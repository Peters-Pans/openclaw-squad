# OpenClaw Squad — 多 Agent 协作方案说明

## 一、项目背景

OpenClaw Squad 是基于 OpenClaw 平台构建的个人专属 AI 团队。目标是通过多个专职 Agent 协作，让用户只需和一个"总接口"对话，背后自动调度最合适的 Agent 完成任务，并内置质量审查流水线。

---

## 二、整体架构

```
用户
 │
 ▼
Commander（唯一对外接口）
 ├─→ Scout         联网搜索、技术调研
 ├─→ Scribe        文案、文档、邮件
 ├─→ Artisan       脚本、配置、轻量代码（<100行）
 ├─→ Reviewer      代码审查（cron + 主动召唤）
 └─→ Claude Code   复杂编码任务（>100行、多文件、架构级）
                   ↑ 通过生成 TASK 文件 + 通知用户切终端触发
```

**核心原则**：
- 用户只和 Commander 对话，不感知内部团队存在
- Commander 不亲自完成任务，只做调度和汇总
- 所有子 Agent 结果统一由 Commander 以自己的口吻呈现给用户
- Claude Code 是唯一"离线"协作者——Commander 无法直接调用它，只能生成任务文件后告知用户手动切终端处理

---

## 三、Agent 职责详述

### 🧠 Commander（指挥官）
- **身份**：用户的唯一对话入口
- **能力**：理解自然语言需求（文字/图片/截图/文件），判断任务类型，调度合适的子 Agent
- **限制**：不能自己做搜索（web_search / web_fetch 被禁），不能执行代码，强制走子 Agent
- **调度工具**：`sessions_spawn(agentId=..., task=..., mode="run")`（同步等待结果）
- **UX 规则**：调度前必须先发一句极短确认（首字优先），避免用户等待无反馈

**调度决策树**：
| 请求类型 | 调度目标 |
|---------|---------|
| 搜索/调研/最新信息 | Scout（强制，即使 Commander 知道答案） |
| 文档/文案/邮件/README | Scribe |
| 脚本/配置/代码（<100行） | Artisan |
| 多文件/架构级/新功能（>100行） | 生成 TASK 文件，让用户切到 Claude Code |
| 组合任务 | 串联调度（如：先 Scout 调研，结果传给 Scribe 写文档） |

---

### 📰 Scout（斥候）
- **身份**：信息情报官
- **能力**：web_search（Brave）、web_fetch、整理调研报告
- **限制**：不能执行代码（exec 被禁）
- **降级策略**：Brave 429 时自动改用 web_fetch；最多重试 2 次，宁可返回部分信息也要及时结束
- **输出**：结构化调研报告，保存到 `~/.openclaw/agents/scout/workspace/reports/`

---

### ✍️ Scribe（笔帖式）
- **身份**：文字专家
- **能力**：撰写文档、README、邮件、博客、技术文章
- **限制**：不能执行代码（exec 被禁）
- **输出原则**：中文为主，简洁直接，不用 AI 套话句式
- **产出**：写入 `~/workspace/docs/DOC-{YYYYMMDD}-{标题}.md`

---

### 🛠️ Artisan（工匠）
- **身份**：快手工程师
- **能力**：单文件脚本（Shell/Python/JS/Go）、配置文件、简单 bug 修复、正则/SQL、CI/CD
- **限制**：不接多文件架构改动、不接需要完整代码库上下文的任务
- **依赖管理**：需要第三方库时先 `exec` 检查，未安装直接 `pip install` / `sudo apt install`，无需询问用户
- **工作流程**（严格顺序）：
  1. 判断是否在接单范围
  2. 检查并安装依赖
  3. 写代码
  4. 调用 `write` 工具，写变更摘要到 `pending/`（含完整代码，**必须是实际 tool call**）
  5. 将代码返回给 Commander
- **文件命名**：新任务用 `CHANGE-{YYYYMMDD}-{序号}-{简述}.md`，修复用 `-fix1` / `-fix2` 后缀

---

### 🔍 Reviewer（审查官）
- **身份**：代码质量把关人
- **触发方式**：cron 每 30 分钟自动扫描 + Commander 主动召唤
- **工作流程**：
  1. 扫描 `~/workspace/code-reviews/pending/`
  2. 逐一审查新文件（正确性、安全性、性能、可维护性）
  3. 意见写入 `~/workspace/code-reviews/feedback/REVIEW-{文件名}.md`
  4. 原文件移到 `~/workspace/code-reviews/reviewed/`
  5. 通过 `sessions_send` 通知 Commander：文件名 + 结论 + 主要问题摘要

---

### 💻 Claude Code（外部协作，异步）
- **身份**：重型编码执行者，在用户本地终端运行，不在 gateway 内
- **触发方式**：Commander 无法直接调用，只能写 TASK 文件 + 告知用户
- **适用场景**：多文件架构改动、需要完整代码库上下文、新功能开发（>100行）、数据库 migration
- **与 Artisan 的分界线**：单文件/独立脚本 → Artisan；需要理解整个仓库 → Claude Code
- **任务已由 Builder 全自动处理**：Commander 通过两阶段协议（[SPEC] 确认 → [EXECUTE] 执行）调度 Builder，无需用户手动切终端

---

## 四、代码质量流水线

```
Artisan 写代码
     │
     ▼
写入 pending/CHANGE-xxx.md（含完整代码）
     │
     ▼ （cron 每 30 分钟 / 主动触发）
Reviewer 审查
     │
     ├─ APPROVED ──────────────────→ Commander 告知用户 ✅
     │
     └─ CHANGES_REQUESTED
              │
              ▼
         Commander 读取 feedback 文件
              │
              ▼
         调度 Artisan 修复（附 feedback + 原始代码路径）
              │
              ▼
         Artisan 写 pending/CHANGE-xxx-fix1.md
              │
              ▼
         Reviewer 再次审查
              │
              ├─ APPROVED ──────────→ Commander 告知用户 ✅
              │
              └─ CHANGES_REQUESTED（第 2 次）
                       │
                       ▼
                  Commander 告知用户"需要人工处理" ⚠️
```

**最多 2 轮修复**，防止无限循环。

---

## 五、Cron 任务

| 任务 | Agent | 频率 | 会话类型 |
|------|-------|------|---------|
| reviewer-scan | Reviewer | 每 30 分钟 | isolated |
| commander-heartbeat | Commander | 每 2 小时 | isolated |

Commander 心跳检查内容：
- Cron 健康状态（agentId 是否设置、session 是否 isolated）
- 接收并转述 Reviewer 的推送通知

---

## 六、跨 Agent 通信机制

| 场景 | 工具 | 说明 |
|------|------|------|
| Commander → 子 Agent | `sessions_spawn(mode="run")` | 同步，等待结果返回 |
| Reviewer → Commander | `sessions_send(sessionKey="agent:commander:main")` | 异步推送通知 |

**关键配置**：`tools.sessions.visibility = "all"`，否则 sessions_send 跨 Agent 推送会被拦截。

---

## 七、配置要点

**Commander deny list**：`["browser", "exec", "web_search", "web_fetch"]`
- 强制 Commander 不能自己搜索，必须走 Scout

**Agent 模型分配**：
- Commander：kimi-k2.5（长上下文，适合调度决策）
- Scout：qwen3.5-plus（快，搜索任务不需要最强模型）
- Scribe：kimi-k2.5（写作质量）
- Artisan：qwen3-coder-plus（代码专项）
- Reviewer：qwen3-max（审查需要最严格的判断力）

---

## 八、已知局限

1. **Brave Search 免费限速**：1 req/s，Scout 在高频搜索时会触发 429，自动降级 web_fetch
2. **Commander 单 session 瓶颈**：并发请求排队，单用户场景无影响，多用户场景需要 per-user session 路由
3. **sessions_spawn 异步丢失**：CLI 测试时 Commander 发出 ack 后连接关闭，sessions_spawn 结果无法回传；真实 WebChat 会话不受影响

---

## 九、目录结构

```
~/workspace/
├── shared/           # 跨 Agent 共享上下文（Scout 报告直传 Scribe，无需 Commander 中转）
├── reports/          # Scout 私有存档
├── code-reviews/
│   ├── pending/      # Artisan 待审代码（Reviewer 原子性 mv 后才读，防并发竞态）
│   ├── processing/   # Reviewer 正在审查中（mv 进来即锁定，异常退出后可续处理）
│   ├── feedback/     # Reviewer 审查意见
│   └── reviewed/     # 已处理文件归档
├── docs/             # Scribe 输出文档
└── tasks/
    ├── specs/        # Builder 生成的任务规格，等待 Commander 确认
    ├── progress/     # Builder 执行中断时的进度快照（断点续跑）
    └── completed/    # Builder 完成的任务摘要
```
