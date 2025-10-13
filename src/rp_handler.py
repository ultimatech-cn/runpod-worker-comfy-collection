# 文件名: src/rp_handler.py

import os
import random
import uuid
import json
import base64

import runpod
from runpod.serverless.utils import rp_download

# 导入健壮的 API 包装器
from ComfyUI_API_Wrapper import ComfyUI_API_Wrapper

# --- 常量 ---
COMFYUI_URL = "http://127.0.0.1:8188"
COMFYUI_INPUT_DIR = "/root/comfy/ComfyUI/input"

# --- 输入验证 ---
def validate_input(job_input):
    """验证输入是否包含必要字段"""
    if not job_input:
        return {"error": "Input is missing."}
    if 'source_image' not in job_input:
        return {"error": "Missing 'source_image' in input."}
    if 'prompt' not in job_input:
        return {"error": "Missing 'prompt' in input."}
    return None

# --- 主处理函数 ---
def handler(job):
    """
    RunPod Serverless Worker 的主处理函数。
    """
    job_input = job.get('input', {})

    # 验证输入
    error = validate_input(job_input)
    if error:
        return error

    # --- 初始化 API 包装器 ---
    client_id = str(uuid.uuid4())
    api = ComfyUI_API_Wrapper(COMFYUI_URL, client_id, None)

    # --- 下载唯一的源图片 ---
    unique_name = str(uuid.uuid4())[:8]
    input_image_name = f"input_{unique_name}.png"
    input_image_path = os.path.join(COMFYUI_INPUT_DIR, input_image_name)

    try:
        rp_download.download_file_from_url(job['id'], job_input['source_image'], input_image_path)
    except Exception as e:
        return {"error": f"Failed to download source image: {e}"}

    # --- 加载并修改工作流 ---
    try:
        with open("workflow.json", 'r', encoding='utf-8') as f:
            prompt_workflow = json.load(f)
    except Exception as e:
        return {"error": f"Failed to load or parse workflow.json: {e}"}

    # 1. 注入源图片 -> 节点 "294" (Load Image)
    prompt_workflow["294"]["inputs"]["image"] = input_image_name
    
    # 2. 注入提示词 -> 节点 "27" (SDXL Prompt Styler)
    prompt_workflow["27"]["inputs"]["text_positive"] = job_input.get('prompt')
    prompt_workflow["27"]["inputs"]["text_negative"] = job_input.get('negative_prompt', '')

    # 3. 注入种子 -> 节点 "31" (KSampler)
    seed = job_input.get('seed', random.randint(0, 18446744073709551615))
    prompt_workflow["31"]["inputs"]["seed"] = seed

    # --- 使用包装器运行工作流并获取结果 ---
    # 节点 "238" 是您工作流中最终的 "Image Save" 节点
    final_output_node_id = "238"
    
    try:
        images_output = api.queue_prompt_and_get_images(prompt_workflow, final_output_node_id)
        
        if not images_output:
            # 去 Logs 页面查看 ComfyUI 的具体错误
            return {"error": "Workflow execution failed to produce images. Check worker logs for details."}

        # 获取第一张图片的详细信息
        image_data = images_output[0]
        image_content = api.get_image(image_data['filename'], image_data['subfolder'], image_data['type'])
        
        output_image_base64 = base64.b64encode(image_content).decode('utf-8')

    except Exception as e:
        return {"error": f"An unexpected error occurred during workflow execution: {e}"}
    finally:
        # 清理输入文件
        if os.path.exists(input_image_path):
            os.remove(input_image_path)

    return {"image": f"data:image/png;base64,{output_image_base64}"}


# --- 启动 Serverless Worker ---
runpod.serverless.start({"handler": handler})
