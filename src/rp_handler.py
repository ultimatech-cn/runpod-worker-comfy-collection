import os
import random
import uuid
import json
import base64
import requests
import websocket
from urllib.parse import urlparse

import runpod
from runpod.serverless.utils import rp_download

# --- 常量 ---
COMFYUI_URL = "http://127.0.0.1:8188"
COMFYUI_INPUT_DIR = "/root/comfy/ComfyUI/input"

# --- 辅助函数 ---
def download_image(url, save_path):
    """从 URL 下载图像并保存到指定路径，支持 URL 和 Base64。"""
    try:
        if url.startswith('data:image'):
            header, encoded = url.split(',', 1)
            image_data = base64.b64decode(encoded)
            with open(save_path, 'wb') as f:
                f.write(image_data)
        else:
            response = requests.get(url, stream=True)
            response.raise_for_status()
            with open(save_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
        return os.path.basename(save_path)
    except Exception as e:
        print(f"下载图片失败，URL: {url}. 错误: {e}")
        return None

def queue_prompt(prompt, client_id):
    """将工作流任务提交到 ComfyUI 队列。"""
    try:
        req = requests.post(f"{COMFYUI_URL}/prompt", json={
            "prompt": prompt,
            "client_id": client_id
        })
        req.raise_for_status()
        return req.json()
    except requests.exceptions.RequestException as e:
        print(f"提交任务队列失败: {e}")
        return None

def get_image(filename, subfolder, folder_type):
    """从 ComfyUI 服务器获取输出图像。"""
    try:
        url = f"{COMFYUI_URL}/view?filename={filename}&subfolder={subfolder}&type={folder_type}"
        response = requests.get(url)
        response.raise_for_status()
        return response.content
    except requests.exceptions.RequestException as e:
        print(f"获取图像失败: {e}")
        return None

def get_history(prompt_id):
    """根据任务ID获取执行历史。"""
    try:
        url = f"{COMFYUI_URL}/history/{prompt_id}"
        response = requests.get(url)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"获取历史记录失败: {e}")
        return None

# --- 主处理函数 ---
def handler(job):
    """
    RunPod Serverless Worker 的主处理函数。
    """
    job_input = job.get('input', {})

    # --- 验证输入 ---
    if not all(k in job_input for k in ['source_image', 'prompt']):
        return {"error": "缺少必要的输入: 'source_image' 或 'prompt'。"}

    # --- 下载唯一的源图片 ---
    client_id = str(uuid.uuid4())
    unique_name = str(uuid.uuid4())[:8]
    
    input_image_name = f"input_{unique_name}.png"
    input_image_path = os.path.join(COMFYUI_INPUT_DIR, input_image_name)

    if not download_image(job_input['source_image'], input_image_path):
        return {"error": "下载源图片失败。"}

    # --- 加载并修改工作流 ---
    try:
        with open("workflow.json", 'r', encoding='utf-8') as f:
            prompt_workflow = json.load(f)
    except FileNotFoundError:
        return {"error": "workflow.json 文件未找到。"}
    except json.JSONDecodeError:
        return {"error": "无法解析 workflow.json 文件。"}

    # 1. 注入源图片
    # 节点 "294" 是工作流中唯一的 LoadImage 节点
    prompt_workflow["294"]["inputs"]["image"] = input_image_name
    
    # 2. 注入提示词
    # 节点 "27" 是 SDXLPromptStyler
    prompt_workflow["27"]["inputs"]["text_positive"] = job_input.get('prompt')
    prompt_workflow["27"]["inputs"]["text_negative"] = job_input.get('negative_prompt', '')

    # 3. 注入种子
    # 节点 "31" 是 KSampler
    seed = job_input.get('seed', random.randint(0, 18446744073709551615))
    prompt_workflow["31"]["inputs"]["seed"] = seed

    # --- 运行工作流 ---
    ws = websocket.WebSocket()
    ws.connect(f"ws://{urlparse(COMFYUI_URL).netloc}/ws?clientId={client_id}")
    
    prompt_id = queue_prompt(prompt_workflow, client_id).get('prompt_id')
    if not prompt_id:
        ws.close()
        return {"error": "提交任务到队列失败。"}

    # --- 等待并处理输出 ---
    output_image = None
    try:
        while True:
            out = ws.recv()
            if isinstance(out, str):
                message = json.loads(out)
                if message.get('type') == 'executed' and message.get('data', {}).get('prompt_id') == prompt_id:
                    # 节点 "238" 是您工作流中最终的 "Image Save" 节点
                    history = get_history(prompt_id)
                    output_data = history[prompt_id]['outputs']['238']['images'][0]
                    image_content = get_image(output_data['filename'], output_data['subfolder'], output_data['type'])
                    output_image = base64.b64encode(image_content).decode('utf-8')
                    break
    finally:
        ws.close()
    
    if output_image:
        # 清理输入文件，为下一个任务做准备
        if os.path.exists(input_image_path):
            os.remove(input_image_path)
        return {"image": f"data:image/png;base64,{output_image}"}
    else:
        return {"error": "工作流未能生成输出图像。"}


# --- 启动 Serverless Worker ---
runpod.serverless.start({"handler": handler})