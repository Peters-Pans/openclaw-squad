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
command -v openclaw >/dev/null 2>&1 || error "openclaw not found. Install: https://github.com/openclaw/openclaw"
command -v node     >/dev/null 2>&1 || error "node.js not found"
command -v npm      >/dev/null 2>&1 || error "npm not found"
OC_VERSION=$(openclaw --version 2>/dev/null | head -1 || echo "unknown")
success "openclaw $OC_VERSION"
success "node $(node --version)"

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

# ── Gateway ───────────────────────────────────────────────────────────────────
section "Gateway Token"
AUTO_TOKEN=$(LC_ALL=C tr -dc 'a-f0-9' </dev/urandom 2>/dev/null | head -c 32 || openssl rand -hex 16)
echo -e "${DIM}Token is used to authenticate clients connecting to the local gateway.${NC}"
echo
ask "Gateway token  [auto: ${AUTO_TOKEN:0:8}…]: "; read -r GW_TOKEN; GW_TOKEN="${GW_TOKEN:-$AUTO_TOKEN}"
success "Token configured"

# ── Web Search ────────────────────────────────────────────────────────────────
section "Web Search (optional)"
echo -e "${DIM}Brave Search API gives agents a web_search tool (no browser needed).${NC}"
echo -e "${DIM}Get a free key at: https://api.search.brave.com/app/keys${NC}"
echo
ask "Brave API key  [skip]: "; read -r -s BRAVE_KEY; echo
[[ -n "$BRAVE_KEY" ]] && success "Brave Search enabled" || warn "Skipping web search — agents won't be able to search the web"

# ── Workspace ─────────────────────────────────────────────────────────────────
section "Workspace Directory"
echo -e "${DIM}Shared directory used by all agents for tasks, code reviews, and signals.${NC}"
echo
ask "Workspace path  [~/workspace]: "; read -r WORKSPACE_INPUT; WORKSPACE_INPUT="${WORKSPACE_INPUT:-~/workspace}"
WORKSPACE="${WORKSPACE_INPUT/#\~/$HOME}"
success "Workspace: $WORKSPACE"

# ── Confirm ───────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}┌─ Install Summary ──────────────────────────────────────────┐${NC}"
printf "│  %-18s %-40s│\n" "Provider"  "$PROVIDER_NAME → $PROVIDER_URL"
printf "│  %-18s %-40s│\n" "Commander"  "$PROVIDER_NAME/$CMD_MODEL"
printf "│  %-18s %-40s│\n" "Scout"      "$PROVIDER_NAME/$SCOUT_MODEL"
printf "│  %-18s %-40s│\n" "Scribe"     "$PROVIDER_NAME/$SCRIBE_MODEL"
printf "│  %-18s %-40s│\n" "Artisan"    "$PROVIDER_NAME/$ARTISAN_MODEL"
printf "│  %-18s %-40s│\n" "Reviewer"   "$PROVIDER_NAME/$REVIEWER_MODEL"
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

# Stop gateway if running (avoid config conflict)
pkill -f "openclaw.*gateway" 2>/dev/null && { warn "Stopped existing gateway"; sleep 1; } || true

# Write full config from scratch (gateway is stopped)
cat > "$CONFIG_FILE" << JSONEOF
{
  "meta": { "lastTouchedVersion": "2026.3.24" },
  "models": {
    "mode": "merge",
    "providers": {
      "$PROVIDER_NAME": {
        "baseUrl": "$PROVIDER_URL",
        "apiKey": "$API_KEY",
        "api": "openai-completions",
        "models": [
          { "id": "$CMD_MODEL",      "name": "$CMD_MODEL",      "input": ["text","image"], "reasoning": false, "cost": {"input":0,"output":0,"cacheRead":0,"cacheWrite":0}, "contextWindow": 262144, "maxTokens": 32768, "compat": {"thinkingFormat":"qwen"} },
          { "id": "$SCOUT_MODEL",    "name": "$SCOUT_MODEL",    "input": ["text","image"], "reasoning": false, "cost": {"input":0,"output":0,"cacheRead":0,"cacheWrite":0}, "contextWindow": 1000000, "maxTokens": 65536, "compat": {"thinkingFormat":"qwen"} },
          { "id": "$ARTISAN_MODEL",  "name": "$ARTISAN_MODEL",  "input": ["text"],         "reasoning": false, "cost": {"input":0,"output":0,"cacheRead":0,"cacheWrite":0}, "contextWindow": 1000000, "maxTokens": 65536 },
          { "id": "$REVIEWER_MODEL", "name": "$REVIEWER_MODEL", "input": ["text"],         "reasoning": false, "cost": {"input":0,"output":0,"cacheRead":0,"cacheWrite":0}, "contextWindow": 262144, "maxTokens": 65536, "compat": {"thinkingFormat":"qwen"} }
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
        "tools": { "deny": ["browser", "exec"] },
        "subagents": { "allowAgents": ["scout", "scribe", "artisan", "reviewer"] }
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
      }
    ]
  },
  "tools": {
    "agentToAgent": { "enabled": true, "allow": ["*"] },
    "web": { "search": { "enabled": $([ -n "$BRAVE_KEY" ] && echo "true" || echo "false"), "provider": "brave", "maxResults": 5 } }
  },
  "commands": { "native": "auto", "nativeSkills": "auto", "restart": true },
  "gateway": {
    "mode": "local",
    "auth": { "mode": "token", "token": "$GW_TOKEN" }
  },
  "plugins": {
    "entries": {
      "brave": {
        "enabled": $([ -n "$BRAVE_KEY" ] && echo "true" || echo "false"),
        "config": { "webSearch": { "apiKey": "${BRAVE_KEY:-}" } }
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
  local SOUL_SRC="$SCRIPT_DIR/agents/$ID/SOUL.md"
  local BEAT_SRC="$SCRIPT_DIR/agents/$ID/HEARTBEAT.md"
  local DEST="$AGENTS_DIR/$ID"

  mkdir -p "$DEST"

  if [[ -f "$SOUL_SRC" ]]; then
    cp "$SOUL_SRC" "$DEST/SOUL.md"
  fi
  if [[ -f "$BEAT_SRC" ]]; then
    cp "$BEAT_SRC" "$DEST/HEARTBEAT.md"
  fi

  # Create TOOLS.md for commander with dispatch instructions
  if [[ "$ID" == "commander" ]]; then
    cat > "$DEST/TOOLS.md" << 'TOOLSEOF'
# TOOLS.md - 工具使用备忘

## ⚠️ 调度子 Agent（最重要）

调度内部团队成员用 sessions_spawn：

```
sessions_spawn(agentId="scout",   task="请调研...", mode="run")
sessions_spawn(agentId="scribe",  task="请写...",   mode="run")
sessions_spawn(agentId="artisan", task="请写脚本...", mode="run")
```

- mode 固定用 "run"
- 不要用 sessions_send(agentId=...) — agentId 在 sessions_send 中无效

## sessions_send 备用格式（直接寻址）

```
sessions_send(sessionKey="agent:scout:main",   message="...")
sessions_send(sessionKey="agent:scribe:main",  message="...")
sessions_send(sessionKey="agent:artisan:main", message="...")
```
TOOLSEOF
  fi

  info "  $ID → $DEST"
}

for AGENT_ID in commander artisan scout scribe reviewer; do
  install_agent "$AGENT_ID"
done
success "All agents installed"

# ── Step 4: Start Gateway ─────────────────────────────────────────────────────
info "Starting openclaw gateway..."
nohup openclaw gateway > "$OPENCLAW_DIR/gateway.log" 2>&1 &
GW_PID=$!
echo -e "  ${DIM}PID $GW_PID · log: $OPENCLAW_DIR/gateway.log${NC}"

# Wait for gateway to be ready
MAX_WAIT=15
for i in $(seq 1 $MAX_WAIT); do
  sleep 1
  if openclaw agents list >/dev/null 2>&1; then
    success "Gateway is ready"
    break
  fi
  if [[ $i -eq $MAX_WAIT ]]; then
    warn "Gateway may still be starting. Check: openclaw gateway status"
  fi
done

# ── Step 5: Cron Jobs ─────────────────────────────────────────────────────────
info "Setting up cron jobs..."

# Reviewer scan every 30 min
openclaw cron add \
  --name "reviewer-scan" \
  --agent reviewer \
  --cron "*/30 * * * *" \
  --session isolated \
  --message "Check ~/workspace/code-reviews/pending/ for files. For each file: review it, write findings to ~/workspace/code-reviews/feedback/<filename>-review.md, move reviewed file to ~/workspace/code-reviews/reviewed/." \
  2>/dev/null && success "Cron: reviewer-scan (every 30 min)" \
             || warn "Failed to add reviewer-scan cron — add manually later"

# Commander heartbeat every 2h
openclaw cron add \
  --name "commander-heartbeat" \
  --agent commander \
  --cron "0 */2 * * *" \
  --session isolated \
  --message "Read HEARTBEAT.md and follow all instructions." \
  2>/dev/null && success "Cron: commander-heartbeat (every 2h)" \
             || warn "Failed to add commander-heartbeat cron — add manually later"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║   ✓  OpenClaw Squad installed successfully!   ║${NC}"
echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "  1. Connect your client to: ${CYAN}ws://localhost:18789${NC}"
echo -e "     Token: ${CYAN}${GW_TOKEN:0:8}…${NC}"
echo -e "  2. Start chatting — messages go to Commander"
echo -e "  3. Drop code files in: ${CYAN}$WORKSPACE/code-reviews/pending/${NC}"
echo -e "     Reviewer will pick them up automatically every 30 min"
echo
echo -e "  ${DIM}Workspace: $WORKSPACE${NC}"
echo -e "  ${DIM}Config:    $CONFIG_FILE${NC}"
echo -e "  ${DIM}Log:       $OPENCLAW_DIR/gateway.log${NC}"
echo
