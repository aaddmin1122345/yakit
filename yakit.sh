#!/usr/bin/env bash
set -euo pipefail

# 1. 路径锁定
# 必须先跳进你的项目根目录，否则 ./release/linux-unpacked/yakit 会报找不到文件
SCRIPT_REAL="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_REAL")"
cd "$SCRIPT_DIR"

# 2. 核心路径配置 (与你的 update 脚本保持一致)
# 真实数据存放地
YAKIT_STORAGE="$HOME/.local/share/yakit"
# 软件硬编码想要生成的“屎路径”
SHIT_PATH="$HOME/yakit-projects"

# 3. 环境变量 (针对 AMD 680M + Wayland 优化)
export NVD_BACKEND=direct

# 4. 执行 bwrap
# --dev-bind / / : 共享系统环境（驱动、库、字体）
# --bind "$YAKIT_STORAGE" "$SHIT_PATH" : 魔法重定向
exec bwrap \
    --dev-bind / / \
    --bind "$YAKIT_STORAGE" "$SHIT_PATH" \
    --setenv YAKIT_HOME "$YAKIT_STORAGE" \
    --setenv XDG_RUNTIME_DIR "/run/user/$(id -u)" \
    "./release/linux-unpacked/yakit" \
    --no-sandbox \
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
