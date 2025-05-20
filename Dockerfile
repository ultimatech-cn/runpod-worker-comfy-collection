FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

# Prevent prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive

ENV TZ="Etc/UTC"

# Define paths
ENV COMFYUI_PATH=/root/comfy/ComfyUI

ENV VENV_PATH=/venv

RUN apt-get update && apt-get install -y \
    curl \
    git \
    ffmpeg \
    wget

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

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
RUN comfy --skip-prompt install --nvidia --cuda-version 12.4

# Install required Python packages within the virtual environment
RUN /venv/bin/python -m pip install \
    opencv-python \
    imageio-ffmpeg \
    hf_transfer \
    onnx \
    "huggingface_hub[hf_transfer]==0.26.2" \
    runpod

# Create necessary directories
RUN mkdir -p \
    $COMFYUI_PATH/models/ultralytics/segm \
    $COMFYUI_PATH/user/default/ComfyUI-Impact-Subpack

# Download models using the virtual environment's tools
RUN huggingface-cli login --token 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
RUN huggingface-cli download black-forest-labs/FLUX.1-Fill-dev ae.safetensors --local-dir $COMFYUI_PATH/models/vae/
RUN huggingface-cli download comfyanonymous/flux_text_encoders t5xxl_fp8_e4m3fn.safetensors clip_l.safetensors --local-dir $COMFYUI_PATH/models/clip/
RUN huggingface-cli download frankjoshua/juggernautXL_version6Rundiffusion juggernautXL_version6Rundiffusion.safetensors --local-dir $COMFYUI_PATH/models/checkpoints/
RUN huggingface-cli download Bingsu/adetailer person_yolov8m-seg.pt --local-dir $COMFYUI_PATH/models/ultralytics/segm/
RUN huggingface-cli download alimama-creative/FLUX.1-Turbo-Alpha diffusion_pytorch_model.safetensors --local-dir $COMFYUI_PATH/models/loras/
RUN huggingface-cli download ostris/OpenFLUX.1 openflux1-v0.1.0-fast-lora.safetensors --local-dir $COMFYUI_PATH/models/loras/

RUN mv ComfyUI/models/loras/diffusion_pytorch_model.safetensors ComfyUI/models/loras/FLUX_1-Turbo-Alpha.safetensors

# Download other necessary files
RUN RUN wget -q -O ComfyUI/models/unet/fluxmania_V.safetensors "https://civitai.com/api/download/models/1539776?token=6046bea046d4fef4b2d55909b4512f1d"

RUN git clone https://github.com/ltdrdata/ComfyUI-Manager $COMFYUI_PATH/custom_nodes/comfyui-manager && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack $COMFYUI_PATH/custom_nodes/comfyui-impact-pack && \
    python -s -m pip install -r $COMFYUI_PATH/custom_nodes/comfyui-impact-pack/requirements.txt && \
    git clone https://github.com/rgthree/rgthree-comfy.git $COMFYUI_PATH/custom_nodes/rgthree-comfy && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git $COMFYUI_PATH/custom_nodes/ComfyUI-KJNodes && \
    python -m pip install -r $COMFYUI_PATH/custom_nodes/ComfyUI-KJNodes/requirements.txt && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git $COMFYUI_PATH/custom_nodes/ComfyUI-Impact-Subpack && \
    python -m pip install -r $COMFYUI_PATH/custom_nodes/ComfyUI-Impact-Subpack/requirements.txt && \
    git clone https://github.com/calcuis/gguf.git $COMFYUI_PATH/custom_nodes/gguf && \
    git clone https://github.com/jjkramhoeft/ComfyUI-Jjk-Nodes.git $COMFYUI_PATH/custom_nodes/ComfyUI-Jjk-Nodes && \
    git clone https://github.com/MzMaXaM/ComfyUi-MzMaXaM.git $COMFYUI_PATH/custom_nodes/ComfyUi-MzMaXaM

# Copy necessary scripts and configuration files into the container
COPY src/start.sh /root/
COPY src/rp_handler.py /root/
COPY workflow.json /root/
COPY config.ini $COMFYUI_PATH/user/default/ComfyUI-Manager/config.ini
COPY model-whitelist.txt $COMFYUI_PATH/user/default/ComfyUI-Impact-Subpack/model-whitelist.txt

# Make the startup script executable
RUN chmod +x /root/start.sh

# Define the default command to run when the container starts
CMD ["/root/start.sh"]
