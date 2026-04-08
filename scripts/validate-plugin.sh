#!/usr/bin/env bash
# validate-plugin.sh — 驗證 Claude Code Plugin 結構與內容
# 用法: validate-plugin.sh <plugin-dir> <repo-name> [<expected-ref>]
# 回傳: exit 0 通過, exit 1 失敗
set -euo pipefail

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PLUGIN_DIR="${1:?用法: validate-plugin.sh <plugin-dir> <repo-name> [<expected-ref>]}"
REPO_NAME="${2:?用法: validate-plugin.sh <plugin-dir> <repo-name> [<expected-ref>]}"
EXPECTED_REF="${3:-}"

ERRORS=0
WARNINGS=0

pass() {
  echo -e "  ${GREEN}✓${NC} $1"
}

fail() {
  echo -e "  ${RED}✗${NC} $1"
  ERRORS=$((ERRORS + 1))
}

warn() {
  echo -e "  ${YELLOW}⚠${NC} $1"
  WARNINGS=$((WARNINGS + 1))
}

# ===== 1. Structure 驗證 =====
echo "--- Structure validation ---"

PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"

# plugin.json 存在
if [[ ! -f "$PLUGIN_JSON" ]]; then
  fail "plugin.json 不存在: $PLUGIN_JSON"
  echo ""
  echo "驗證結果: ${ERRORS} 錯誤, ${WARNINGS} 警告"
  exit 1
fi
pass "plugin.json 存在"

# 檢查 JSON 格式
if ! jq empty "$PLUGIN_JSON" 2>/dev/null; then
  fail "plugin.json 不是有效的 JSON"
  echo ""
  echo "驗證結果: ${ERRORS} 錯誤, ${WARNINGS} 警告"
  exit 1
fi
pass "plugin.json 是有效的 JSON"

# 讀取欄位
PLUGIN_NAME=$(jq -r '.name // empty' "$PLUGIN_JSON")
PLUGIN_VERSION=$(jq -r '.version // empty' "$PLUGIN_JSON")
PLUGIN_TYPE=$(jq -r '.type // empty' "$PLUGIN_JSON")
PLUGIN_DESC=$(jq -r '.description // empty' "$PLUGIN_JSON")
PLUGIN_KEYWORDS_COUNT=$(jq -r '.keywords | length // 0' "$PLUGIN_JSON" 2>/dev/null || echo "0")
PLUGIN_AUTHOR_GITHUB=$(jq -r '.author.github // empty' "$PLUGIN_JSON")

# 必要欄位
if [[ -n "$PLUGIN_NAME" ]]; then
  pass "name 欄位存在: $PLUGIN_NAME"
else
  fail "缺少 name 欄位"
fi

if [[ -n "$PLUGIN_VERSION" ]]; then
  pass "version 欄位存在: $PLUGIN_VERSION"
else
  fail "缺少 version 欄位"
fi

if [[ -n "$PLUGIN_TYPE" ]]; then
  pass "type 欄位存在: $PLUGIN_TYPE"
else
  fail "缺少 type 欄位"
fi

if [[ -n "$PLUGIN_DESC" ]]; then
  pass "description 欄位存在"
else
  fail "缺少 description 欄位"
fi

if (( PLUGIN_KEYWORDS_COUNT >= 2 )); then
  pass "keywords 數量足夠: $PLUGIN_KEYWORDS_COUNT"
else
  fail "keywords 需要至少 2 個，目前有 ${PLUGIN_KEYWORDS_COUNT} 個"
fi

if [[ -n "$PLUGIN_AUTHOR_GITHUB" ]]; then
  pass "author.github 欄位存在: $PLUGIN_AUTHOR_GITHUB"
else
  fail "缺少 author.github 欄位"
fi

# type 是否為有效列舉值
VALID_TYPES="skill agent hook mcp mixed"
if [[ -n "$PLUGIN_TYPE" ]]; then
  if echo "$VALID_TYPES" | grep -qw "$PLUGIN_TYPE"; then
    pass "type 是有效值: $PLUGIN_TYPE"
  else
    fail "type 不是有效值: ${PLUGIN_TYPE}（必須是 skill/agent/hook/mcp/mixed）"
  fi
fi

# version 是否為 semver
if [[ -n "$PLUGIN_VERSION" ]]; then
  if [[ "$PLUGIN_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$ ]]; then
    pass "version 是有效的 semver: $PLUGIN_VERSION"
  else
    fail "version 不是有效的 semver: $PLUGIN_VERSION"
  fi
fi

# ===== 2. Naming 驗證 =====
echo ""
echo "--- Naming validation ---"

EXPECTED_REPO="plugin-${PLUGIN_NAME}"
if [[ "$REPO_NAME" == "$EXPECTED_REPO" ]]; then
  pass "repo 名稱符合: $REPO_NAME == plugin-${PLUGIN_NAME}"
else
  fail "repo 名稱不符: $REPO_NAME != $EXPECTED_REPO"
fi

# ===== 3. Content by type 驗證 =====
echo ""
echo "--- Content validation (type: ${PLUGIN_TYPE:-unknown}) ---"

# 安全的 find 包裝（避免 pipefail 下 find 非零退出碼）
safe_find() {
  find "$@" 2>/dev/null || true
}

case "$PLUGIN_TYPE" in
  skill)
    # 檢查 SKILL.md 存在且有 description frontmatter
    SKILL_MD=$(safe_find "$PLUGIN_DIR/skills" -name "SKILL.md" | head -1)
    if [[ -n "$SKILL_MD" && -f "$SKILL_MD" ]]; then
      pass "SKILL.md 存在: $SKILL_MD"
      # 檢查 frontmatter 中的 description
      if head -20 "$SKILL_MD" | grep -q "description:"; then
        pass "SKILL.md 包含 description frontmatter"
      else
        fail "SKILL.md 缺少 description frontmatter"
      fi
    else
      fail "type=skill 但找不到 skills/*/SKILL.md"
    fi
    ;;
  hook)
    HOOKS_JSON="$PLUGIN_DIR/hooks/hooks.json"
    if [[ -f "$HOOKS_JSON" ]]; then
      pass "hooks.json 存在"
      if jq empty "$HOOKS_JSON" 2>/dev/null; then
        pass "hooks.json 是有效的 JSON"
      else
        fail "hooks.json 不是有效的 JSON"
      fi
    else
      fail "type=hook 但找不到 hooks/hooks.json"
    fi
    ;;
  agent)
    AGENT_MD=$(safe_find "$PLUGIN_DIR/agents" -name "*.md" | head -1)
    if [[ -n "$AGENT_MD" && -f "$AGENT_MD" ]]; then
      pass "agent .md 存在: $AGENT_MD"
      # 檢查 frontmatter
      if head -5 "$AGENT_MD" | grep -q "^---"; then
        pass "agent .md 包含 frontmatter"
      else
        fail "agent .md 缺少 frontmatter"
      fi
    else
      fail "type=agent 但找不到 agents/*.md"
    fi
    ;;
  mcp)
    MCP_CONFIG=$(safe_find "$PLUGIN_DIR/mcp-servers" -name "*.json" | head -1)
    if [[ -n "$MCP_CONFIG" && -f "$MCP_CONFIG" ]]; then
      pass "mcp-servers config 存在"
      if jq -e '.. | .command? // empty' "$MCP_CONFIG" >/dev/null 2>&1; then
        pass "mcp config 包含 command 欄位"
      else
        fail "mcp config 缺少 command 欄位"
      fi
    else
      fail "type=mcp 但找不到 mcp-servers/*.json"
    fi
    ;;
  mixed)
    # 需要有 2+ 種內容類型
    CONTENT_TYPES=0
    [[ -n "$(safe_find "$PLUGIN_DIR/skills" -name "SKILL.md")" ]] && CONTENT_TYPES=$((CONTENT_TYPES + 1))
    [[ -n "$(safe_find "$PLUGIN_DIR/agents" -name "*.md")" ]] && CONTENT_TYPES=$((CONTENT_TYPES + 1))
    [[ -f "$PLUGIN_DIR/hooks/hooks.json" ]] && CONTENT_TYPES=$((CONTENT_TYPES + 1))
    [[ -n "$(safe_find "$PLUGIN_DIR/mcp-servers" -name "*.json")" ]] && CONTENT_TYPES=$((CONTENT_TYPES + 1))
    if (( CONTENT_TYPES >= 2 )); then
      pass "mixed plugin 有 ${CONTENT_TYPES} 種內容類型"
    else
      fail "mixed plugin 需要至少 2 種內容類型，目前有 ${CONTENT_TYPES} 種"
    fi
    ;;
esac

# ===== 4. Cross validation =====
echo ""
echo "--- Cross validation ---"

# hooks.json 只能出現在 hook/mixed 類型
if [[ -f "$PLUGIN_DIR/hooks/hooks.json" ]] && [[ "$PLUGIN_TYPE" != "hook" && "$PLUGIN_TYPE" != "mixed" ]]; then
  fail "hooks/hooks.json 存在但 type=${PLUGIN_TYPE}（只有 hook/mixed 可以有 hooks）"
else
  pass "hooks 目錄符合 type 規範"
fi

# mcp-servers 只能出現在 mcp/mixed 類型
if [[ -d "$PLUGIN_DIR/mcp-servers" ]] && [[ "$PLUGIN_TYPE" != "mcp" && "$PLUGIN_TYPE" != "mixed" ]]; then
  # 只有在目錄非空時才算錯誤
  if [[ -n "$(safe_find "$PLUGIN_DIR/mcp-servers" -name "*.json")" ]]; then
    fail "mcp-servers/ 存在但 type=${PLUGIN_TYPE}（只有 mcp/mixed 可以有 mcp-servers）"
  else
    pass "mcp-servers 目錄符合 type 規範"
  fi
else
  pass "mcp-servers 目錄符合 type 規範"
fi

# ===== 5. Version consistency =====
if [[ -n "$EXPECTED_REF" ]]; then
  echo ""
  echo "--- Version consistency ---"
  EXPECTED_VERSION_TAG="v${PLUGIN_VERSION}"
  if [[ "$EXPECTED_REF" == "$EXPECTED_VERSION_TAG" ]]; then
    pass "version tag 一致: $EXPECTED_REF == v${PLUGIN_VERSION}"
  else
    fail "version tag 不一致: $EXPECTED_REF != v${PLUGIN_VERSION}"
  fi
fi

# ===== 6. Quality warnings =====
echo ""
echo "--- Quality checks ---"

if [[ -n "$PLUGIN_DESC" ]] && (( ${#PLUGIN_DESC} < 10 )); then
  warn "description 太短（${#PLUGIN_DESC} 字元），建議至少 10 字元"
else
  pass "description 長度足夠"
fi

if [[ ! -f "$PLUGIN_DIR/README.md" ]]; then
  warn "缺少 README.md"
else
  pass "README.md 存在"
fi

# ===== 結果 =====
echo ""
echo "=== 驗證結果: ${ERRORS} 錯誤, ${WARNINGS} 警告 ==="

if (( ERRORS > 0 )); then
  exit 1
fi

exit 0
