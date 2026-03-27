# OpenClaw Squad — Multi-Agent Template

[English](#english) | [中文](#中文)

---

## English

A production-tested multi-agent configuration for [OpenClaw](https://github.com/openclaw/openclaw), built around a **Commander-centric dispatch pattern**. All user messages go to the Commander, who routes to specialized agents internally.

### Architecture

```
User
 └── 🧠 Commander (default agent, all-in-one interface)
       ├── 📰 Scout     — web research, competitive analysis
       ├── ✍️  Scribe    — writing, docs, emails
       ├── 🛠️  Artisan   — code < 100 lines, scripts, config
       └── 🔍 Reviewer  — code review (cron-triggered)

External:
 └── 💻 Claude Code — complex multi-file coding tasks (terminal)
```

### Key Design Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| Dispatch mechanism | `sessions_spawn(agentId=..., mode="run")` | `agentToAgent` is not a real tool; see Lessons Learned |
| Agent notification | File-based (`feedback/` → heartbeat) | More reliable than `sessions_send` in isolated sessions |
| Cron auto-fix | Detect + notify user | Agents can't run `openclaw cron edit` from heartbeat context |
| Per-agent tools | `deny` list only | `allow` whitelist blocks `sessions_*`, `web_search`, etc. |
| Shared workspace paths | `~/workspace/` | Device-portable; `exec` expands `~` correctly |

### Agents

| Agent | Model (recommended) | Role |
|-------|-------------------|------|
| Commander | `bailian/kimi-k2.5` or MiMo-V2-Omni | Dispatcher, user interface |
| Scout | `bailian/qwen3.5-plus` | Research, web search |
| Scribe | `bailian/kimi-k2.5` | Writing, documentation |
| Artisan | `bailian/qwen3-coder-plus` | Code, scripts |
| Reviewer | `bailian/qwen3-max-*` | Code review |

### Quick Start

```bash
git clone https://github.com/Peters-Pans/openclaw-squad
cd openclaw-squad
bash setup.sh
```

The installer will guide you through: provider config → model selection → gateway token → Brave search → workspace → done.

<details>
<summary>Manual setup (advanced)</summary>

1. **Clone and configure**
   ```bash
   git clone https://github.com/Peters-Pans/openclaw-squad
   cp openclaw.json.template ~/.openclaw/openclaw.json
   # Fill in your API keys
   ```

2. **Create workspace**
   ```bash
   mkdir -p ~/workspace/{tasks/{active,done,templates},code-reviews/{pending,feedback,reviewed},reports,docs,signals}
   ```

3. **Deploy agents** — copy each `agents/<name>/SOUL.md` to your openclaw agent workspace:
   ```bash
   # Example for commander
   openclaw agents add commander --model <your-model> --non-interactive
   cp agents/commander/SOUL.md ~/.openclaw/agents/commander/SOUL.md
   cp agents/commander/HEARTBEAT.md ~/.openclaw/agents/commander/HEARTBEAT.md
   ```

4. **Configure tools** (in `openclaw.json`):
   ```jsonc
   "tools": {
     "agentToAgent": { "enabled": true, "allow": ["*"] },
     "web": { "search": { "enabled": true, "provider": "brave" } }
   }
   ```

5. **Set up cron jobs**
   ```bash
   # Reviewer scan every 30 min
   openclaw cron add --name "reviewer-scan" --agent reviewer \
     --cron "*/30 * * * *" --session isolated --best-effort-deliver \
     --message "Check ~/workspace/code-reviews/pending/..."

   # Commander heartbeat every 2h
   openclaw cron add --name "commander-heartbeat" --agent commander \
     --cron "0 */2 * * *" --session isolated --best-effort-deliver \
     --message "Read HEARTBEAT.md and follow instructions."
   ```

</details>

### Lessons Learned (from real deployment)

- **`config.apply` will crash the gateway** — always use `openclaw config set` one field at a time
- **Skills path**: copy SKILL.md to `$(npm prefix)/lib/node_modules/openclaw/skills/<name>/`
- **`tools.allow` is a strict whitelist** — it blocks `sessions_*`, `web_search`, `subagents` etc. Use `deny` instead
- **Cron jobs need `--agent`** — bare jobs (no agentId) run as main session which pollutes context
- **Absolute paths in SOUL.md**: use `~/workspace/` not `/home/user/workspace/`
- **Dispatch tool is `sessions_spawn`** — `agentToAgent` is not a tool name; `sessions_send(agentId=...)` silently fails because `sessions.resolve` ignores the `agentId` param. Use `sessions_spawn(agentId="scout", task="...", mode="run")` instead; requires `subagents.allowAgents` in agent config
- **Commander must deny exec** — if exec is available, the LLM will use curl instead of dispatching to Scout, bypassing the multi-agent architecture entirely
- **Heartbeat should use built-in `cron` tool** — not `exec openclaw cron list`; exec in heartbeat context may fail

### Skills Included

| Skill | Purpose | Needs Internet |
|-------|---------|---------------|
| `conventional-commits` | Git commit message formatting | No |
| `git-essentials` | Git workflows | No |
| `security-scanner` | Vulnerability scanning | No |
| `task-status` | Long-task progress updates | No |
| `github` | GitHub CLI integration | Yes |
| `summarize` | URL/file summarization | Yes |

---

## 中文

基于 [OpenClaw](https://github.com/openclaw/openclaw) 的多 Agent 配置模板，经过真实部署测试。采用**指挥官中心化调度**模式——所有用户消息只发给指挥官，指挥官内部调度专业 Agent。

### 架构

```
用户
 └── 🧠 指挥官（默认 Agent，统一对外接口）
       ├── 📰 斥候    — 网络调研、情报收集
       ├── ✍️  笔帖式  — 文案写作、文档整理
       ├── 🛠️  工匠    — 轻量代码（<100行）、脚本、配置
       └── 🔍 审查官  — 代码审查（cron 定时触发）

外部协作：
 └── 💻 Claude Code — 复杂多文件编码任务（终端处理）
```

### 关键设计决策

| 决策 | 选择 | 原因 |
|------|------|------|
| 调度机制 | `sessions_spawn(agentId=..., mode="run")` | `agentToAgent` 不是工具名；`sessions_send(agentId=...)` 静默失败 |
| Agent 间通知 | 文件流（`feedback/` → heartbeat 读取） | isolated session 间 `sessions_send` 不可靠 |
| Cron 自动修复 | 检测 + 通知用户 | Agent 在 heartbeat 上下文中无法执行 `openclaw cron edit` |
| 每 Agent 工具 | 只用 `deny` 列表 | `allow` 白名单会屏蔽 `sessions_*`、`web_search` 等高级工具 |
| 共享工作区路径 | `~/workspace/` | 跨设备兼容；exec 工具会正确展开 `~` |

### 已知限制

1. **搜索需要出网**：`web_search`（Brave API）需要服务器能访问外网
2. **agentToAgent 在 isolated session 中不支持实时 push**：改用文件流通知
3. **cron edit 权限限制**：Agent 在 heartbeat 中无法修改 cron job，只能通知用户

### 快速开始

```bash
git clone https://github.com/Peters-Pans/openclaw-squad
cd openclaw-squad
bash setup.sh
```

安装脚本会引导你完成：provider 配置 → 模型选择 → gateway token → 网络搜索 → 工作区 → 完成。

### 文件结构

```
openclaw-squad/
├── agents/
│   ├── commander/
│   │   ├── SOUL.md         # 指挥官身份、调度规则
│   │   └── HEARTBEAT.md    # 心跳检查清单
│   ├── artisan/SOUL.md
│   ├── scout/SOUL.md
│   ├── scribe/SOUL.md
│   └── reviewer/
│       ├── SOUL.md
│       └── HEARTBEAT.md
├── workspace/              # 共享工作区目录结构（空占位）
│   ├── tasks/
│   ├── code-reviews/
│   ├── reports/
│   ├── docs/
│   └── signals/
├── openclaw.json.template  # 配置模板（已脱敏）
└── README.md
```

---

> Built with [OpenClaw](https://github.com/openclaw/openclaw) · Tested on OpenClaw v2026.3.24
