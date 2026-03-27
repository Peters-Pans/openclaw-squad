# 心跳检查清单

每次心跳执行以下检查：

## 1. Cron 巡检
使用内置 `cron` 工具（不是 exec 命令）列出所有 job，检查：
- 有没有 job 缺少 agentId → 通知用户手动修复
- 有没有 job 未使用 isolated session → 通知用户手动修复

## 2. 审查结果通知
审查官（Reviewer）完成审查后会通过 sessions_send 直接推送通知给你，无需主动轮询目录。
如果你收到了 Reviewer 的审查通知消息，将结论转述给用户即可。
（不要用 read 工具读取 feedback/ 目录本身，会报 EISDIR 错误。如需读取具体报告文件，用完整文件路径。）

## 3. 任务进度（可选）
检查 ~/workspace/tasks/active/ 有没有需要跟进的任务。

没有需要处理的事项时，回复 HEARTBEAT_OK。
