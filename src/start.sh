#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

echo "worker-comfyui: Starting ComfyUI"
comfy launch -- --listen 0.0.0.0 --port 8188 &

echo "worker-comfyui: Starting RunPod Handler"
python -u /root/rp_handler.py