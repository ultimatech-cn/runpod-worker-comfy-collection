# 使用包含CUDA 12.2的NVIDIA基础镜像
FROM nvidia/cuda:12.6.3-cudnn-runtime-ubuntu22.04

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

ENV TZ="Etc/UTC"

ENV COMFYUI_PATH=/root/comfy/ComfyUI

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3-pip \
    git \
    wget \
    libgl1 \
    ffmpeg \
    curl \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# 安装 git-lfs
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash \
    && apt-get install -y git-lfs \
    && git lfs install

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install uv

# Install comfy-cli
RUN uv pip install comfy-cli --system

RUN comfy --skip-prompt install --nvidia

RUN pip uninstall -y torch torchaudio torchvision
RUN uv pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu124

# 安装 Python 包
RUN uv pip install \
    fastapi[standard]==0.115.4 \
    opencv-python \
    imageio-ffmpeg \
    hf_transfer \
    scikit-image \
    matplotlib \
    onnx \
    modelscope \
    transformers \
    runpod \
    --system

# 运行 comfy 安装命令

# 克隆自定义节点仓库并安装依赖
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager /root/comfy/ComfyUI/custom_nodes/comfyui-manager
RUN git clone https://github.com/Fannovel16/comfyui_controlnet_aux /root/comfy/ComfyUI/custom_nodes/comfyui_controlnet_aux \
    && uv pip install -r /root/comfy/ComfyUI/custom_nodes/comfyui_controlnet_aux/requirements.txt --system
RUN git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git /root/comfy/ComfyUI/custom_nodes/ComfyUI-Custom-Scripts
RUN git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack /root/comfy/ComfyUI/custom_nodes/comfyui-impact-pack \
    && uv pip install -r /root/comfy/ComfyUI/custom_nodes/comfyui-impact-pack/requirements.txt --system
RUN git clone https://github.com/chflame163/ComfyUI_LayerStyle /root/comfy/ComfyUI/custom_nodes/ComfyUI_LayerStyle \
    && uv pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI_LayerStyle/requirements.txt --system
RUN git clone https://github.com/yolain/ComfyUI-Easy-Use /root/comfy/ComfyUI/custom_nodes/ComfyUI-Easy-Use \
    && uv pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-Easy-Use/requirements.txt --system
RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git /root/comfy/ComfyUI/custom_nodes/ComfyUI-KJNodes \
    && uv pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-KJNodes/requirements.txt --system
RUN git clone https://github.com/jags111/efficiency-nodes-comfyui /root/comfy/ComfyUI/custom_nodes/efficiency-nodes-comfyui \
    && uv pip install -r /root/comfy/ComfyUI/custom_nodes/efficiency-nodes-comfyui/requirements.txt --system
RUN git clone https://github.com/storyicon/comfyui_segment_anything.git /root/comfy/ComfyUI/custom_nodes/comfyui_segment_anything \
    && uv pip install -r /root/comfy/ComfyUI/custom_nodes/comfyui_segment_anything/requirements.txt --system
RUN git clone https://github.com/pythongosssss/ComfyUI-WD14-Tagger /root/comfy/ComfyUI/custom_nodes/ComfyUI-WD14-Tagger \
    && uv pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-WD14-Tagger/requirements.txt --system
RUN git clone https://github.com/cubiq/ComfyUI_essentials.git /root/comfy/ComfyUI/custom_nodes/ComfyUI_essentials \
    && uv pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI_essentials/requirements.txt --system
RUN git clone https://github.com/ZHO-ZHO-ZHO/ComfyUI-Gemini /root/comfy/ComfyUI/custom_nodes/ComfyUI-Gemini \
    && uv pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-Gemini/requirements.txt --system
RUN git clone https://github.com/chrisgoringe/cg-use-everywhere /root/comfy/ComfyUI/custom_nodes/cg-use-everywhere
RUN git clone https://github.com/CY-CHENYUE/ComfyUI-Janus-Pro /root/comfy/ComfyUI/custom_nodes/ComfyUI-Janus-Pro \
    && uv pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-Janus-Pro/requirements.txt --system
RUN git clone https://github.com/melMass/comfy_mtb /root/comfy/ComfyUI/custom_nodes/comfy_mtb \
    && uv pip install -r /root/comfy/ComfyUI/custom_nodes/comfy_mtb/requirements.txt --system
RUN git clone https://github.com/wallish77/wlsh_nodes /root/comfy/ComfyUI/custom_nodes/wlsh_nodes \
    && uv pip install -r /root/comfy/ComfyUI/custom_nodes/wlsh_nodes/requirements.txt --system
RUN git clone https://github.com/M1kep/ComfyLiterals /root/comfy/ComfyUI/custom_nodes/ComfyLiterals
RUN git clone https://github.com/ai-shizuka/ComfyUI-tbox /root/comfy/ComfyUI/custom_nodes/ComfyUI-tbox
RUN git clone https://github.com/Goktug/comfyui-saveimage-plus /root/comfy/ComfyUI/custom_nodes/comfyui-saveimage-plus

# 创建目录
RUN mkdir -p /root/comfy/ComfyUI/web/extensions/Gemini_Zho \
    && mkdir -p /root/comfy/ComfyUI/temp/ckpts \
    && mkdir /root/comfy/ComfyUI/models/clip/sd3 \
    && mkdir /root/comfy/ComfyUI/models/LLM \
    && mkdir /root/comfy/ComfyUI/models/Janus-Pro \
    && mkdir /root/comfy/ComfyUI/models/sams \
    && mkdir /root/comfy/ComfyUI/models/grounding-dino

# 下载模型
RUN modelscope download --model 'licyks/control-lora' control-lora-canny-rank256.safetensors control-lora-depth-rank256.safetensors --local_dir '/root/comfy/ComfyUI/models/controlnet/'
RUN huggingface-cli login --token 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
RUN huggingface-cli download black-forest-labs/FLUX.1-Fill-dev ae.safetensors --local-dir /root/comfy/ComfyUI/models/vae/
RUN huggingface-cli download comfyanonymous/flux_text_encoders t5xxl_fp16.safetensors clip_l.safetensors --local-dir /root/comfy/ComfyUI/models/clip/sd3/
RUN huggingface-cli download oguzm/dreamshaper-xl-lightning-dpmsde dreamshaperXL_lightningDPMSDE.safetensors --local-dir /root/comfy/ComfyUI/models/checkpoints/
RUN huggingface-cli download ShilongLiu/GroundingDINO groundingdino_swint_ogc.pth GroundingDINO_SwinT_OGC.cfg.py --local-dir /root/comfy/ComfyUI/models/grounding-dino/
RUN huggingface-cli download Shakker-Labs/AWPortrait-FL AWPortrait-FL-lora.safetensors --local-dir /root/comfy/ComfyUI/models/loras/

# 下载其他文件
RUN wget -q -O /root/comfy/ComfyUI/models/sams/sam_vit_b_01ec64.pth https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth
RUN wget -q -O /root/comfy/ComfyUI/models/unet/flux1-dev-fp8-Kijai.safetensors https://huggingface.co/Kijai/flux-fp8/resolve/main/flux1-dev-fp8.safetensors?download=true
RUN wget -q -O /root/comfy/ComfyUI/models/upscale_models/RealESRGAN_x2plus.pth https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth

# 克隆模型仓库
RUN git clone https://huggingface.co/google-bert/bert-base-uncased /root/comfy/ComfyUI/models/bert-base-uncased
RUN git clone https://huggingface.co/microsoft/Florence-2-base /root/comfy/ComfyUI/models/LLM/Florence-2-base
RUN git clone https://huggingface.co/deepseek-ai/Janus-Pro-1B /root/comfy/ComfyUI/models/Janus-Pro/Janus-Pro-1B
RUN git clone https://huggingface.co/deepseek-ai/Janus-Pro-7B /root/comfy/ComfyUI/models/Janus-Pro/Janus-Pro-7B

# 强制重新安装 timm
RUN python -m pip install --force-reinstall timm>=0.9.16

# 创建目录并下载文件
RUN mkdir -p /root/comfy/ComfyUI/custom_nodes/comfyui_controlnet_aux/ckpts/lllyasviel/Annotators \
    && huggingface-cli download lllyasviel/Annotators sk_model.pth sk_model2.pth dpt_hybrid-midas-501f0c75.pt --local-dir /root/comfy/ComfyUI/custom_nodes/comfyui_controlnet_aux/ckpts/lllyasviel/Annotators/

COPY src/start.sh /root/
COPY src/rp_handler.py /root/
COPY workflow.json /root/
COPY config.ini /root/comfy/ComfyUI/user/default/ComfyUI-Manager/config.ini

RUN chmod +x /root/start.sh

CMD ["/root/start.sh"]
