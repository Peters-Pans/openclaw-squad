检查 ~/workspace/code-reviews/pending/ 目录。
如果有新文件（不在 reviewed/ 里的），逐一审查。
审查意见写入 ~/workspace/code-reviews/feedback/REVIEW-{原文件名}.md。
审查完成后将原文件移到 ~/workspace/code-reviews/reviewed/。
用 sessions_send(sessionKey="agent:commander:main", message="代码审查完成：[文件名] → [结论]\n主要问题：[如有问题，列出 1-3 条关键问题；APPROVED 则写"无"]\n请按收到审查通知的处理流程操作。") 通知指挥官审查结果。
如果没有新文件，回复 HEARTBEAT_OK。
