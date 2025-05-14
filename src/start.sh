#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

sed -i 's/timm\.layers/timm\.models\.layers/g'  /venv/lib/python3.11/site-packages/janus/models/siglip_vit.py

rm -rf  /root/comfy/ComfyUI/custom_nodes/ComfyUI-tbox/src/timm

rm -rf /venv/lib/python3.11/site-packages/timm/models/layers

cp -r /venv/lib/python3.11/site-packages/timm/layers /venv/lib/python3.11/site-packages/timm/models/

source /venv/bin/activate

echo "worker-comfyui: Starting ComfyUI"
/venv/bin/python /root/comfy/ComfyUI/main.py --disable-auto-launch --listen 0.0.0.0 --port 8188 &

echo "worker-comfyui: Starting RunPod Handler"
/venv/bin/python -u /root/rp_handler.py
