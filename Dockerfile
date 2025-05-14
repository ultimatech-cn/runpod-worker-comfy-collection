FROM python:3.11.10-slim-bookworm

# Prevent prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ="Etc/UTC"

# Define paths
ENV COMFYUI_PATH=/root/comfy/ComfyUI
ENV VENV_PATH=/venv

# Update package lists and install necessary system packages
RUN apt-get update && \
    # Set debconf frontend to noninteractive to suppress prompts
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt-get install -y \
        gcc \
        gfortran \
        build-essential \
        git \
        wget \
        libgl1 \
        ffmpeg \
        curl && \
    # Install git-lfs
    curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    apt-get install -y git-lfs && \
    git lfs install && \
    # Clean up to reduce image size
    apt-get autoremove -y && apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# Create a virtual environment
RUN python -m venv $VENV_PATH

# Ensure that the virtual environment's bin directory is in the PATH
# This makes 'python' and '/venv/bin/python -m pip' point to the venv's executables by default
ENV PATH="$VENV_PATH/bin:$PATH"

# Upgrade /venv/bin/python -m pip within the virtual environment
RUN /venv/bin/python -m pip install --upgrade pip

# Install comfy-cli within the virtual environment
RUN /venv/bin/python -m pip install comfy-cli

# Install ComfyUI using comfy-cli within the virtual environment
RUN comfy --skip-prompt install --nvidia --cuda-version 12.6

# Install required Python packages within the virtual environment
RUN /venv/bin/python -m pip install \
    "fastapi[standard]==0.115.4" \
    opencv-python \
    imageio-ffmpeg \
    hf_transfer \
    scikit-image \
    matplotlib \
    onnx \
    modelscope \
    transformers \
    "huggingface_hub[hf_transfer]==0.26.2" \
    runpod

# Clone custom node repositories and install their Python dependencies
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager /root/comfy/ComfyUI/custom_nodes/comfyui-manager
RUN git clone https://github.com/Fannovel16/comfyui_controlnet_aux /root/comfy/ComfyUI/custom_nodes/comfyui_controlnet_aux \
    && /venv/bin/python -m pip install -r /root/comfy/ComfyUI/custom_nodes/comfyui_controlnet_aux/requirements.txt
RUN git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git /root/comfy/ComfyUI/custom_nodes/ComfyUI-Custom-Scripts
RUN git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack /root/comfy/ComfyUI/custom_nodes/comfyui-impact-pack \
    && /venv/bin/python -m pip install -r /root/comfy/ComfyUI/custom_nodes/comfyui-impact-pack/requirements.txt
RUN git clone https://github.com/chflame163/ComfyUI_LayerStyle /root/comfy/ComfyUI/custom_nodes/ComfyUI_LayerStyle \
    && /venv/bin/python -m pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI_LayerStyle/requirements.txt
RUN git clone https://github.com/yolain/ComfyUI-Easy-Use /root/comfy/ComfyUI/custom_nodes/ComfyUI-Easy-Use \
    && /venv/bin/python -m pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-Easy-Use/requirements.txt
RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git /root/comfy/ComfyUI/custom_nodes/ComfyUI-KJNodes \
    && /venv/bin/python -m pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-KJNodes/requirements.txt
RUN git clone https://github.com/jags111/efficiency-nodes-comfyui /root/comfy/ComfyUI/custom_nodes/efficiency-nodes-comfyui \
    && /venv/bin/python -m pip install -r /root/comfy/ComfyUI/custom_nodes/efficiency-nodes-comfyui/requirements.txt
RUN git clone https://github.com/storyicon/comfyui_segment_anything.git /root/comfy/ComfyUI/custom_nodes/comfyui_segment_anything \
    && /venv/bin/python -m pip install -r /root/comfy/ComfyUI/custom_nodes/comfyui_segment_anything/requirements.txt
RUN git clone https://github.com/pythongosssss/ComfyUI-WD14-Tagger /root/comfy/ComfyUI/custom_nodes/ComfyUI-WD14-Tagger \
    && /venv/bin/python -m pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-WD14-Tagger/requirements.txt
RUN git clone https://github.com/cubiq/ComfyUI_essentials.git /root/comfy/ComfyUI/custom_nodes/ComfyUI_essentials \
    && /venv/bin/python -m pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI_essentials/requirements.txt
RUN git clone https://github.com/ZHO-ZHO-ZHO/ComfyUI-Gemini /root/comfy/ComfyUI/custom_nodes/ComfyUI-Gemini \
    && /venv/bin/python -m pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-Gemini/requirements.txt
RUN git clone https://github.com/chrisgoringe/cg-use-everywhere /root/comfy/ComfyUI/custom_nodes/cg-use-everywhere
RUN git clone https://github.com/CY-CHENYUE/ComfyUI-Janus-Pro /root/comfy/ComfyUI/custom_nodes/ComfyUI-Janus-Pro \
    && /venv/bin/python -m pip install -r /root/comfy/ComfyUI/custom_nodes/ComfyUI-Janus-Pro/requirements.txt
RUN git clone https://github.com/melMass/comfy_mtb /root/comfy/ComfyUI/custom_nodes/comfy_mtb \
    && /venv/bin/python -m pip install -r /root/comfy/ComfyUI/custom_nodes/comfy_mtb/requirements.txt
RUN git clone https://github.com/wallish77/wlsh_nodes /root/comfy/ComfyUI/custom_nodes/wlsh_nodes \
    && /venv/bin/python -m pip install -r /root/comfy/ComfyUI/custom_nodes/wlsh_nodes/requirements.txt
RUN git clone https://github.com/M1kep/ComfyLiterals /root/comfy/ComfyUI/custom_nodes/ComfyLiterals
RUN git clone https://github.com/ai-shizuka/ComfyUI-tbox /root/comfy/ComfyUI/custom_nodes/ComfyUI-tbox
RUN git clone https://github.com/Goktug/comfyui-saveimage-plus /root/comfy/ComfyUI/custom_nodes/comfyui-saveimage-plus

# Create necessary directories
RUN mkdir -p \
    $COMFYUI_PATH/web/extensions/Gemini_Zho \
    $COMFYUI_PATH/temp/ckpts \
    $COMFYUI_PATH/models/clip/sd3 \
    $COMFYUI_PATH/models/LLM \
    $COMFYUI_PATH/models/Janus-Pro \
    $COMFYUI_PATH/models/sams \
    $COMFYUI_PATH/models/grounding-dino

# Download models using the virtual environment's tools
RUN modelscope download --model 'licyks/control-lora' control-lora-canny-rank256.safetensors control-lora-depth-rank256.safetensors --local_dir '/root/comfy/ComfyUI/models/controlnet/' && \
    huggingface-cli login --token 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 && \
    huggingface-cli download black-forest-labs/FLUX.1-Fill-dev ae.safetensors --local-dir /root/comfy/ComfyUI/models/vae/ && \
    huggingface-cli download comfyanonymous/flux_text_encoders t5xxl_fp16.safetensors clip_l.safetensors --local-dir /root/comfy/ComfyUI/models/clip/sd3/ && \
    huggingface-cli download oguzm/dreamshaper-xl-lightning-dpmsde dreamshaperXL_lightningDPMSDE.safetensors --local-dir /root/comfy/ComfyUI/models/checkpoints/ && \
    huggingface-cli download ShilongLiu/GroundingDINO groundingdino_swint_ogc.pth GroundingDINO_SwinT_OGC.cfg.py --local-dir /root/comfy/ComfyUI/models/grounding-dino/ && \
    huggingface-cli download Shakker-Labs/AWPortrait-FL AWPortrait-FL-lora.safetensors --local-dir /root/comfy/ComfyUI/models/loras/

# Download other necessary files
RUN wget -q -O $COMFYUI_PATH/models/sams/sam_vit_b_01ec64.pth https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth && \
    wget -q -O $COMFYUI_PATH/models/unet/flux1-dev-fp8-Kijai.safetensors "https://huggingface.co/Kijai/flux-fp8/resolve/main/flux1-dev-fp8.safetensors?download=true" && \
    wget -q -O $COMFYUI_PATH/models/upscale_models/RealESRGAN_x2plus.pth https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth

# Clone model repositories
RUN git clone https://huggingface.co/google-bert/bert-base-uncased $COMFYUI_PATH/models/bert-base-uncased && \
    git clone https://huggingface.co/microsoft/Florence-2-base $COMFYUI_PATH/models/LLM/Florence-2-base && \
    git clone https://huggingface.co/deepseek-ai/Janus-Pro-1B $COMFYUI_PATH/models/Janus-Pro/Janus-Pro-1B && \
    git clone https://huggingface.co/deepseek-ai/Janus-Pro-7B $COMFYUI_PATH/models/Janus-Pro/Janus-Pro-7B

# Force reinstall timm within the virtual environment
RUN /venv/bin/python -m pip install --upgrade timm==0.9.16

# Create directories and download additional files using huggingface-cli
RUN mkdir -p $COMFYUI_PATH/custom_nodes/comfyui_controlnet_aux/ckpts/lllyasviel/Annotators && \
    huggingface-cli download lllyasviel/Annotators sk_model.pth sk_model2.pth dpt_hybrid-midas-501f0c75.pt --local-dir $COMFYUI_PATH/custom_nodes/comfyui_controlnet_aux/ckpts/lllyasviel/Annotators/

# Copy necessary scripts and configuration files into the container
COPY src/start.sh /root/
COPY src/rp_handler.py /root/
COPY workflow.json /root/
COPY config.ini $COMFYUI_PATH/user/default/ComfyUI-Manager/config.ini

# Make the startup script executable
RUN chmod +x /root/start.sh

RUN /venv/bin/python -c "import timm; print('timm version:', timm.__version__); import timm.layers"

# Define the default command to run when the container starts
CMD ["/root/start.sh"]
