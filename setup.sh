#!/usr/bin/env bash
# OpenClaw Squad — Interactive Installer
# https://github.com/Peters-Pans/openclaw-squad
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

info()    { echo -e "${CYAN}→${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}✗${NC} $*" >&2; exit 1; }
section() { echo; echo -e "${BOLD}── $* $(printf '%.0s─' {1..40} | head -c $((44 - ${#1})))${NC}"; }
ask()     { echo -en "${BOLD}$1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_DIR="$HOME/.openclaw"
AGENTS_DIR="$OPENCLAW_DIR/agents"

# ── Platform ──────────────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      error "Unsupported platform: $OS" ;;
esac

# ── Language detection ─────────────────────────────────────────────────────────
LANG_DETECTED="${LANG:-}${LANGUAGE:-}"
if [[ "$LANG_DETECTED" == *zh* ]] || [[ "${LC_ALL:-}" == *zh* ]]; then
  LANG_MODE="zh"
else
  LANG_MODE="en"
fi

# Allow explicit override: OPENCLAW_LANG=zh ./setup.sh  or  OPENCLAW_LANG=en ./setup.sh
[[ -n "${OPENCLAW_LANG:-}" ]] && LANG_MODE="$OPENCLAW_LANG"

# ── i18n strings ──────────────────────────────────────────────────────────────
if [[ "$LANG_MODE" == "zh" ]]; then
  T_CHECKING="检查前置条件"
  T_PROVIDER="模型服务商"
  T_PROVIDER_DESC="OpenClaw 需要一个 OpenAI 兼容的 API 端点（百炼、Moonshot 等）"
  T_PROVIDER_NAME="服务商名称  [bailian]: "
  T_PROVIDER_URL="Base URL   [https://dashscope.aliyuncs.com/compatible-mode/v1]: "
  T_API_KEY="API Key: "
  T_API_KEY_REQUIRED="API Key 不能为空"
  T_MODELS="Agent 模型分配"
  T_MODELS_DESC="每个 Agent 使用不同的模型，直接回车使用默认值。"
  T_MODEL_CMD="指挥官模型    [kimi-k2.5]:            "
  T_MODEL_SCOUT="斥候模型      [qwen3.5-plus]:         "
  T_MODEL_SCRIBE="笔帖式模型    [kimi-k2.5]:            "
  T_MODEL_ARTISAN="工匠模型      [qwen3-coder-plus]:     "
  T_MODEL_REVIEWER="审查官模型    [qwen3-max-2026-01-23]: "
  T_MODEL_BUILDER="建造者模型    [qwen3.5-plus]:         "
  T_GW_TOKEN="网关令牌"
  T_GW_TOKEN_DESC="令牌用于验证连接到网关的客户端。"
  T_GW_TOKEN_PROMPT="网关令牌  [自动生成: "
  T_SEARCH="网页搜索（可选）"
  T_SEARCH_DESC="Brave Search API 给 Agent 提供 web_search 工具。"
  T_SEARCH_KEY_URL="免费申请：https://api.search.brave.com/app/keys"
  T_SEARCH_PROMPT="Brave API Key  [跳过]: "
  T_SEARCH_ON="Brave Search 已启用"
  T_SEARCH_OFF="跳过 — Agent 将只使用 web_fetch"
  T_WORKSPACE="工作区目录"
  T_WORKSPACE_DESC="所有 Agent 共享的目录，用于任务、代码审查和文档。"
  T_WORKSPACE_PROMPT="工作区路径  [~/workspace]: "
  T_SUMMARY="安装摘要"
  T_CONFIRM="确认安装？[Y/n]: "
  T_ABORTED="已取消。"
  T_INSTALLING="安装中…"
  T_WORKSPACE_READY="工作区就绪"
  T_CONFIGURING="配置 openclaw..."
  T_AGENTS="安装 Agents..."
  T_GATEWAY="启动网关..."
  T_GATEWAY_READY="网关就绪"
  T_GATEWAY_WARN="网关可能仍在启动中，检查：openclaw gateway status"
  T_CRON="设置定时任务..."
  T_CRON_REVIEWER="定时任务：reviewer-scan（每 30 分钟）"
  T_CRON_REVIEWER_FAIL="reviewer-scan 添加失败 — 之后手动添加"
  T_CRON_HEARTBEAT="定时任务：commander-heartbeat（每 2 小时）"
  T_CRON_HEARTBEAT_FAIL="commander-heartbeat 添加失败 — 之后手动添加"
  T_DONE_TITLE="OpenClaw Squad 安装完成！"
  T_CONNECT="连接网关："
  T_BUILDER_WARN="Builder Agent 未启用。安装 claude CLI 后重新运行安装脚本可启用复杂编码任务："
  T_LAUNCHD_MANAGED="由 launchd 管理（登录后自动启动）"
  T_LAUNCHD_WARN="launchd 安装失败 — 网关重启后不会自动恢复，请手动运行 'openclaw gateway install'"
  T_SYSTEMD_MANAGED="由 systemd 管理（登录后自动启动）"
  T_SYSTEMD_WARN="systemd 安装失败 — 网关重启后不会自动恢复，请手动运行 'openclaw gateway install'"
  T_NOT_FOUND_OC="openclaw 未找到，请先安装：https://openclaw.ai/docs/install"
  T_NOT_FOUND_PY="python3 未找到"
  T_CLAUDE_FOUND="claude CLI 已找到，Builder Agent 将启用"
  T_CLAUDE_MISSING="未找到 claude CLI — Builder Agent（复杂编码）将被禁用"
else
  T_CHECKING="Checking Prerequisites"
  T_PROVIDER="Model Provider"
  T_PROVIDER_DESC="OpenClaw needs an OpenAI-compatible API endpoint (DashScope, Moonshot, etc.)"
  T_PROVIDER_NAME="Provider name  [bailian]: "
  T_PROVIDER_URL="Base URL       [https://dashscope.aliyuncs.com/compatible-mode/v1]: "
  T_API_KEY="API key: "
  T_API_KEY_REQUIRED="API key is required"
  T_MODELS="Agent Models"
  T_MODELS_DESC="Each agent uses a different model. Press Enter to accept defaults."
  T_MODEL_CMD="Commander model  [kimi-k2.5]:            "
  T_MODEL_SCOUT="Scout model      [qwen3.5-plus]:         "
  T_MODEL_SCRIBE="Scribe model     [kimi-k2.5]:            "
  T_MODEL_ARTISAN="Artisan model    [qwen3-coder-plus]:     "
  T_MODEL_REVIEWER="Reviewer model   [qwen3-max-2026-01-23]: "
  T_MODEL_BUILDER="Builder model    [qwen3.5-plus]:         "
  T_GW_TOKEN="Gateway Token"
  T_GW_TOKEN_DESC="Token authenticates clients connecting to the gateway."
  T_GW_TOKEN_PROMPT="Gateway token  [auto: "
  T_SEARCH="Web Search (optional)"
  T_SEARCH_DESC="Brave Search API gives agents a web_search tool."
  T_SEARCH_KEY_URL="Get a free key at: https://api.search.brave.com/app/keys"
  T_SEARCH_PROMPT="Brave API key  [skip]: "
  T_SEARCH_ON="Brave Search enabled"
  T_SEARCH_OFF="Skipping — agents will use web_fetch only"
  T_WORKSPACE="Workspace Directory"
  T_WORKSPACE_DESC="Shared directory used by all agents for tasks, code reviews, and docs."
  T_WORKSPACE_PROMPT="Workspace path  [~/workspace]: "
  T_SUMMARY="Install Summary"
  T_CONFIRM="Proceed with installation? [Y/n]: "
  T_ABORTED="Aborted."
  T_INSTALLING="Installing…"
  T_WORKSPACE_READY="Workspace ready"
  T_CONFIGURING="Configuring openclaw..."
  T_AGENTS="Installing agents..."
  T_GATEWAY="Starting openclaw gateway..."
  T_GATEWAY_READY="Gateway is ready"
  T_GATEWAY_WARN="Gateway may still be starting. Check: openclaw gateway status"
  T_CRON="Setting up cron jobs..."
  T_CRON_REVIEWER="Cron: reviewer-scan (every 30 min)"
  T_CRON_REVIEWER_FAIL="Failed to add reviewer-scan cron — add manually later"
  T_CRON_HEARTBEAT="Cron: commander-heartbeat (every 2h)"
  T_CRON_HEARTBEAT_FAIL="Failed to add commander-heartbeat cron — add manually later"
  T_DONE_TITLE="OpenClaw Squad installed successfully!"
  T_CONNECT="Connect to gateway:"
  T_BUILDER_WARN="Builder agent disabled. Install claude CLI and re-run setup to enable complex coding tasks:"
  T_LAUNCHD_MANAGED="Managed by launchd (auto-starts on login)"
  T_LAUNCHD_WARN="launchd install failed — gateway will not survive reboot. Run 'openclaw gateway install' manually."
  T_SYSTEMD_MANAGED="Managed by systemd (auto-starts on login)"
  T_SYSTEMD_WARN="systemd install failed — gateway will not survive reboot. Run 'openclaw gateway install' manually."
  T_NOT_FOUND_OC="openclaw not found. Install: https://openclaw.ai/docs/install"
  T_NOT_FOUND_PY="python3 not found"
  T_CLAUDE_FOUND="claude CLI found — Builder agent will be enabled"
  T_CLAUDE_MISSING="claude CLI not found — Builder agent (complex coding) will be disabled"
fi

# ── Header ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${BLUE}"
cat << 'BANNER'
  ___                  _____ _                 ____                     _
 / _ \ _ __   ___ _ _ / ____| | __ ___      __/ ___|  __ _ _   _  __ _| |
| | | | '_ \ / _ \ '_ \ |    | |/ _` \ \ /\ / /\___ \ / _` | | | |/ _` | |
| |_| | |_) |  __/ | | | |___| | (_| |\ V  V /  ___) | (_| | |_| | (_| | |
 \___/| .__/ \___|_| |_|\____|_|\__,_| \_/\_/  |____/ \__, |\__,_|\__,_|_|
      |_|                                                 |_|
BANNER
echo -e "${NC}${DIM}  Multi-agent template installer · https://github.com/Peters-Pans/openclaw-squad${NC}"
echo

# ── Prerequisites ─────────────────────────────────────────────────────────────
section "$T_CHECKING"
command -v openclaw >/dev/null 2>&1 || error "$T_NOT_FOUND_OC"
command -v python3  >/dev/null 2>&1 || error "$T_NOT_FOUND_PY"
OC_VERSION=$(openclaw --version 2>/dev/null | head -1 || echo "unknown")
success "openclaw $OC_VERSION"
success "python3 $(python3 --version 2>&1 | awk '{print $2}')"
success "Platform: $PLATFORM"

# claude CLI is optional — Builder agent uses it for complex coding tasks
if command -v claude >/dev/null 2>&1; then
  CLAUDE_AVAILABLE=true
  success "$T_CLAUDE_FOUND"
else
  CLAUDE_AVAILABLE=false
  warn "$T_CLAUDE_MISSING"
fi

# ── Provider ──────────────────────────────────────────────────────────────────
section "$T_PROVIDER"
echo -e "${DIM}$T_PROVIDER_DESC${NC}"
echo
ask "$T_PROVIDER_NAME";  read -r PROVIDER_NAME;  PROVIDER_NAME="${PROVIDER_NAME:-bailian}"
ask "$T_PROVIDER_URL";   read -r PROVIDER_URL
PROVIDER_URL="${PROVIDER_URL:-https://dashscope.aliyuncs.com/compatible-mode/v1}"
ask "$T_API_KEY";  read -r -s API_KEY;  echo
[[ -z "$API_KEY" ]] && error "$T_API_KEY_REQUIRED"
success "Provider: $PROVIDER_NAME → $PROVIDER_URL"

# ── Models ────────────────────────────────────────────────────────────────────
section "$T_MODELS"
echo -e "${DIM}$T_MODELS_DESC${NC}"
echo
ask "$T_MODEL_CMD";      read -r CMD_MODEL;      CMD_MODEL="${CMD_MODEL:-kimi-k2.5}"
ask "$T_MODEL_SCOUT";    read -r SCOUT_MODEL;    SCOUT_MODEL="${SCOUT_MODEL:-qwen3.5-plus}"
ask "$T_MODEL_SCRIBE";   read -r SCRIBE_MODEL;   SCRIBE_MODEL="${SCRIBE_MODEL:-kimi-k2.5}"
ask "$T_MODEL_ARTISAN";  read -r ARTISAN_MODEL;  ARTISAN_MODEL="${ARTISAN_MODEL:-qwen3-coder-plus}"
ask "$T_MODEL_REVIEWER"; read -r REVIEWER_MODEL; REVIEWER_MODEL="${REVIEWER_MODEL:-qwen3-max-2026-01-23}"
if [[ "$CLAUDE_AVAILABLE" == true ]]; then
  ask "$T_MODEL_BUILDER";  read -r BUILDER_MODEL;  BUILDER_MODEL="${BUILDER_MODEL:-qwen3.5-plus}"
fi

# ── Gateway ───────────────────────────────────────────────────────────────────
section "$T_GW_TOKEN"
AUTO_TOKEN=$(LC_ALL=C tr -dc 'a-f0-9' </dev/urandom 2>/dev/null | head -c 32 || openssl rand -hex 16)
echo -e "${DIM}$T_GW_TOKEN_DESC${NC}"
echo
ask "${T_GW_TOKEN_PROMPT}${AUTO_TOKEN:0:8}…]: "; read -r GW_TOKEN; GW_TOKEN="${GW_TOKEN:-$AUTO_TOKEN}"
success "Token configured"

# ── Web Search ────────────────────────────────────────────────────────────────
section "$T_SEARCH"
echo -e "${DIM}$T_SEARCH_DESC${NC}"
echo -e "${DIM}$T_SEARCH_KEY_URL${NC}"
echo
ask "$T_SEARCH_PROMPT"; read -r -s BRAVE_KEY; echo
[[ -n "$BRAVE_KEY" ]] && success "$T_SEARCH_ON" || warn "$T_SEARCH_OFF"

# ── Workspace ─────────────────────────────────────────────────────────────────
section "$T_WORKSPACE"
echo -e "${DIM}$T_WORKSPACE_DESC${NC}"
echo
ask "$T_WORKSPACE_PROMPT"; read -r WORKSPACE_INPUT; WORKSPACE_INPUT="${WORKSPACE_INPUT:-~/workspace}"
WORKSPACE="${WORKSPACE_INPUT/#\~/$HOME}"
success "Workspace: $WORKSPACE"

# ── Confirm ───────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}┌─ $T_SUMMARY $(printf '%.0s─' {1..50} | head -c $((47 - ${#T_SUMMARY})))┐${NC}"
printf "│  %-18s %-40s│\n" "Platform"   "$PLATFORM"
printf "│  %-18s %-40s│\n" "Provider"   "$PROVIDER_NAME → $PROVIDER_URL"
printf "│  %-18s %-40s│\n" "Commander"  "$PROVIDER_NAME/$CMD_MODEL"
printf "│  %-18s %-40s│\n" "Scout"      "$PROVIDER_NAME/$SCOUT_MODEL"
printf "│  %-18s %-40s│\n" "Scribe"     "$PROVIDER_NAME/$SCRIBE_MODEL"
printf "│  %-18s %-40s│\n" "Artisan"    "$PROVIDER_NAME/$ARTISAN_MODEL"
printf "│  %-18s %-40s│\n" "Reviewer"   "$PROVIDER_NAME/$REVIEWER_MODEL"
if [[ "$CLAUDE_AVAILABLE" == true ]]; then
  printf "│  %-18s %-40s│\n" "Builder"  "$PROVIDER_NAME/$BUILDER_MODEL"
fi
printf "│  %-18s %-40s│\n" "Gateway"    "${GW_TOKEN:0:8}…"
printf "│  %-18s %-40s│\n" "Web search" "${BRAVE_KEY:+Brave API enabled}${BRAVE_KEY:-disabled}"
printf "│  %-18s %-40s│\n" "Workspace"  "$WORKSPACE"
echo -e "${BOLD}└────────────────────────────────────────────────────────────┘${NC}"
echo
ask "$T_CONFIRM"; read -r CONFIRM
[[ "$CONFIRM" =~ ^[Nn]$ ]] && { echo "$T_ABORTED"; exit 0; }

echo
echo -e "${BOLD}$T_INSTALLING${NC}"
echo

# ── Step 1: Workspace ─────────────────────────────────────────────────────────
info "Creating workspace directories..."
mkdir -p "$WORKSPACE"/{shared,reports,tasks/{specs,progress,completed},code-reviews/{pending,feedback,reviewed},docs}
success "$T_WORKSPACE_READY: $WORKSPACE"

# ── Step 2: openclaw.json ─────────────────────────────────────────────────────
info "$T_CONFIGURING"
mkdir -p "$OPENCLAW_DIR"
CONFIG_FILE="$OPENCLAW_DIR/openclaw.json"

# Stop gateway if running
pkill -f "openclaw.*gateway" 2>/dev/null && { warn "Stopped existing gateway"; sleep 1; } || true

# JSON-escape helper
json_str() { python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$1"; }

API_KEY_J=$(json_str "$API_KEY")
GW_TOKEN_J=$(json_str "$GW_TOKEN")
BRAVE_KEY_J=$(json_str "${BRAVE_KEY:-}")
PROVIDER_URL_J=$(json_str "$PROVIDER_URL")
BRAVE_ENABLED=$([ -n "$BRAVE_KEY" ] && echo "true" || echo "false")

# Build unique model list
declare -A _SEEN_MODELS
_MODELS_JSON=""
_add_model() {
  local id="$1" input="$2" ctx="$3" maxTok="$4" compat="$5"
  [[ -n "${_SEEN_MODELS[$id]+x}" ]] && return
  _SEEN_MODELS["$id"]=1
  local entry
  if [[ -n "$compat" ]]; then
    entry="{ \"id\": \"$id\", \"name\": \"$id\", \"input\": $input, \"reasoning\": false, \"cost\": {\"input\":0,\"output\":0,\"cacheRead\":0,\"cacheWrite\":0}, \"contextWindow\": $ctx, \"maxTokens\": $maxTok, \"compat\": {\"thinkingFormat\": \"$compat\"} }"
  else
    entry="{ \"id\": \"$id\", \"name\": \"$id\", \"input\": $input, \"reasoning\": false, \"cost\": {\"input\":0,\"output\":0,\"cacheRead\":0,\"cacheWrite\":0}, \"contextWindow\": $ctx, \"maxTokens\": $maxTok }"
  fi
  [[ -n "$_MODELS_JSON" ]] && _MODELS_JSON+=$',\n          '
  _MODELS_JSON+="$entry"
}
_add_model "$CMD_MODEL"      '["text","image"]' 262144  32768 "qwen"
_add_model "$SCOUT_MODEL"    '["text","image"]' 1000000 65536 "qwen"
_add_model "$SCRIBE_MODEL"   '["text","image"]' 262144  32768 "qwen"
_add_model "$ARTISAN_MODEL"  '["text"]'         1000000 65536 ""
_add_model "$REVIEWER_MODEL" '["text"]'         262144  65536 "qwen"
if [[ "$CLAUDE_AVAILABLE" == true ]]; then
  _add_model "${BUILDER_MODEL:-qwen3.5-plus}" '["text","image"]' 1000000 65536 "qwen"
fi

# Build builder agent entry (conditional)
BUILDER_ENTRY=""
BUILDER_IN_SUBAGENTS=""
if [[ "$CLAUDE_AVAILABLE" == true ]]; then
  BUILDER_ENTRY=",
      {
        \"id\": \"builder\", \"name\": \"builder\",
        \"workspace\": \".agents/builder\",
        \"model\": \"$PROVIDER_NAME/${BUILDER_MODEL:-qwen3.5-plus}\",
        \"identity\": { \"name\": \"🏗️ 建造者\" },
        \"tools\": { \"deny\": [\"browser\"] }
      }"
  BUILDER_IN_SUBAGENTS=", \"builder\""
fi

cat > "$CONFIG_FILE" << JSONEOF
{
  "meta": { "lastTouchedVersion": "2026.3.24" },
  "models": {
    "mode": "merge",
    "providers": {
      "$PROVIDER_NAME": {
        "baseUrl": $PROVIDER_URL_J,
        "apiKey": $API_KEY_J,
        "api": "openai-completions",
        "models": [
          $_MODELS_JSON
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": { "primary": "$PROVIDER_NAME/$CMD_MODEL" },
      "compaction": { "mode": "safeguard" }
    },
    "list": [
      { "id": "main" },
      {
        "id": "commander", "default": true, "name": "commander",
        "workspace": ".agents/commander",
        "model": "$PROVIDER_NAME/$CMD_MODEL",
        "identity": { "name": "🧠 指挥官" },
        "tools": { "deny": ["browser", "exec", "web_search", "web_fetch"] },
        "subagents": { "allowAgents": ["scout", "scribe", "artisan", "reviewer"$BUILDER_IN_SUBAGENTS] }
      },
      {
        "id": "artisan", "name": "artisan",
        "workspace": ".agents/artisan",
        "model": "$PROVIDER_NAME/$ARTISAN_MODEL",
        "identity": { "name": "🛠️ 工匠" },
        "tools": { "deny": ["browser"] }
      },
      {
        "id": "scout", "name": "scout",
        "workspace": ".agents/scout",
        "model": "$PROVIDER_NAME/$SCOUT_MODEL",
        "identity": { "name": "📰 斥候" },
        "tools": { "deny": ["exec","browser"] }
      },
      {
        "id": "scribe", "name": "scribe",
        "workspace": ".agents/scribe",
        "model": "$PROVIDER_NAME/$SCRIBE_MODEL",
        "identity": { "name": "✍️ 笔帖式" },
        "tools": { "deny": ["exec","browser"] }
      },
      {
        "id": "reviewer", "name": "reviewer",
        "workspace": ".agents/reviewer",
        "model": "$PROVIDER_NAME/$REVIEWER_MODEL",
        "identity": { "name": "🔍 审查官" },
        "tools": { "deny": ["browser"] }
      }$BUILDER_ENTRY
    ]
  },
  "tools": {
    "web": { "search": { "enabled": $BRAVE_ENABLED, "provider": "brave", "maxResults": 5 } },
    "sessions": { "visibility": "all" }
  },
  "commands": { "native": "auto", "nativeSkills": "auto", "restart": true, "ownerDisplay": "raw" },
  "gateway": {
    "mode": "local",
    "auth": { "mode": "token", "token": $GW_TOKEN_J }
  },
  "plugins": {
    "entries": {
      "brave": {
        "enabled": $BRAVE_ENABLED,
        "config": { "webSearch": { "apiKey": $BRAVE_KEY_J } }
      }
    },
    "allow": ["brave"]
  },
  "bindings": []
}
JSONEOF

success "openclaw.json written"

# ── Step 3: Agents ────────────────────────────────────────────────────────────
info "$T_AGENTS"
mkdir -p "$AGENTS_DIR"

install_agent() {
  local ID="$1"
  local DEST="$AGENTS_DIR/$ID"
  mkdir -p "$DEST"
  [[ -f "$SCRIPT_DIR/agents/$ID/SOUL.md"      ]] && cp "$SCRIPT_DIR/agents/$ID/SOUL.md"      "$DEST/SOUL.md"
  [[ -f "$SCRIPT_DIR/agents/$ID/HEARTBEAT.md" ]] && cp "$SCRIPT_DIR/agents/$ID/HEARTBEAT.md" "$DEST/HEARTBEAT.md"
  info "  $ID → $DEST"
}

for AGENT_ID in commander artisan scout scribe reviewer; do
  install_agent "$AGENT_ID"
done

if [[ "$CLAUDE_AVAILABLE" == true ]]; then
  install_agent "builder"
fi

success "All agents installed"

# ── Step 4: Start Gateway ─────────────────────────────────────────────────────
info "$T_GATEWAY"

start_gateway_macos() {
  if openclaw gateway install 2>/dev/null; then
    launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway" 2>/dev/null || \
    launchctl start ai.openclaw.gateway 2>/dev/null || true
    echo -e "  ${DIM}$T_LAUNCHD_MANAGED${NC}"
  else
    nohup openclaw gateway > "$OPENCLAW_DIR/gateway.log" 2>&1 &
    echo -e "  ${DIM}PID $! · log: $OPENCLAW_DIR/gateway.log${NC}"
    warn "$T_LAUNCHD_WARN"
  fi
}

start_gateway_linux() {
  if openclaw gateway install 2>/dev/null; then
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable openclaw-gateway.service 2>/dev/null || true
    systemctl --user restart openclaw-gateway.service
    echo -e "  ${DIM}$T_SYSTEMD_MANAGED${NC}"
  else
    nohup openclaw gateway > "$OPENCLAW_DIR/gateway.log" 2>&1 &
    echo -e "  ${DIM}PID $! · log: $OPENCLAW_DIR/gateway.log${NC}"
    warn "$T_SYSTEMD_WARN"
  fi
}

if [[ "$PLATFORM" == "macos" ]]; then
  start_gateway_macos
else
  start_gateway_linux
fi

# Wait for gateway
for i in $(seq 1 15); do
  sleep 1
  if openclaw agents list >/dev/null 2>&1; then
    success "$T_GATEWAY_READY"
    break
  fi
  [[ $i -eq 15 ]] && warn "$T_GATEWAY_WARN"
done

# ── Step 5: Cron Jobs ─────────────────────────────────────────────────────────
info "$T_CRON"

openclaw cron add \
  --name "reviewer-scan" \
  --agent reviewer \
  --cron "*/30 * * * *" \
  --session isolated \
  --best-effort-deliver \
  --message "Check $WORKSPACE/code-reviews/pending/ for new files. For each: review it, write findings to $WORKSPACE/code-reviews/feedback/REVIEW-{filename}.md, move to $WORKSPACE/code-reviews/reviewed/. Notify commander via sessions_send." \
  2>/dev/null && success "$T_CRON_REVIEWER" \
             || warn "$T_CRON_REVIEWER_FAIL"

openclaw cron add \
  --name "commander-heartbeat" \
  --agent commander \
  --cron "0 */2 * * *" \
  --session isolated \
  --best-effort-deliver \
  --message "Read HEARTBEAT.md and follow all instructions." \
  2>/dev/null && success "$T_CRON_HEARTBEAT" \
             || warn "$T_CRON_HEARTBEAT_FAIL"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║   ✓  $T_DONE_TITLE   ║${NC}"
echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo
echo -e "  ${BOLD}$T_CONNECT${NC}"
echo -e "    URL:   ${CYAN}ws://localhost:18789${NC}"
echo -e "    Token: ${CYAN}${GW_TOKEN:0:8}…${NC}"
echo
echo -e "  ${BOLD}Workspace:${NC} $WORKSPACE"
echo -e "  ${BOLD}Config:${NC}    $CONFIG_FILE"
if [[ "$CLAUDE_AVAILABLE" == false ]]; then
  echo
  echo -e "  ${YELLOW}$T_BUILDER_WARN${NC} ${CYAN}https://claude.ai/download${NC}"
fi
echo
