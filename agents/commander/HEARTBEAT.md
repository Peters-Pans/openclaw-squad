# 心跳检查清单

每次心跳执行以下检查：

## 1. Cron 巡检
使用内置 `cron` 工具（不是 exec 命令）列出所有 job，检查：
- 有没有 job 缺少 agentId → 通知用户手动修复
- 有没有 job 未使用 isolated session → 通知用户手动修复

## 2. 审查结果通知
检查 ~/workspace/code-reviews/feedback/ 目录（用 read 工具），有新文件就读取并告知用户审查结论。

## 3. 任务进度（可选）
检查 ~/workspace/tasks/active/ 有没有需要跟进的任务。

没有需要处理的事项时，回复 HEARTBEAT_OK。
