#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Yakit update script (fork workflow + Audit)
#
# 目标：
#   1) 自动检测官方是否修改了你维护的敏感文件
#   2) base 分支始终对齐官方 yaklang/yakit 最新 release tag
#   3) my-yakit 分支在 base 之上 rebase（叠加你的改动）
#   4) 下载引擎/插件并执行打包
# ==============================================================================

# ---- Local paths -------------------------------------------------------------
PROJECT_PATH="$HOME/.local/share/yakit"

SCRIPT_REAL="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_REAL")"
cd "$SCRIPT_DIR"

UA="Mozilla/5.0 (Macintosh; U; PPC Mac OS X 10_11_1 rv:5.0; hsb-DE) AppleWebKit/532.17.5 (KHTML, like Gecko) Version/4.0 Safari/532.17.5"

# ==============================================================================
# UI helpers
# ==============================================================================
sep()  { echo "------------------------------------------------------------------------"; }
ok()   { echo -e "\033[32m✅ $*\033[0m"; }
info() { echo -e "\033[34mℹ️  $*\033[0m"; }
step() { echo -e "\033[35m▶️  $*\033[0m"; }
warn() { echo -e "\033[33m⚠️  $*\033[0m"; }
fail() { echo -e "\033[31m❌ $*\033[0m" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || fail "缺少依赖：$1"; }

# ==============================================================================
# HTTP helpers
# ==============================================================================
curl_json_to_file() {
  local url="$1"
  local out="$2"
  curl -fSL -A "$UA" "$url" -o "$out" || fail "curl 失败：$url"
  [[ -s "$out" ]] || fail "返回为空：$url"
  local first
  first="$(head -c 1 "$out" || true)"
  if [[ "$first" != "{" && "$first" != "[" ]]; then
    fail "返回不是 JSON：$url"
  fi
}

# ==============================================================================
# Git helpers
# ==============================================================================
ensure_clean_worktree() {
  git diff --quiet && git diff --cached --quiet || fail "工作区不干净，先提交或 stash 你的改动"
}

git_fetch_all() {
  git fetch --prune origin
  git fetch --prune upstream --tags
}

get_latest_release_tag() {
  local repo="$1"
  local tmp
  tmp="$(mktemp)"
  curl_json_to_file "https://api.github.com/repos/${repo}/releases/latest" "$tmp"
  python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag_name",""))' < "$tmp"
  rm -f "$tmp"
}

# 核心审计函数：对比旧 base 和新 Tag 之间的文件差异
check_sensitive_modifications() {
  local new_tag="$1"
  # 你维护的敏感文件列表
  local sensitive_files=(
    "app/main/index.js"
    "app/renderer/src/main/src/components/BaseTitleBar/index.tsx"
    "app/renderer/src/main/src/components/layout/UILayout.tsx"
    "app/renderer/src/main/src/pages/softwareSettings/ProjectManage.tsx"
    "README.md"
  )

  info "正在审计官方更新是否触及敏感文件..."
  local found_change=0

  for file in "${sensitive_files[@]}"; do
    # 检查当前本地 base 分支和即将更新的 tag 之间的差异
    if ! git diff --quiet "base..$new_tag" -- "$file" 2>/dev/null; then
      warn "检测到官方修改了敏感文件: $file"
      # 显示官方的具体提交简述，方便你判断
      git log --oneline --color "base..$new_tag" -- "$file" | sed 's/^/    - /'
      found_change=1
    fi
  done

  if [[ "$found_change" -eq 1 ]]; then
    sep
    echo -e "\033[1;31m!!! 注意：官方已对你修改过的文件进行了更新 !!!\033[0m"
    echo "建议稍后执行: git diff base..my-yakit -- <文件名> 来手动核对逻辑。"
    read -p "按回车键[Enter]接受改动并继续变基，或 [Ctrl+C] 退出手动检查..."
  else
    ok "审计通过：关键文件未发现冲突性官方改动。"
  fi
}

sync_base_to_tag() {
  local tag="$1"
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null \
    || fail "tag 不存在：$tag"
  git switch -C base "$tag"
}

rebase_my_branch_onto_base() {
  step "执行变基: my-yakit -> base"
  git switch my-yakit
  if ! git rebase base; then
    warn "变基出现冲突！"
    echo "请手动修复冲突后执行: git rebase --continue"
    fail "自动化脚本已暂停。"
  fi
}

push_my_branch() {
  git push origin my-yakit --force-with-lease
}

# ==============================================================================
# Yak engine helpers (保持原逻辑)
# ==============================================================================
select_default_yak_release_json() {
  local tmp
  tmp="$(mktemp)"
  curl_json_to_file "https://api.github.com/repos/yaklang/yaklang/releases?per_page=30" "$tmp"
  python3 -c '
import json,sys
rels=json.load(sys.stdin)
for r in rels:
    if any(a.get("name")=="yak_linux_amd64" for a in r.get("assets",[])):
        import json as _json
        print(_json.dumps(r))
        sys.exit(0)
raise SystemExit("No release contains asset yak_linux_amd64")
' < "$tmp"
  rm -f "$tmp"
}

extract_tag_from_release_json() {
  python3 -c 'import json,sys; r=json.loads(sys.stdin.read()); print(r["tag_name"])'
}

extract_asset_url_from_release_json() {
  python3 -c '
import json,sys
r=json.loads(sys.stdin.read())
for a in r.get("assets",[]):
    if a.get("name")=="yak_linux_amd64":
        print(a["browser_download_url"])
        break
else:
    raise SystemExit("asset not found")
'
}

download_yak_engine() {
  local release_json="$1"
  local tag asset_url
  tag="$(printf "%s" "$release_json" | extract_tag_from_release_json)"
  asset_url="$(printf "%s" "$release_json" | extract_asset_url_from_release_json)"

  info "[Yak] Tag = $tag"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"; trap - RETURN' RETURN

  curl -fL -A "$UA" "$asset_url" -o "$tmp_dir/yak_linux_amd64"
  chmod +x "$tmp_dir/yak_linux_amd64"

  command cp -f "$tmp_dir/yak_linux_amd64" "$PROJECT_PATH/yak-engine/yak"
  mkdir -p bins
  command mv -f "$tmp_dir/yak_linux_amd64" "$tmp_dir/bins/yak_linux_amd64"
  (cd "$tmp_dir" && zip -9 -r out.zip bins/yak_linux_amd64 >/dev/null)
  command mv -f "$tmp_dir/out.zip" "bins/yak_linux_amd64.zip"
  echo "$tag" > bins/engine-version.txt
}

# ==============================================================================
# Chrome & Build helpers (保持原逻辑)
# ==============================================================================
download_chrome_extension() {
  local chrome_tag="$1"
  mkdir -p bins/scripts
  curl -fL -A "$UA" \
    "https://github.com/yaklang/yaklang-chrome-extension/releases/download/${chrome_tag}/yakit-chrome-extension-${chrome_tag}.zip" \
    -o "bins/scripts/google-chrome-plugin.zip"
}

build_if_renderer_changed() {
  if git diff --name-only base..HEAD | grep -q '^app/renderer/'; then
    step "Renderer 发生变化，执行构建..."
    yarn build-renders
  else
    info "Renderer 无变化，跳过构建。"
  fi
}

pack_linux() {
  step "执行打包流程..."
  yarn pack-linux
}

cleanup_appimage() {
  rm -rf ./release/*.AppImage
  ok "清理完成。"
}

# ==============================================================================
# Main
# ==============================================================================
main() {
  for c in git curl python3 zip unzip yarn; do need "$c"; done
  ensure_clean_worktree

  step "[0/6] 拉取远端仓库最新信息..."
  git_fetch_all

  step "[1/6] 获取官方最新 Release Tag"
  local yakit_tag
  yakit_tag="$(get_latest_release_tag "yaklang/yakit")"
  [[ -n "$yakit_tag" ]] || fail "无法获取 Tag 名称"
  info "[Yakit] Latest Tag: $yakit_tag"

  # --- 审计步骤：这是你最需要的监控功能 ---
  check_sensitive_modifications "$yakit_tag"

  step "[2/6] 将 base 分支对齐到官方新版本"
  sync_base_to_tag "$yakit_tag"

  step "[3/6] 切换分支并准备变基"
  step "[4/6] 执行变基逻辑"
  rebase_my_branch_onto_base

  step "[5/6] 推送洗白后的分支到个人仓库"
  push_my_branch
  sep

  step "[Yak] 下载并准备引擎"
  local yak_release_json
  yak_release_json="$(select_default_yak_release_json)"
  download_yak_engine "$yak_release_json"

  step "[Chrome] 获取最新插件"
  local chrome_tag
  chrome_tag="$(get_latest_release_tag "yaklang/yaklang-chrome-extension")"
  download_chrome_extension "$chrome_tag"
  sep

  step "[Build] 开始构建流程"
  build_if_renderer_changed
  pack_linux

  cleanup_appimage
  ok "Yakit 更新并构建成功！"
  info "现在可以运行 ./yakit.sh 启动隔离环境下的 Yakit 了。"
}

main "$@"
