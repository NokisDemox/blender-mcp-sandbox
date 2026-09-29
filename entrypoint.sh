#!/bin/bash
# Container entrypoint: re-apply Blender preferences with the GPU present,
# print the hardware audit, then launch Blender GUI.
#
# Re-running startup_init.py at every start (not just at image build) is
# deliberate: GPU device enumeration only works when the NVIDIA device is
# attached, which is never the case during `podman build`. The script is
# idempotent, so this costs a few seconds and self-heals any drift.
set -e

echo "--> [entrypoint] Applying Blender preferences..."
blender --background --python /opt/startup_init.py

echo "--> [entrypoint] GPU audit..."
blender --background --python-expr "import gpu; print('[GPU Audit] Vendor:', gpu.platform.vendor_get(), '| Renderer:', gpu.platform.renderer_get())"

echo "--> [entrypoint] Launching Blender..."
if [ "$#" -eq 0 ]; then
  exec blender
else
  exec "$@"
fi
