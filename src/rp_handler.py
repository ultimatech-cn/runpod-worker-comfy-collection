# 文件名: src/rp_handler.py (最终修复下载功能版)

import os
import random
import uuid
import json
import base64
import requests # 确保导入 requests 库

import runpod
# 不再需要 rp_download，我们自己实现下载
# from runpod.serverless.utils import rp_download 
from ComfyUI_API_Wrapper import ComfyUI_API_Wrapper

# --- 常量 ---
COMFYUI_URL = "http://127.0.0.1:8188"
COMFYUI_INPUT_DIR = "/root/comfy/ComfyUI/input"

# --- 新增的、可靠的下载函数 ---
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
            response.raise_for_status() # 如果请求失败则会抛出异常
            with open(save_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
        return True # 下载成功
    except Exception as e:
        print(f"下载图片失败，URL: {url}. 错误: {e}")
        return False # 下载失败

# --- 输入验证 ---
def validate_input(job_input):
    if not job_input: return {"error": "Input is missing."}
    if 'source_image' not in job_input: return {"error": "Missing 'source_image' in input."}
    if 'prompt' not in job_input: return {"error": "Missing 'prompt' in input."}
    return None

# --- 主处理函数 ---
def handler(job):
    job_input = job.get('input', {})

    error = validate_input(job_input)
    if error: return error

    client_id = str(uuid.uuid4())
    api = ComfyUI_API_Wrapper(COMFYUI_URL, client_id, None)

    unique_name = str(uuid.uuid4())[:8]
    input_image_name = f"input_{unique_name}.png"
    input_image_path = os.path.join(COMFYUI_INPUT_DIR, input_image_name)

    # *** 使用我们自己的、可靠的下载函数 ***
    if not download_image(job_input['source_image'], input_image_path):
        return {"error": "Failed to download source image."}

    # --- 加载并修改工作流 ---
    try:
        with open("/root/workflow.json", 'r', encoding='utf-8') as f:
            prompt_workflow = json.load(f)
    except Exception as e:
        return {"error": f"Failed to load or parse /root/workflow.json: {e}"}

    # 注入输入到工作流模板
    prompt_workflow["294"]["inputs"]["image"] = input_image_name
    prompt_workflow["27"]["inputs"]["text_positive"] = job_input.get('prompt')
    prompt_workflow["27"]["inputs"]["text_negative"] = job_input.get('negative_prompt', '')
    seed = job_input.get('seed', random.randint(0, 18446744073709551615))
    prompt_workflow["31"]["inputs"]["seed"] = seed

    # --- 运行工作流 ---
    final_output_node_id = "238"
    
    try:
        images_output = api.queue_prompt_and_get_images(prompt_workflow, final_output_node_id)
        
        if not images_output:
            return {"error": "Workflow execution failed. Check worker logs for ComfyUI errors."}

        image_data = images_output[0]
        image_content = api.get_image(image_data['filename'], image_data['subfolder'], image_data['type'])
        output_image_base64 = base64.b64encode(image_content).decode('utf-8')

    except Exception as e:
        return {"error": f"An unexpected error occurred: {e}"}
    finally:
        if os.path.exists(input_image_path):
            os.remove(input_image_path)

    return {"image": f"data:image/png;base64,{output_image_base64}"}

# --- 启动 Serverless Worker ---
runpod.serverless.start({"handler": handler})
