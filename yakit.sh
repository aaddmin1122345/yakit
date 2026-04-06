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

# 只映射主题相关路径，避免把整份 ~/.config 和 ~/.local/share 带进去，
# 否则 Electron/Chromium 的配置与 GPU 缓存也会被复用，容易把渲染路径搞坏。
mkdir -p "$FAKE_HOME/.config" "$FAKE_HOME/.local/share"
for rel in \
  ".config/dconf" \
  ".config/gtk-3.0" \
  ".config/gtk-4.0" \
  ".config/kdeglobals" \
  ".config/kcminputrc" \
  ".config/qt5ct" \
  ".config/qt6ct" \
  ".config/xsettingsd" \
  ".icons" \
  ".themes" \
  ".local/share/glib-2.0" \
  ".local/share/icons" \
  ".local/share/themes" \
  ".local/share/color-schemes"; do
  src="$REAL_HOME/$rel"
  dst="$FAKE_HOME/$rel"
  parent="$(dirname "$dst")"
  if [[ -e "$src" && ! -e "$dst" ]]; then
    mkdir -p "$parent"
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

# Wayland 下启用基础平台参数。
# GPU 固定走 OpenGL 加速，不再保留模式切换。
YAKIT_FLAGS=()
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  YAKIT_FLAGS+=(
    "--ozone-platform=wayland"
    "--enable-wayland-ime"
  )
fi

YAKIT_FLAGS+=(
  "--ignore-gpu-blocklist"
  "--enable-gpu-rasterization"
  "--enable-zero-copy"
  "--enable-features=WaylandWindowDecorations,CanvasOopRasterization,OverlayScrollbars,WebRTCPipeWireCapturer,VaapiIgnoreDriverChecks,AcceleratedVideoEncoder,AcceleratedVideoDecodeLinuxZeroCopyGL"
)

# 只对 yakit 进程注入临时 HOME，真实数据目录仍然是 ~/.local/share/yakit-projects。
HOME="$FAKE_HOME" \
XDG_CONFIG_HOME="$FAKE_HOME/.config" \
XDG_DATA_HOME="$FAKE_HOME/.local/share" \
XDG_CACHE_HOME="$FAKE_HOME/.cache" \
"$APP_BIN" "${YAKIT_FLAGS[@]}" "$@"
