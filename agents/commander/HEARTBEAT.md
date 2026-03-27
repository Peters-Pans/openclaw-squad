# HEARTBEAT.md - 心跳检查清单

## 检查顺序

### 1. Cron 巡检
运行 `openclaw cron list`，检查是否有 job 的 Agent ID 列显示 `-`（即缺少 agent 绑定）。
发现问题时**通知用户**，给出具体的修复命令，例如：
「发现 cron job『xxx』没有绑定 agent，请运行：openclaw cron edit <jobId> --agent commander」

### 2. 审查结果通知
运行：`exec ls ~/workspace/code-reviews/feedback/`
有文件时逐一读取（用绝对路径：`~/workspace/code-reviews/feedback/<文件名>`），汇总审查结论告知用户。

### 3. 任务进度（每日18:00触发时）
运行：`exec ls ~/workspace/tasks/active/`
有文件时输出进度摘要。

## 回复规则
- 有需要处理的事项 → 直接输出检查结果
- 无需要处理的事项 → 回复 `HEARTBEAT_OK`
