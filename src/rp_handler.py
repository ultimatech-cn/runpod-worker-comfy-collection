import os
import json
import uuid
import runpod
import requests
from ComfyUI_API_Wrapper import ComfyUI_API_Wrapper # 已修正类名

# --- 全局变量和初始化 ---
COMFYUI_URL = "http://127.0.0.1:8188"
WORKFLOW_TEMPLATE_FILE = "/root/workflow_api.json" # 使用绝对路径

# --- 关键修复：在初始化API Wrapper时提供所有必需的参数 ---
# 1. 为每个Worker实例生成一个唯一的客户端ID
client_id = str(uuid.uuid4())
# 2. 定义ComfyUI的输出目录
output_path = "/root/comfy/ComfyUI/output"
# 3. 传入所有三个参数来创建api对象
api = ComfyUI_API_Wrapper(COMFYUI_URL, client_id, output_path)

# --- 辅助函数: 下载图片 ---
def download_image(url, save_path):
    """
    从给定的URL下载图片并保存到指定路径。
    """
    try:
        response = requests.get(url, stream=True, timeout=15)
        response.raise_for_status()
        with open(save_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8182):
                f.write(chunk)
        return True
    except requests.exceptions.RequestException as e:
        print(f"下载图片时出错: {e}")
        return False

# --- RunPod Handler ---
def handler(job):
    """
    RunPod的入口处理函数。
    """
    job_input = job.get('input', {})

    # 加载工作流模板文件
    try:
        with open(WORKFLOW_TEMPLATE_FILE, 'r', encoding='utf-8') as f:
            workflow = json.load(f)
    except FileNotFoundError:
        return {"error": f"关键错误: 工作流模板文件 '{WORKFLOW_TEMPLATE_FILE}' 未找到。"}
    except json.JSONDecodeError:
        return {"error": f"关键错误: 工作流模板文件 '{WORKFLOW_TEMPLATE_FILE}' 格式无效。"}

    # 获取并验证输入参数
    image_url = job_input.get("image_url")
    if not image_url:
        return {"error": "输入错误: 'image_url' 是必需的参数。"}

    # 为可选参数提供默认值
    positive_prompt = job_input.get("positive_prompt", "masterpiece, best quality, ultra-detailed, 8k, beautiful woman")
    negative_prompt = job_input.get("negative_prompt", "blurry, ugly, deformed, bad quality")
    seed = int(job_input.get("seed", 12345))

    # 下载输入图片
    image_filename = f"input_{uuid.uuid4()}.png"
    # 注意：这里的输入路径也需要从api对象获取，或者硬编码
    input_path = "/root/comfy/ComfyUI/input"
    save_path = os.path.join(input_path, image_filename)
    
    if not os.path.exists(input_path):
        os.makedirs(input_path)

    if not download_image(image_url, save_path):
        return {"error": f"无法从指定的URL下载图片: {image_url}"}

    # 将参数填充到工作流的对应节点中
    workflow["106"]["inputs"]["image"] = image_filename
    workflow["110"]["inputs"]["text"] = positive_prompt
    workflow["111"]["inputs"]["text"] = negative_prompt
    workflow["108"]["inputs"]["seed"] = seed
    
    # 提交工作流到ComfyUI队列并等待结果
    try:
        prompt_id = api.queue_prompt(workflow).get('prompt_id')
        if not prompt_id:
            return {"error": "提交工作流到队列失败。"}

        # 使用新的Wrapper类，它可能需要等待结果
        output_images = api.wait_for_result(prompt_id)

        if not output_images:
             return {"error": "执行超时或工作流未生成任何输出。"}

        return {"result": output_images}

    except Exception as e:
        return {"error": f"处理过程中发生未知错误: {str(e)}"}

# --- 启动 RunPod Worker ---
if __name__ == "__main__":
    print("ComfyUI Worker (定制版) 启动中...")
    runpod.serverless.start({
        "handler": handler
    })
