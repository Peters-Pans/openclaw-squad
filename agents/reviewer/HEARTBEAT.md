按以下顺序执行：

1. 检查 ~/workspace/code-reviews/processing/ 目录。
   如果有残留文件（上次实例异常退出），从审查步骤 3 继续处理（直接读取并审查，无需再 mv）。

2. 检查 ~/workspace/code-reviews/pending/ 目录。
   **单次最多处理 5 个文件**，超出部分留待下次 cron 处理。
   对每个文件，先执行 mv pending/{文件名} processing/{文件名}，移动成功后再审查；移动失败则跳过。
   审查意见写入 ~/workspace/code-reviews/feedback/REVIEW-{原文件名}.md。
   审查完成后将文件从 processing/ 移到 reviewed/。
   用 sessions_send(sessionKey="agent:commander:main", message="代码审查完成：[文件名] → [结论]\n主要问题：[如有问题，列出 1-3 条关键问题；APPROVED 则写"无"]\n请按收到审查通知的处理流程操作。") 通知指挥官。

3. 清理共享目录：
   a. 清理 7 天前的旧报告（只清理完整文件，不动临时文件）：
      exec: find ~/workspace/shared/ -name "REPORT-*.md" -mtime +7 -delete
   b. 清理超过 1 小时的残留临时文件（Scout 写到一半崩溃留下的）：
      exec: find ~/workspace/shared/ -name ".tmp-REPORT-*.md" -mmin +60 -delete
   （私有存档 ~/workspace/reports/ 不清理）

4. 如果 pending/ 和 processing/ 都没有文件，回复 HEARTBEAT_OK。
