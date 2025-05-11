# 使用包含CUDA 12.2的NVIDIA基础镜像
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive

ENV TZ="Etc/UTC"

ENV COMFYUI_PATH=/root/comfy/ComfyUI

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    git \
    ffmpeg \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 安装 git-lfs
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash \
    && apt-get install -y git-lfs \
    && rm -rf /var/lib/apt/lists/*

# 安装 Python 包
RUN pip install fastapi[standard]==0.115.4 \
    comfy-cli \
    opencv-python \
    imageio-ffmpeg \
    hf_transfer \
    scikit-image \
    matplotlib \
    onnx \
    modelscope \
    transformers \
    torch

# 运行 comfy 安装命令和初始化 git lfs
RUN comfy --skip-prompt install --nvidia \
    && git lfs install

# 克隆自定义节点仓库并安装依赖
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager /root/comfy/ComfyUI/custom_nodes/comfyui-manager \
    && git clone https://github.com/Fannovel16/comfyui_controlnet_aux /root/comfy/ComfyUI/custom_nodes/comfyui_controlnet_aux \
    && pip install -r /root/comfy/ComfyUI/custom_nodes/comfyui_controlnet_aux/requirements.txt \
    && git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git /root/comfy/ComfyUI/custom_nodes/ComfyUI-Custom-Scripts \
    && git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack /root/comfy/ComfyUI/custom_nodes/comfyui-impact-pack \
    && pip install -r /root/comfy/ComfyUI/custom_nodes/comfyui-impact-pack/requirements.txt \
    && git clone https://github.com/chflame163/ComfyUI_LayerStyle /root/comfy/ComfyUI/custom_nodes/ComfyUI_LayerStyle \
    && pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI_LayerStyle/requirements.txt \
    && git clone https://github.com/yolain/ComfyUI-Easy-Use /root/comfy/ComfyUI/custom_nodes/ComfyUI-Easy-Use \
    && pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-Easy-Use/requirements.txt \
    && git clone https://github.com/kijai/ComfyUI-KJNodes.git /root/comfy/ComfyUI/custom_nodes/ComfyUI-KJNodes \
    && pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-KJNodes/requirements.txt \
    && git clone https://github.com/jags111/efficiency-nodes-comfyui /root/comfy/ComfyUI/custom_nodes/efficiency-nodes-comfyui \
    && pip install -r /root/comfy/ComfyUI/custom_nodes/efficiency-nodes-comfyui/requirements.txt \
    && git clone https://github.com/storyicon/comfyui_segment_anything.git /root/comfy/ComfyUI/custom_nodes/comfyui_segment_anything \
    && pip install -r /root/comfy/ComfyUI/custom_nodes/comfyui_segment_anything/requirements.txt \
    && git clone https://github.com/pythongosssss/ComfyUI-WD14-Tagger /root/comfy/ComfyUI/custom_nodes/ComfyUI-WD14-Tagger \
    && pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-WD14-Tagger/requirements.txt \
    && git clone https://github.com/cubiq/ComfyUI_essentials.git /root/comfy/ComfyUI/custom_nodes/ComfyUI_essentials \
    && pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI_essentials/requirements.txt \
    && git clone https://github.com/ZHO-ZHO-ZHO/ComfyUI-Gemini /root/comfy/ComfyUI/custom_nodes/ComfyUI-Gemini \
    && pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-Gemini/requirements.txt \
    && git clone https://github.com/chrisgoringe/cg-use-everywhere /root/comfy/ComfyUI/custom_nodes/cg-use-everywhere \
    && git clone https://github.com/CY-CHENYUE/ComfyUI-Janus-Pro /root/comfy/ComfyUI/custom_nodes/ComfyUI-Janus-Pro \
    && pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-Janus-Pro/requirements.txt \
    && git clone https://github.com/melMass/comfy_mtb /root/comfy/ComfyUI/custom_nodes/comfy_mtb \
    && pip install -r /root/comfy/ComfyUI/custom_nodes/comfy_mtb/requirements.txt \
    && git clone https://github.com/wallish77/wlsh_nodes /root/comfy/ComfyUI/custom_nodes/wlsh_nodes \
    && pip install -r /root/comfy/ComfyUI/custom_nodes/wlsh_nodes/requirements.txt \
    && git clone https://github.com/M1kep/ComfyLiterals /root/comfy/ComfyUI/custom_nodes/ComfyLiterals \
    && git clone https://github.com/ai-shizuka/ComfyUI-tbox /root/comfy/ComfyUI/custom_nodes/ComfyUI-tbox \
    && git clone https://github.com/Goktug/comfyui-saveimage-plus /root/comfy/ComfyUI/custom_nodes/comfyui-saveimage-plus

# 创建目录
RUN mkdir -p /root/comfy/ComfyUI/web/extensions/Gemini_Zho \
    && mkdir /root/comfy/ComfyUI/models/clip/sd3 \
    && mkdir /root/comfy/ComfyUI/models/LLM \
    && mkdir /root/comfy/ComfyUI/models/Janus-Pro \
    && mkdir /root/comfy/ComfyUI/models/sams \
    && mkdir /root/comfy/ComfyUI/models/grounding-dino

# 下载模型
RUN modelscope download --model 'licyks/control-lora' control-lora-canny-rank256.safetensors control-lora-depth-rank256.safetensors --local-dir '/root/comfy/ComfyUI/models/controlnet/' \
    && huggingface-cli login --token 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 \
    && huggingface-cli download black-forest-labs/FLUX.1-Fill-dev ae.safetensors --local-dir /root/comfy/ComfyUI/models/vae/ \
    && huggingface-cli download comfyanonymous/flux_text_encoders t5xxl_fp16.safetensors clip_l.safetensors --local-dir /root/comfy/ComfyUI/models/clip/sd3/ \
    && huggingface-cli download oguzm/dreamshaper-xl-lightning-dpmsde dreamshaperXL_lightningDPMSDE.safetensors --local-dir /root/comfy/ComfyUI/models/checkpoints/ \
    && huggingface-cli download ShilongLiu/GroundingDINO groundingdino_swint_ogc.pth GroundingDINO_SwinT_OGC.cfg.py --local-dir /root/comfy/ComfyUI/models/grounding-dino/ \
    && huggingface-cli download Shakker-Labs/AWPortrait-FL AWPortrait-FL-lora.safetensors --local-dir /root/comfy/ComfyUI/models/loras/

# 下载其他文件
RUN wget -q -O /root/comfy/ComfyUI/models/sams/sam_vit_b_01ec64.pth https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth \
    && wget -q -O /root/comfy/ComfyUI/models/unet/flux1-dev-fp8-Kijai.safetensors https://huggingface.co/Kijai/flux-fp8/resolve/main/flux1-dev-fp8.safetensors?download=true \
    && wget -q -O /root/comfy/ComfyUI/models/upscale_models/RealESRGAN_x2plus.pth https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth

# 克隆模型仓库
RUN git clone https://huggingface.co/google-bert/bert-base-uncased /root/comfy/ComfyUI/models/bert-base-uncased \
    && git clone https://huggingface.co/microsoft/Florence-2-base /root/comfy/ComfyUI/models/LLM/Florence-2-base \
    && git clone https://huggingface.co/deepseek-ai/Janus-Pro-1B /root/comfy/ComfyUI/models/Janus-Pro/Janus-Pro-1B \
    && git clone https://huggingface.co/deepseek-ai/Janus-Pro-7B /root/comfy/ComfyUI/models/Janus-Pro/Janus-Pro-7B

# 强制重新安装 timm 并创建临时目录
RUN python -m pip install --force-reinstall timm>=0.9.16 \
    && mkdir /tmp/ckpts

# 创建目录并下载文件
RUN mkdir -p /root/comfy/ComfyUI/custom_nodes/comfyui_controlnet_aux/ckpts/lllyasviel/Annotators \
    && huggingface-cli download lllyasviel/Annotators sk_model.pth sk_model2.pth dpt_hybrid-midas-501f0c75.pt --local-dir /root/comfy/ComfyUI/custom_nodes/comfyui_controlnet_aux/ckpts/lllyasviel/Annotators/

COPY src/start.sh /root/
COPY src/rp_handler.py /root/
COPY workflow.json /root/

RUN chmod +x /root/start.sh

CMD ["/root/start.sh"]