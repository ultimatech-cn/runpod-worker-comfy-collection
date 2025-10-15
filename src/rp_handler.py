import os
import json
import uuid
import runpod
import base64 # <-- 关键：导入base64库
import requests
from ComfyUI_API_Wrapper import ComfyUI_API_Wrapper

# --- 全局常量和初始化 ---
COMFYUI_URL = "http://127.0.0.1:8188"
WORKFLOW_TEMPLATE_FILE = "/root/workflow_api.json"
OUTPUT_NODE_ID = "164"

client_id = str(uuid.uuid4())
output_path = "/root/comfy/ComfyUI/output"
api = ComfyUI_API_Wrapper(COMFYUI_URL, client_id, output_path)

# --- 辅助函数: 下载图片 ---
def download_image(url, save_path):
    try:
        response = requests.get(url, stream=True, timeout=15)
        response.raise_for_status()
        with open(save_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        return True
    except requests.exceptions.RequestException as e:
        print(f"下载图片时出错: {e}")
        return False

# --- RunPod Handler ---
def handler(job):
    job_input = job.get('input', {})

    try:
        with open(WORKFLOW_TEMPLATE_FILE, 'r', encoding='utf-8') as f:
            workflow = json.load(f)
    except Exception as e:
        return {"error": f"加载工作流模板失败: {e}"}

    image_url = job_input.get("image_url")
    if not image_url:
        return {"error": "输入错误: 'image_url' 是必需的参数。"}
    
    input_path = "/root/comfy/ComfyUI/input"
    if not os.path.exists(input_path):
        os.makedirs(input_path)

    image_filename = f"input_{uuid.uuid4()}.png"
    save_path = os.path.join(input_path, image_filename)

    if not download_image(image_url, save_path):
        return {"error": f"无法从指定的URL下载图片: {image_url}"}

    # 填充工作流参数
    workflow["106"]["inputs"]["image"] = image_filename
    workflow["110"]["inputs"]["text"] = job_input.get("positive_prompt", "a beautiful girl")
    workflow["111"]["inputs"]["text"] = job_input.get("negative_prompt", "blurry, ugly")
    workflow["108"]["inputs"]["seed"] = int(job_input.get("seed", uuid.uuid4().int & (1<<32)-1))

    try:
        # 1. 执行工作流，获取包含文件名的输出信息
        output_data = api.queue_prompt_and_get_images(workflow, OUTPUT_NODE_ID)

        if not output_data:
             return {"error": "执行超时或工作流未生成任何图片输出。"}
        
        # 2. 准备一个列表来存放base64编码的图片
        base64_images = []

        # 3. 遍历输出信息，读取每张图片并进行base64编码
        for image_info in output_data:
            filename = image_info.get("filename")
            subfolder = image_info.get("subfolder")
            img_type = image_info.get("type")

            if filename and img_type == 'output':
                # 使用API Wrapper的方法获取图片的二进制数据
                image_bytes = api.get_image(filename, subfolder, img_type)
                # 将二进制数据编码为base64字符串
                base64_encoded_image = base64.b64encode(image_bytes).decode('utf-8')
                base64_images.append(base64_encoded_image)

        # 4. 在最终的JSON中返回包含base64字符串的列表
        return {"images": base64_images}

    except Exception as e:
        return {"error": f"处理过程中发生未知错误: {str(e)}"}

# --- 启动 RunPod Worker ---
if __name__ == "__main__":
    print("ComfyUI Worker (Base64-output) 启动中...")
    runpod.serverless.start({"handler": handler})
