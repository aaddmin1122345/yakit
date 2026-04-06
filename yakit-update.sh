#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Yakit update script (Fork Workflow + Audit)
# ==============================================================================

# ---- 本地路径配置 ------------------------------------------------------------
PROJECT_PATH="$HOME/.local/share/yakit"

SCRIPT_REAL="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_REAL")"
cd "$SCRIPT_DIR"

UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# ==============================================================================
# UI 辅助函数 (确保 need 函数定义完整)
# ==============================================================================
sep()  { echo "------------------------------------------------------------------------"; }
ok()   { echo -e "\033[32m✅ $*\033[0m"; }
info() { echo -e "\033[34mℹ️  $*\033[0m"; }
step() { echo -e "\033[35m▶️  $*\033[0m"; }
warn() { echo -e "\033[33m⚠️  $*\033[0m"; }
fail() { echo -e "\033[31m❌ $*\033[0m" >&2; exit 1; }

# 核心依赖检查函数
need() {
    command -v "$1" >/dev/null 2>&1 || fail "缺少依赖：$1"
}

# ==============================================================================
# HTTP 辅助函数
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
# Git 辅助函数
# ==============================================================================
ensure_clean_worktree() {
  if [[ "${YAKIT_SKIP_CLEAN_CHECK:-0}" == "1" ]]; then
      warn "已跳过工作区检查 (YAKIT_SKIP_CLEAN_CHECK=1)"
      return 0
  fi
  git diff --quiet && git diff --cached --quiet || fail "工作区不干净，请先提交或 stash 你的改动；或临时设置 YAKIT_SKIP_CLEAN_CHECK=1"
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

# 敏感文件审计：在对齐 base 之前检查官方是否动了你的核心逻辑
check_sensitive_modifications() {
    local new_tag="$1"
    local new_tag_ref="refs/tags/$new_tag"
    local sensitive_files=(
        # 开启系统自带标题栏
        "app/main/index.js" 
        # 这个应该是双击流量出现的界面，只有Windiws才开启winUI
        "app/renderer/src/main/src/components/BaseTitleBar/index.tsx"
        # 判断系统是否是windwos，只有Windows才开启winUI
        "app/renderer/src/main/src/components/layout/UILayout.tsx"
        # 修改首页默认项目备注
        "app/renderer/src/main/src/pages/softwareSettings/ProjectManage.tsx"
        # 自己项目的说明
        "README.md"
    )

    if ! git rev-parse -q --verify "refs/heads/base" >/dev/null; then
        warn "未找到本地 base 分支，跳过敏感文件审计（首次运行可忽略）。"
        return 0
    fi
    git rev-parse -q --verify "$new_tag_ref" >/dev/null || fail "tag 不存在：$new_tag"

    info "正在审计官方更新是否触及敏感文件..."
    local found_change=0

    for file in "${sensitive_files[@]}"; do
        if ! git diff --quiet "base..$new_tag_ref" -- "$file"; then
            warn "检测到官方修改了敏感文件: $file"
            git log --oneline --color "base..$new_tag_ref" -- "$file" | sed 's/^/    - /'
            found_change=1
        fi
    done

    if [[ "$found_change" -eq 1 ]]; then
        sep
        echo -e "\033[1;31m!!! 注意：官方已对你修改过的敏感文件进行了更新 !!!\033[0m"
        echo "建议执行: git diff base..my-yakit -- <文件名> 来手动核对。"
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
# Yak 引擎与插件处理
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

download_yak_engine() {
    local release_json="$1"
    local tag asset_url
    tag=$(echo "$release_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')
    asset_url=$(echo "$release_json" | python3 -c '
import json,sys
r=json.load(sys.stdin)
for a in r.get("assets",[]):
    if a.get("name")=="yak_linux_amd64":
        print(a["browser_download_url"])
        break
')

    info "[Yak] Tag = $tag"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"; trap - RETURN' RETURN

    curl -fL -A "$UA" "$asset_url" -o "$tmp_dir/yak_linux_amd64"
    chmod +x "$tmp_dir/yak_linux_amd64"

    mkdir -p "$PROJECT_PATH/yak-engine"
    command cp -f "$tmp_dir/yak_linux_amd64" "$PROJECT_PATH/yak-engine/yak"

    mkdir -p bins/bins
    command cp -f "$tmp_dir/yak_linux_amd64" "bins/bins/yak_linux_amd64"
    (cd bins && zip -9 -r yak_linux_amd64.zip bins/yak_linux_amd64 >/dev/null)
    rm -rf bins/bins
    echo "$tag" > bins/engine-version.txt
}

download_chrome_extension() {
    local chrome_tag="$1"
    mkdir -p bins/scripts
    curl -fL -A "$UA" \
        "https://github.com/yaklang/yaklang-chrome-extension/releases/download/${chrome_tag}/yakit-chrome-extension-${chrome_tag}.zip" \
        -o "bins/scripts/google-chrome-plugin.zip"
}

# ==============================================================================
# 构建流程
# ==============================================================================
build_if_renderer_changed() {
    if git diff --name-only base..HEAD | grep -q '^app/renderer/'; then
        step "Renderer 发生变化，执行构建..."
        yarn build-renders
    else
        info "Renderer 无变化，跳过构建。"
    fi
}

cleanup_release_artifacts() {
    rm -rf \
        ./release/linux-arm64-unpacked \
        ./release/.icon-set
    rm -f \
        ./release/*-linux-arm64.yml \
        ./release/*.AppImage \
        ./release/builder-debug.yml \
        ./release/builder-effective-config.yaml
    ok "已清理 arm64 与构建残留文件。"
}

copy_system_mode_file() {
    local src="bins/yakit-system-mode.txt"
    local target_dir="./release/linux-unpacked/bins"

    [[ -f "$src" ]] || fail "缺少文件：$src"
    mkdir -p "$target_dir"
    command cp -f "$src" "$target_dir/"
    ok "已补充 system mode 文件到 linux-unpacked。"
}

pack_linux() {
    step "执行正常版 Linux x64 打包..."
    [[ -x ./node_modules/.bin/env-cmd ]] || fail "缺少依赖：./node_modules/.bin/env-cmd，请先执行 yarn"
    [[ -x ./node_modules/.bin/electron-builder ]] || fail "缺少依赖：./node_modules/.bin/electron-builder，请先执行 yarn"
    ./node_modules/.bin/env-cmd -e nonSignNormal -r packageScript/.env-cmdrc \
        ./node_modules/.bin/electron-builder build --linux AppImage --x64 --config ./packageScript/electron-builder.config.js
}

# ==============================================================================
# Main
# ==============================================================================
main() {
    # 逐个检查依赖，避免循环解析错误
    need git
    need curl
    need python3
    need zip
    need unzip
    need yarn

    ensure_clean_worktree

    step "[0/6] 拉取远端仓库最新信息"
    git_fetch_all

    step "[1/6] 获取官方最新 Release Tag"
    local yakit_tag
    yakit_tag="$(get_latest_release_tag "yaklang/yakit")"
    [[ -n "$yakit_tag" ]] || fail "无法获取 Tag 名称"
    info "[Yakit] Latest Tag: $yakit_tag"

    # 审计
    check_sensitive_modifications "$yakit_tag"

    step "[2/6] 将 base 分支对齐到官方新版本"
    sync_base_to_tag "$yakit_tag"

    step "[3/6] 准备变基"
    step "[4/6] 执行变基逻辑"
    rebase_my_branch_onto_base

    step "[5/6] 推送分支到个人仓库"
    push_my_branch
    sep

    step "[Yak] 下载并准备引擎"
    mkdir -p bins
    local yak_json
    yak_json="$(select_default_yak_release_json)"
    download_yak_engine "$yak_json"

    step "[Chrome] 获取最新插件"
    local chrome_tag
    chrome_tag="$(get_latest_release_tag "yaklang/yaklang-chrome-extension")"
    download_chrome_extension "$chrome_tag"
    sep

    step "[Build] 开始构建流程"
    cleanup_release_artifacts
    build_if_renderer_changed
    pack_linux
    copy_system_mode_file

    cleanup_release_artifacts
    ok "Yakit 更新并构建成功！"
}

main "$@"
