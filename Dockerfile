# --- 1. 基础镜像和环境设置 ---
# 使用包含 PyTorch 和 CUDA 的官方 RunPod 镜像
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

# 防止在安装过程中出现交互式提示
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ="Etc/UTC"

# 定义核心路径变量
ENV COMFYUI_PATH=/root/comfy/ComfyUI
ENV VENV_PATH=/venv


# --- 2. 安装系统依赖 ---
# 一次性安装所有必需的系统工具，并清理缓存以减小镜像大小
RUN apt-get update && apt-get install -y \
    curl \
    git \
    ffmpeg \
    wget \
    unzip \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*


# --- 3. 设置 Python 虚拟环境 (VENV) ---
# 创建虚拟环境以隔离依赖
RUN python -m venv $VENV_PATH

# 将虚拟环境的 bin 目录添加到 PATH，这样后续命令会默认使用 venv 中的 python 和 pip
ENV PATH="$VENV_PATH/bin:$PATH"

# 在虚拟环境中升级 pip
RUN /venv/bin/python -m pip install --upgrade pip


# --- 4. 安装 ComfyUI 和核心 Python 包 ---
# 使用 comfy-cli 工具安装 ComfyUI 本体
RUN /venv/bin/python -m pip install comfy-cli
RUN comfy --skip-prompt install --nvidia --cuda-version 12.4

# 安装运行 RunPod Worker 和其他节点所需的核心 Python 库
RUN /venv/bin/python -m pip install \
    opencv-python \
    imageio-ffmpeg \
    runpod


# --- 5. 创建所有模型目录 ---
# 一次性创建所有需要的模型子目录，保持结构清晰
RUN mkdir -p \
    $COMFYUI_PATH/models/checkpoints \
    $COMFYUI_PATH/models/vae \
    $COMFYUI_PATH/models/controlnet \
    $COMFYUI_PATH/models/sams \
    $COMFYUI_PATH/models/ultralytics/bbox \
    $COMFYUI_PATH/models/insightface/models \
    $COMFYUI_PATH/models/reswapper \
    $COMFYUI_PATH/models/hyperswap \
    $COMFYUI_PATH/models/facerestore_models \
    $COMFYUI_PATH/models/upscale_models


# --- 6. 下载所有模型文件 ---
# 使用 wget -O 命令将模型直接下载到指定目录
# Checkpoints
RUN wget -O $COMFYUI_PATH/models/checkpoints/RealVisXL_V5.0_Lightning_fp16.safetensors "https://huggingface.co/SG161222/RealVisXL_V5.0_Lightning/resolve/main/RealVisXL_V5.0_Lightning_fp16.safetensors"

# VAE
RUN wget -O $COMFYUI_PATH/models/vae/sdxl_vae.safetensors "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors"

# ControlNet
RUN wget -O $COMFYUI_PATH/models/controlnet/diffusion_pytorch_model_promax.safetensors "https://huggingface.co/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model_promax.safetensors"

# ReActor Models (Sams, Bbox, Face Restore, etc.)
RUN wget -O $COMFYUI_PATH/models/sams/sam_vit_b_01ec64.pth "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/sams/sam_vit_b_01ec64.pth"
RUN wget -O $COMFYUI_PATH/models/ultralytics/bbox/face_yolov8m.pt "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/detection/bbox/face_yolov8m.pt"
RUN wget -O $COMFYUI_PATH/models/insightface/inswapper_128.onnx "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128.onnx"
RUN wget -O $COMFYUI_PATH/models/reswapper/reswapper_128.onnx "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/reswapper_128.onnx"
RUN wget -O $COMFYUI_PATH/models/facerestore_models/GFPGANv1.4.pth "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/GFPGANv1.4.pth"
RUN wget -O $COMFYUI_PATH/models/facerestore_models/GPEN-BFR-512.onnx "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/GPEN-BFR-512.onnx"

# Hyperswap Models
RUN wget -O $COMFYUI_PATH/models/hyperswap/hyperswap_1a_256.onnx "https://huggingface.co/facefusion/models-3.3.0/resolve/main/hyperswap_1a_256.onnx"
RUN wget -O $COMFYUI_PATH/models/hyperswap/hyperswap_1b_256.onnx "https://huggingface.co/facefusion/models-3.3.0/resolve/main/hyperswap_1b_256.onnx"
RUN wget -O $COMFYUI_PATH/models/hyperswap/hyperswap_1c_256.onnx "https://huggingface.co/facefusion/models-3.3.0/resolve/main/hyperswap_1c_256.onnx"

# Upscale Models
RUN wget -O $COMFYUI_PATH/models/upscale_models/RealESRGAN_x2.pth "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x2.pth"

# 特殊处理：下载并解压 buffalo_l.zip
RUN wget -O /tmp/buffalo_l.zip "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/buffalo_l.zip" && \
    unzip /tmp/buffalo_l.zip -d $COMFYUI_PATH/models/insightface/models/ && \
    rm /tmp/buffalo_l.zip


# --- 7. 安装所有自定义节点 ---
# 将所有 git clone 和 pip install 命令整合到一个 RUN 块中，以优化镜像层
# 为每一个包含 requirements.txt 的节点都添加依赖安装步骤
RUN git clone https://github.com/Gourieff/ComfyUI-ReActor.git $COMFYUI_PATH/custom_nodes/ComfyUI-ReActor && \
    /venv/bin/python -m pip install -r $COMFYUI_PATH/custom_nodes/ComfyUI-ReActor/requirements.txt && \
    \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git $COMFYUI_PATH/custom_nodes/ComfyUI-Impact-Pack && \
    /venv/bin/python -m pip install -r $COMFYUI_PATH/custom_nodes/ComfyUI-Impact-Pack/requirements.txt && \
    \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git $COMFYUI_PATH/custom_nodes/ComfyUI-Impact-Subpack && \
    \
    git clone https://github.com/rgthree/rgthree-comfy.git $COMFYUI_PATH/custom_nodes/rgthree-comfy && \
    /venv/bin/python -m pip install -r $COMFYUI_PATH/custom_nodes/rgthree-comfy/requirements.txt && \
    \
    git clone https://github.com/twri/sdxl_prompt_styler.git $COMFYUI_PATH/custom_nodes/sdxl_prompt_styler && \
    \
    git clone https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git $COMFYUI_PATH/custom_nodes/ComfyUI_JPS-Nodes && \
    \
    git clone https://github.com/1038lab/ComfyUI-RMBG.git $COMFYUI_PATH/custom_nodes/ComfyUI-RMBG && \
    /venv/bin/python -m pip install -r $COMFYUI_PATH/custom_nodes/ComfyUI-RMBG/requirements.txt && \
    \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git $COMFYUI_PATH/custom_nodes/ComfyUI-KJNodes && \
    /venv/bin/python -m pip install -r $COMFYUI_PATH/custom_nodes/ComfyUI-KJNodes/requirements.txt && \
    \
    git clone https://github.com/evanspearman/ComfyMath.git $COMFYUI_PATH/custom_nodes/ComfyMath && \
    \
    git clone https://github.com/chflame163/ComfyUI_LayerStyle.git $COMFYUI_PATH/custom_nodes/ComfyUI_LayerStyle && \
    /venv/bin/python -m pip install -r $COMFYUI_PATH/custom_nodes/ComfyUI_LayerStyle/requirements.txt && \
    \
    git clone https://github.com/Acly/comfyui-tooling-nodes.git $COMFYUI_PATH/custom_nodes/comfyui-tooling-nodes && \
    \
    git clone https://github.com/WainWong/ComfyUI-Loop-image.git $COMFYUI_PATH/custom_nodes/ComfyUI-Loop-image
    

# --- 8. 复制脚本并设置权限 ---
# 将本地的启动脚本和处理器复制到镜像中
COPY src/start.sh /
COPY src/rp_handler.py /

# 赋予启动脚本执行权限
RUN chmod +x /start.sh


# --- 9. 定义容器启动命令 ---
# 设置容器启动时执行的默认命令
CMD ["/start.sh"]
