#!/usr/bin/env bash

set -euo pipefail

# 1. 确保路径鲁棒性
SCRIPT_REAL="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_REAL")"
cd "$SCRIPT_DIR"

# 2. 环境变量配置
# 使用默认值赋值，允许外部临时覆盖 YAKIT_HOME
export YAKIT_HOME="$HOME/.local/share/yakit"
# 针对 AMD 驱动在 Wayland 下的显示优化
export NVD_BACKEND=direct

# 3. 启动参数优化
exec "$SCRIPT_DIR/release/linux-unpacked/yakit" \
    --ozone-platform-hint=wayland \
    --enable-wayland-ime \
    --ignore-gpu-blocklist \
    --enable-gpu-rasterization \
    --canvas-oop-rasterization \
    --use-gl=angle \
    --use-angle=gl \
    --use-cmd-decoder=validating \
    --disable-gpu-driver-bug-workarounds \
    --disable-features=UsePassthroughCommandDecoder,SkiaGraphite,Vulkan \
    --enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer,VaapiVideoDecodeLinuxGL,VaapiIgnoreDriverChecks,CanvasOopRasterization \
    --js-flags="--max-old-space-size=8192" \
    --force-device-scale-factor=1.5 \
    "$@"
