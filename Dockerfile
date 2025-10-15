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
    $COMFYUI_PATH/models/loras \
    $COMFYUI_PATH/models/controlnet \
    $COMFYUI_PATH/models/upscale_models

# --- 6. 下载所有模型文件 ---
# Checkpoints
RUN wget -O $COMFYUI_PATH/models/checkpoints/epicrealism_naturalSinRC1VAE.safetensors "https://huggingface.co/dtarnow/epicrealism_naturalSinRC1VAE/resolve/a941b77c791f939be58b4cf8e2bfcbcd6f32c6d6/epicrealism_naturalSinRC1VAE.safetensors"

# LORAs
RUN wget -O $COMFYUI_PATH/models/loras/more_details.safetensors "https://huggingface.co/digiplay/LORA/resolve/fa075647d8164b327ba07e430bdb3fd02f147a62/more_details.safetensors"
RUN wget -O $COMFYUI_PATH/models/loras/SDXLrender_v2.0.safetensors "https://huggingface.co/philz1337x/loras/resolve/main/SDXLrender_v2.0.safetensors"

# ControlNet
RUN wget -O $COMFYUI_PATH/models/controlnet/control_v11f1e_sd15_tile.pth "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1e_sd15_tile.pth"

# Upscale Models
RUN wget -O $COMFYUI_PATH/models/upscale_models/4x_foolhardy_Remacri.pth "https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri/resolve/main/4x_foolhardy_Remacri.pth"
RUN wget -O $COMFYUI_PATH/models/upscale_models/4x_NMKD-Siax_200k.pth "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Siax_200k.pth"

# --- 7. 安装所有自定义节点 ---
RUN git clone https://github.com/Extraltodeus/ComfyUI-AutomaticCFG.git $COMFYUI_PATH/custom_nodes/ComfyUI-AutomaticCFG && \
    git clone https://github.com/pamparamm/sd-perturbed-attention.git $COMFYUI_PATH/custom_nodes/sd-perturbed-attention && \
    git clone https://github.com/shiimizu/ComfyUI-TiledDiffusion.git $COMFYUI_PATH/custom_nodes/ComfyUI-TiledDiffusion && \
    git clone https://github.com/EllangoK/ComfyUI-post-processing-nodes.git $COMFYUI_PATH/custom_nodes/ComfyUI-post-processing-nodes

# --- 8. 复制脚本并设置权限 ---
# 将本地的启动脚本和处理器复制到镜像中
COPY src/start.sh /root/start.sh
COPY src/rp_handler.py /root/rp_handler.py
COPY src/ComfyUI_API_Wrapper.py /root/ComfyUI_API_Wrapper.py
COPY src/workflow_api.json /root/workflow_api.json # <--- 添加这一行

# 赋予启动脚本执行权限
RUN chmod +x /root/start.sh

# --- 9. 定义容器启动命令 ---
# 设置容器启动时执行的默认命令
CMD ["/root/start.sh"]
