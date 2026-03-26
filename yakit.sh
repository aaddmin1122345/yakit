#!/usr/bin/env bash
set -euo pipefail

# 把yakit放到bin目录，由于是个软链接，必须这样，不然会找不到路径
SCRIPT_REAL="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_REAL")"
cd "$SCRIPT_DIR"

APP_BIN="./release/linux-unpacked/yakit"
[[ -x "$APP_BIN" ]] || {
  echo "error: 可执行文件不存在或不可执行: $APP_BIN" >&2
  exit 1
}

# 真正数据存放目录
REAL_DATA="$HOME/.local/share/yakit-projects"
mkdir -p "$REAL_DATA"

# 临时 HOME，欺骗yakit不会在home创建 ~/yakit-projects
FAKE_HOME="$(mktemp -d)"
mkdir -p "$FAKE_HOME"
cleanup() {
  rm -rf "$FAKE_HOME"
}
trap cleanup EXIT INT TERM

# 创建符号链接，让程序访问到真实数据
ln -s "$REAL_DATA" "$FAKE_HOME/yakit-projects"

# Wayland 下使用更激进的图形参数；X11 默认不强推。
YAKIT_FLAGS=()
if [[ "${YAKIT_USE_WAYLAND:-auto}" == "1" || "${YAKIT_USE_WAYLAND:-auto}" == "true" || ( "${YAKIT_USE_WAYLAND:-auto}" == "auto" && -n "${WAYLAND_DISPLAY:-}" ) ]]; then
  YAKIT_FLAGS+=(
    "--ozone-platform=wayland"
    "--enable-wayland-ime"
    "--ignore-gpu-blocklist"
    "--enable-gpu-rasterization"
    "--canvas-oop-rasterization"
    "--enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer,VaapiVideoDecodeLinuxGL,VaapiIgnoreDriverChecks,CanvasOopRasterization,OverlayScrollbars"
    "--enable-zero-copy"
  )
fi

# 启动程序，HOME 指向临时目录，同时带上 GPU/Wayland flags
HOME="$FAKE_HOME" "$APP_BIN" "${YAKIT_FLAGS[@]}" "$@"
