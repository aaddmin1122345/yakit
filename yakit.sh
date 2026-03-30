#!/usr/bin/env bash
set -euo pipefail

# 把 yakit 放到 bin 目录，由于是个软链接，必须这样，不然会找不到路径
SCRIPT_REAL="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_REAL")"
cd "$SCRIPT_DIR"

APP_BIN="./release/linux-unpacked/yakit"
[[ -x "$APP_BIN" ]] || {
  echo "error: 可执行文件不存在或不可执行: $APP_BIN" >&2
  exit 1
}

REAL_HOME="$HOME"
REAL_DATA="$REAL_HOME/.local/share/yakit-projects"
mkdir -p "$REAL_DATA"

# 临时 HOME 只给 yakit 进程用，宿主机真实 HOME 不变。
FAKE_HOME="$(mktemp -d)"
cleanup() {
  rm -rf "$FAKE_HOME"
}
trap cleanup EXIT INT TERM

# 让程序眼中的 ~/yakit-projects 实际落到 ~/.local/share/yakit-projects。
ln -s "$REAL_DATA" "$FAKE_HOME/yakit-projects"

# 主题、鼠标指针和 GTK 配置通常依赖这些用户目录。
# 这里只暴露读取所需的常见路径，避免因为临时 HOME 变空而丢失桌面主题。
mkdir -p "$FAKE_HOME/.local"
for rel in ".config" ".icons" ".themes" ".local/share"; do
  src="$REAL_HOME/$rel"
  dst="$FAKE_HOME/$rel"
  if [[ -e "$src" && ! -e "$dst" ]]; then
    ln -s "$src" "$dst"
  fi
done

for rel in ".gtkrc-2.0" ".Xresources" ".Xauthority"; do
  src="$REAL_HOME/$rel"
  dst="$FAKE_HOME/$rel"
  if [[ -e "$src" && ! -e "$dst" ]]; then
    ln -s "$src" "$dst"
  fi
done

# Wayland 下只启用基础平台参数。
# GPU 默认走安全模式，避免某些驱动在 Skia / GLSL 上炸 shader。
YAKIT_FLAGS=()
if [[ "${YAKIT_USE_WAYLAND:-auto}" == "1" || "${YAKIT_USE_WAYLAND:-auto}" == "true" || ( "${YAKIT_USE_WAYLAND:-auto}" == "auto" && -n "${WAYLAND_DISPLAY:-}" ) ]]; then
  YAKIT_FLAGS+=(
    "--ozone-platform=wayland"
    "--enable-wayland-ime"
  )
fi

case "${YAKIT_GPU_MODE:-safe}" in
  native)
    YAKIT_FLAGS+=(
      "--ignore-gpu-blocklist"
      "--enable-gpu-rasterization"
      "--canvas-oop-rasterization"
      "--enable-zero-copy"
      "--enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer,VaapiVideoDecodeLinuxGL,VaapiIgnoreDriverChecks,CanvasOopRasterization,OverlayScrollbars"
    )
    ;;
  safe)
    YAKIT_FLAGS+=(
      "--disable-gpu"
      "--disable-gpu-rasterization"
      "--disable-zero-copy"
      "--disable-features=VaapiVideoDecodeLinuxGL,VaapiIgnoreDriverChecks,CanvasOopRasterization"
    )
    ;;
  minimal)
    YAKIT_FLAGS+=(
      "--enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer,OverlayScrollbars"
    )
    ;;
  *)
    echo "warn: 未知的 YAKIT_GPU_MODE=${YAKIT_GPU_MODE}，回退到 safe" >&2
    YAKIT_FLAGS+=(
      "--disable-gpu"
      "--disable-gpu-rasterization"
      "--disable-zero-copy"
      "--disable-features=VaapiVideoDecodeLinuxGL,VaapiIgnoreDriverChecks,CanvasOopRasterization"
    )
    ;;
esac

# 只对 yakit 进程注入临时 HOME，真实数据目录仍然是 ~/.local/share/yakit-projects。
HOME="$FAKE_HOME" "$APP_BIN" "${YAKIT_FLAGS[@]}" "$@"
