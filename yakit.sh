#!/usr/bin/env bash
set -euo pipefail

# 不往home下写文件，相比之前的方案更简洁了，也省去过多维护。





# 把yakit放到bin目录，由于是个软链接，必须这样，不然会找不到路径
SCRIPT_REAL="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_REAL")"
cd "$SCRIPT_DIR"

# 真正数据存放目录
REAL_DATA="$HOME/.local/share/yakit-projects"
mkdir -p "$REAL_DATA"

# 临时 HOME，欺骗yakit不会在home创建 ~/yakit-projects
FAKE_HOME="$(mktemp -d)"
mkdir -p "$FAKE_HOME"

# 创建符号链接，让程序访问到真实数据
ln -s "$REAL_DATA" "$FAKE_HOME/yakit-projects"

# GPU/Wayland flags
YAKIT_FLAGS=(
  "--ozone-platform=wayland"
  "--enable-wayland-ime"
  "--ignore-gpu-blocklist"
  "--enable-gpu-rasterization"
  "--canvas-oop-rasterization"
  "--enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer,VaapiVideoDecodeLinuxGL,VaapiIgnoreDriverChecks,CanvasOopRasterization,OverlayScrollbars"
  "--enable-zero-copy"
)

# 启动程序，HOME 指向临时目录，同时带上 GPU/Wayland flags
HOME="$FAKE_HOME" exec "./release/linux-unpacked/yakit" "${YAKIT_FLAGS[@]}" "$@"
