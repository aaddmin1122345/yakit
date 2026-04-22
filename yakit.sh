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

# 这里不能再用随机 mktemp。
# 程序和引擎会把绝对路径持久化；如果每次启动 HOME 都变成不同的 /tmp/tmp.xxx，
# 下一次再打开旧项目时就会指向失效路径。改成固定的 fake HOME，路径才能稳定。
FAKE_HOME_BASE="${XDG_RUNTIME_DIR:-/tmp}"
FAKE_HOME="$FAKE_HOME_BASE/yakit-home-${USER:-$(id -u)}"

ensure_project_link() {
  local home_dir="$1"
  local link_path="$home_dir/yakit-projects"

  mkdir -p "$home_dir"
  if [[ -L "$link_path" ]]; then
    local link_target
    link_target="$(readlink -f "$link_path")"
    [[ "$link_target" == "$REAL_DATA" ]] || {
      echo "error: $link_path 已存在，但未指向 $REAL_DATA" >&2
      exit 1
    }
    return 0
  fi

  if [[ -e "$link_path" ]]; then
    echo "error: $link_path 已存在且不是符号链接，请手动处理后再启动" >&2
    exit 1
  fi

  ln -s "$REAL_DATA" "$link_path"
}

restore_legacy_tmp_links() {
  local log_root="$REAL_DATA"
  local legacy_paths=()
  local source_dirs=()

  [[ -d "$log_root/engine-log" ]] && source_dirs+=("$log_root/engine-log")
  [[ -d "$log_root/print-log" ]] && source_dirs+=("$log_root/print-log")
  [[ ${#source_dirs[@]} -eq 0 ]] && return 0

  mapfile -t legacy_paths < <(
    grep -RhoE '/tmp/tmp\.[^/]+/yakit-projects' "${source_dirs[@]}" 2>/dev/null | sort -u
  )

  local legacy_path legacy_home
  for legacy_path in "${legacy_paths[@]}"; do
    legacy_home="${legacy_path%/yakit-projects}"
    ensure_project_link "$legacy_home"
  done
}

ensure_project_link "$FAKE_HOME"
restore_legacy_tmp_links

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

# HOME 固定指向稳定的 fake HOME；这样程序里看到的 ~/yakit-projects 是固定路径，
# 但真实数据仍然通过符号链接落在 ~/.local/share/yakit-projects。
HOME="$FAKE_HOME" \
XDG_CONFIG_HOME="$FAKE_HOME/.config" \
XDG_DATA_HOME="$FAKE_HOME/.local/share" \
XDG_CACHE_HOME="$FAKE_HOME/.cache" \
"$APP_BIN" "${YAKIT_FLAGS[@]}" "$@"
