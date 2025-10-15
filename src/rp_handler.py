# ================== 临时诊断代码开始 ==================
import os
print("--- STARTING DIAGNOSTIC CHECK ---")
wrapper_file_path = "/root/ComfyUI_API_Wrapper.py"
print(f"Checking for file at: {wrapper_file_path}")

if os.path.exists(wrapper_file_path):
    print("File FOUND. Reading contents...")
    try:
        with open(wrapper_file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            print("--- FILE CONTENT START ---")
            print(content)
            print("--- FILE CONTENT END ---")
            if "class ComfyUIAPIWrapper" in content:
                print("DIAGNOSTIC SUCCESS: The class name 'ComfyUIAPIWrapper' was found in the file.")
            else:
                print("DIAGNOSTIC WARNING: The exact string 'class ComfyUIAPIWrapper' was NOT found.")
    except Exception as e:
        print(f"Error reading file: {e}")
else:
    print("DIAGNOSTIC ERROR: File NOT FOUND.")

print("--- END OF DIAGNOSTIC CHECK ---\n")
# ================== 临时诊断代码结束 ==================

import os
import json
import uuid
import runpod
import requests
from ComfyUI_API_Wrapper import ComfyUI_API_Wrapper

# --- 全局变量和初始化 ---
# ComfyUI 的本地URL
COMFYUI_URL = "http://127.0.0.1:8188"
# 您的工作流文件名，请确保这个文件和 rp_handler.py 在同一个目录，或者路径正确
WORKFLOW_TEMPLATE_FILE = "/root/workflow_api.json"

# 初始化API包装器
api = ComfyUI_API_Wrapper(COMFYUI_URL)

# --- 辅助函数: 下载图片 ---
def download_image(url, save_path):
    """
    从给定的URL下载图片并保存到指定路径。
    """
    try:
        response = requests.get(url, stream=True, timeout=15)
        response.raise_for_status()  # 如果请求失败则抛出异常
        with open(save_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        return True
    except requests.exceptions.RequestException as e:
        print(f"下载图片时出错: {e}")
        return False

# --- RunPod Handler ---
def handler(job):
    """
    RunPod的入口处理函数。
    接收指定的输入参数，修改固定的工作流模板，并执行。
    """
    job_input = job.get('input', {})

    # 1. 加载工作流模板文件
    try:
        with open(WORKFLOW_TEMPLATE_FILE, 'r', encoding='utf-8') as f:
            workflow = json.load(f)
    except FileNotFoundError:
        return {"error": f"关键错误: 工作流模板文件 '{WORKFLOW_TEMPLATE_FILE}' 未找到。"}
    except json.JSONDecodeError:
        return {"error": f"关键错误: 工作流模板文件 '{WORKFLOW_TEMPLATE_FILE}' 格式无效。"}

    # 2. 获取并验证输入参数 (与您的 input.json 格式完全对应)
    image_url = job_input.get("image_url")
    if not image_url:
        return {"error": "输入错误: 'image_url' 是必需的参数。"}

    # 为可选参数提供默认值
    positive_prompt = job_input.get("positive_prompt", "masterpiece, best quality, ultra-detailed, 8k, beautiful woman")
    negative_prompt = job_input.get("negative_prompt", "blurry, ugly, deformed, bad quality")
    # ComfyUI的seed需要是整数
    seed = int(job_input.get("seed", 12345))

    # 3. 下载输入图片
    image_filename = f"input_{uuid.uuid4()}.png"
    save_path = os.path.join(api.input_path, image_filename)
    if not download_image(image_url, save_path):
        return {"error": f"无法从指定的URL下载图片: {image_url}"}

    # 4. 将获取到的参数填充到工作流的对应节点中
    #    这些ID是根据您提供的workflow文件硬编码的
    
    # 节点 106: LoadImage - 设置输入的图片文件名
    workflow["106"]["inputs"]["image"] = image_filename
    
    # 节点 110: CLIPTextEncode - 设置正向提示词
    workflow["110"]["inputs"]["text"] = positive_prompt
    
    # 节点 111: CLIPTextEncode - 设置反向提示词
    workflow["111"]["inputs"]["text"] = negative_prompt

    # 节点 108: KSampler - 设置随机种子
    workflow["108"]["inputs"]["seed"] = seed
    
    # 5. 提交工作流到ComfyUI队列并等待结果
    try:
        prompt_id = api.queue_prompt(workflow)
        if not prompt_id:
            return {"error": "提交工作流到队列失败。"}

        output = api.wait_for_result(prompt_id)

        if not output:
             return {"error": "执行超时或工作流未生成任何输出。"}

        # 6. 返回最终结果
        return {"result": output}

    except Exception as e:
        return {"error": f"处理过程中发生未知错误: {str(e)}"}

# --- 启动 RunPod Worker ---
if __name__ == "__main__":
    print("ComfyUI Worker (定制版) 启动中...")
    runpod.serverless.start({
        "handler": handler
    })
