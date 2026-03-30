按以下顺序执行：

1. **超时恢复**（DB 驱动，原子操作）：
   exec: python3 ~/workspace/bin/db_timeout_recovery.py
   此命令自动找出 DB 中 status='processing' 且 reviewer_started_at 超过 2 小时的任务，
   将 DB 状态重置为 'pending'，并将对应文件从 processing/ 移回 pending/。
   输出恢复的文件列表。

   检查 processing/ 中**近期残留文件**（DB 状态仍为 processing，时间 <2 小时，上次实例异常退出）：
   如有 → 从审查步骤 3 继续处理（直接读取并审查，无需再执行 db_claim.py）。

2. 执行常规审查（与 SOUL.md 审查流程完全一致）：
   步骤 1：exec: python3 ~/workspace/bin/db_list_pending.py 5
   **单次最多处理 5 个文件**，超出部分留待下次 cron 处理。
   按 SOUL.md 步骤 2-6 处理每个文件（DB 抢占 → 审查 → DB 完成 → 归档 → 通知）。

3. 清理共享目录：
   a. 清理 7 天前的旧报告（只清理完整文件，不动临时文件）：
      exec: find ~/workspace/shared/ -name "REPORT-*.md" -mtime +7 -delete
   b. 清理超过 24 小时的残留临时文件（Scout 写到一半崩溃留下的，给大文件足够写入时间）：
      exec: find ~/workspace/shared/ -name ".tmp-REPORT-*.md" -mmin +1440 -delete
   （私有存档 ~/workspace/reports/ 不清理）

4. 如果 pending/ 和 processing/ 都没有文件，回复 HEARTBEAT_OK。
