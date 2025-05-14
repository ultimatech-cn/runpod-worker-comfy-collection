#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

python -c 'import timm; from timm.layers import LayerNorm2d; print("Success!")'

echo "worker-comfyui: Starting ComfyUI"
python /root/comfy/ComfyUI/main.py --disable-auto-launch --listen 0.0.0.0 --port 8188 &

echo "worker-comfyui: Starting RunPod Handler"
python -u /root/rp_handler.py
