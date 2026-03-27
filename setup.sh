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
section "Checking Prerequisites"
command -v openclaw >/dev/null 2>&1 || error "openclaw not found. Install: https://openclaw.ai/docs/install"
command -v python3  >/dev/null 2>&1 || error "python3 not found"
OC_VERSION=$(openclaw --version 2>/dev/null | head -1 || echo "unknown")
success "openclaw $OC_VERSION"
success "python3 $(python3 --version 2>&1 | awk '{print $2}')"
success "Platform: $PLATFORM"

# claude CLI is optional — Builder agent uses it for complex coding tasks
if command -v claude >/dev/null 2>&1; then
  CLAUDE_AVAILABLE=true
  success "claude $(claude --version 2>/dev/null | head -1 || echo 'found')"
else
  CLAUDE_AVAILABLE=false
  warn "claude CLI not found — Builder agent (complex coding) will be disabled"
fi

# ── Provider ──────────────────────────────────────────────────────────────────
section "Model Provider"
echo -e "${DIM}OpenClaw needs an OpenAI-compatible API endpoint (DashScope, Moonshot, etc.)${NC}"
echo
ask "Provider name  [bailian]: ";  read -r PROVIDER_NAME;  PROVIDER_NAME="${PROVIDER_NAME:-bailian}"
ask "Base URL       [https://dashscope.aliyuncs.com/compatible-mode/v1]: "
read -r PROVIDER_URL
PROVIDER_URL="${PROVIDER_URL:-https://dashscope.aliyuncs.com/compatible-mode/v1}"
ask "API key: ";  read -r -s API_KEY;  echo
[[ -z "$API_KEY" ]] && error "API key is required"
success "Provider: $PROVIDER_NAME → $PROVIDER_URL"

# ── Models ────────────────────────────────────────────────────────────────────
section "Agent Models"
echo -e "${DIM}Each agent uses a different model. Press Enter to accept defaults.${NC}"
echo
ask "Commander model  [kimi-k2.5]:            "; read -r CMD_MODEL;      CMD_MODEL="${CMD_MODEL:-kimi-k2.5}"
ask "Scout model      [qwen3.5-plus]:         "; read -r SCOUT_MODEL;    SCOUT_MODEL="${SCOUT_MODEL:-qwen3.5-plus}"
ask "Scribe model     [kimi-k2.5]:            "; read -r SCRIBE_MODEL;   SCRIBE_MODEL="${SCRIBE_MODEL:-kimi-k2.5}"
ask "Artisan model    [qwen3-coder-plus]:     "; read -r ARTISAN_MODEL;  ARTISAN_MODEL="${ARTISAN_MODEL:-qwen3-coder-plus}"
ask "Reviewer model   [qwen3-max-2026-01-23]: "; read -r REVIEWER_MODEL; REVIEWER_MODEL="${REVIEWER_MODEL:-qwen3-max-2026-01-23}"
if [[ "$CLAUDE_AVAILABLE" == true ]]; then
  ask "Builder model    [qwen3.5-plus]:         "; read -r BUILDER_MODEL;  BUILDER_MODEL="${BUILDER_MODEL:-qwen3.5-plus}"
fi

# ── Gateway ───────────────────────────────────────────────────────────────────
section "Gateway Token"
AUTO_TOKEN=$(LC_ALL=C tr -dc 'a-f0-9' </dev/urandom 2>/dev/null | head -c 32 || openssl rand -hex 16)
echo -e "${DIM}Token authenticates clients connecting to the gateway.${NC}"
echo
ask "Gateway token  [auto: ${AUTO_TOKEN:0:8}…]: "; read -r GW_TOKEN; GW_TOKEN="${GW_TOKEN:-$AUTO_TOKEN}"
success "Token configured"

# ── Web Search ────────────────────────────────────────────────────────────────
section "Web Search (optional)"
echo -e "${DIM}Brave Search API gives agents a web_search tool.${NC}"
echo -e "${DIM}Get a free key at: https://api.search.brave.com/app/keys${NC}"
echo
ask "Brave API key  [skip]: "; read -r -s BRAVE_KEY; echo
[[ -n "$BRAVE_KEY" ]] && success "Brave Search enabled" || warn "Skipping — agents will use web_fetch only"

# ── Workspace ─────────────────────────────────────────────────────────────────
section "Workspace Directory"
echo -e "${DIM}Shared directory used by all agents for tasks, code reviews, and docs.${NC}"
echo
ask "Workspace path  [~/workspace]: "; read -r WORKSPACE_INPUT; WORKSPACE_INPUT="${WORKSPACE_INPUT:-~/workspace}"
WORKSPACE="${WORKSPACE_INPUT/#\~/$HOME}"
success "Workspace: $WORKSPACE"

# ── Confirm ───────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}┌─ Install Summary ──────────────────────────────────────────┐${NC}"
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
ask "Proceed with installation? [Y/n]: "; read -r CONFIRM
[[ "$CONFIRM" =~ ^[Nn]$ ]] && { echo "Aborted."; exit 0; }

echo
echo -e "${BOLD}Installing…${NC}"
echo

# ── Step 1: Workspace ─────────────────────────────────────────────────────────
info "Creating workspace directories..."
mkdir -p "$WORKSPACE"/{tasks/{active,done,templates},code-reviews/{pending,feedback,reviewed},reports,docs,signals}
success "Workspace ready: $WORKSPACE"

# ── Step 2: openclaw.json ─────────────────────────────────────────────────────
info "Configuring openclaw..."
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
info "Installing agents..."
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
info "Starting openclaw gateway..."

start_gateway_macos() {
  # Try openclaw's own install (handles launchd automatically)
  if openclaw gateway install 2>/dev/null; then
    launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway" 2>/dev/null || \
    launchctl start ai.openclaw.gateway 2>/dev/null || true
    echo -e "  ${DIM}Managed by launchd (auto-starts on login)${NC}"
  else
    nohup openclaw gateway > "$OPENCLAW_DIR/gateway.log" 2>&1 &
    echo -e "  ${DIM}PID $! · log: $OPENCLAW_DIR/gateway.log${NC}"
    warn "launchd install failed — gateway will not survive reboot. Run 'openclaw gateway install' manually."
  fi
}

start_gateway_linux() {
  if openclaw gateway install 2>/dev/null; then
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable openclaw-gateway.service 2>/dev/null || true
    systemctl --user restart openclaw-gateway.service
    echo -e "  ${DIM}Managed by systemd (auto-starts on login)${NC}"
  else
    nohup openclaw gateway > "$OPENCLAW_DIR/gateway.log" 2>&1 &
    echo -e "  ${DIM}PID $! · log: $OPENCLAW_DIR/gateway.log${NC}"
    warn "systemd install failed — gateway will not survive reboot. Run 'openclaw gateway install' manually."
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
    success "Gateway is ready"
    break
  fi
  [[ $i -eq 15 ]] && warn "Gateway may still be starting. Check: openclaw gateway status"
done

# ── Step 5: Cron Jobs ─────────────────────────────────────────────────────────
info "Setting up cron jobs..."

openclaw cron add \
  --name "reviewer-scan" \
  --agent reviewer \
  --cron "*/30 * * * *" \
  --session isolated \
  --best-effort-deliver \
  --message "Check $WORKSPACE/code-reviews/pending/ for new files. For each: review it, write findings to $WORKSPACE/code-reviews/feedback/REVIEW-{filename}.md, move to $WORKSPACE/code-reviews/reviewed/. Notify commander via sessions_send." \
  2>/dev/null && success "Cron: reviewer-scan (every 30 min)" \
             || warn "Failed to add reviewer-scan cron — add manually later"

openclaw cron add \
  --name "commander-heartbeat" \
  --agent commander \
  --cron "0 */2 * * *" \
  --session isolated \
  --best-effort-deliver \
  --message "Read HEARTBEAT.md and follow all instructions." \
  2>/dev/null && success "Cron: commander-heartbeat (every 2h)" \
             || warn "Failed to add commander-heartbeat cron — add manually later"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║   ✓  OpenClaw Squad installed successfully!   ║${NC}"
echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo
echo -e "  ${BOLD}Connect to gateway:${NC}"
echo -e "    URL:   ${CYAN}ws://localhost:18789${NC}"
echo -e "    Token: ${CYAN}${GW_TOKEN:0:8}…${NC}"
echo
echo -e "  ${BOLD}Workspace:${NC} $WORKSPACE"
echo -e "  ${BOLD}Config:${NC}    $CONFIG_FILE"
if [[ "$CLAUDE_AVAILABLE" == false ]]; then
  echo
  echo -e "  ${YELLOW}Builder agent disabled.${NC} Install claude CLI and re-run setup"
  echo -e "  to enable complex coding tasks: ${CYAN}https://claude.ai/download${NC}"
fi
echo
