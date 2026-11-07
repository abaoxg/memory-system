# 压缩与晋升

目的：让核心记忆长期停在预算内，同时不丢关键信息。

## 触发条件

满足任一即压缩：

- `MEMORY.md` > 8000 字符
- 单主题 notes 文件 > 6000 字符
- 距上次压缩 > 30 天且条目有增长
- 用户说「整理记忆」

## 四个动作

### 1. 晋升 (promote)

低层 → 高层，反复用到的才升。

```text
facts/ 里同一 tag 出现 >= 3 次   → 合并成 MEMORY.md 一行
notes/errors.md 同一根因 >= 2 次 → 晋升为 MEMORY.md「规则」一行
notes/<topic>.md 的「关键结论」  → 摘要进 MEMORY.md「项目」表一行
```

### 2. 合并 (merge)

同义条目合成一条：

```text
- 用户喜欢直接回答
- 用户要求不要免责声明
- 用户不要替代方案
→ 风格：直接、无免责声明、无替代方案。
```

### 3. 降级 (demote)

核心记忆里不常用但有价值的内容，移入 `notes/`，`MEMORY.md` 只留指针。
判定：90 天内未被检索命中。

### 4. 归档 (archive)

低价值或过期内容移入 `archive/YYYY-MM.md`，原处删除。

判定：`status: stale` 且 7 天未确认 / 项目 `done` 且 90 天无变更 / 明确过期的路径与版本号。

## 执行

```bash
sh scripts/mem-compact.sh --dry-run    # 先看方案
sh scripts/mem-compact.sh --apply      # 执行机械部分
sh scripts/mem-stat.sh                 # 验证结果
```

`--apply` 会：

1. 备份到 `archive/<YYYY-MM-DD>-backup/`
2. 归档 stale 笔记并清理 INDEX 死链
3. 重写 `MEMORY.md` 的 `revision` 与 `updated`

**它不会做语义合并。** 合并、提炼、降级需要模型判断。

## 压缩原则

- **宁删勿糊** — 写不清楚的条目直接删，不留模糊占位。
- **保留可执行信息** — 命令、路径、端口、版本号一字不改。
- **保留因果** — 结论可压缩，根因不能删。
- **不合并不同项目** — 跨项目合并会串味。
- **不归档未完成项目** — 只压缩表述，不搬文件。

## 压缩后自检

1. `MEMORY.md` ≤ 8000 字符？
2. 每个 notes 文件在 `INDEX.md` 有条目？
3. 被删内容在 `archive/` 可追溯？
4. 关键路径/端口/版本号仍在？
5. 规则条目每条一行、可直接执行？
