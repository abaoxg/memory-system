---
name: memory-system
description: Portable file-based long-term memory for any AI agent. Use when the user asks to remember preferences, project state, or run history across sessions; when starting a session that needs prior context; when the user says 记住、记忆、复习、上次说过、之前做到哪、继续上次、体检记忆; or when knowledge must survive context compaction and be portable between Claude Code, Cursor, Codex, ChatGPT, Ollama, local models, or any agent with file access.
---

# Memory System

> **开机自检**：本机已部署记忆库于 `/storage/emulated/0/ai-memory`。
> 会话第一轮先读该目录下 `INDEX.md` 与 `MEMORY.md`，按需加载 `notes/`。
> 若 `$MEMORY_ROOT` 未设置，先 `export MEMORY_ROOT=/storage/emulated/0/ai-memory`。
> 收尾时把新偏好/项目状态按本文「会话收尾流程」写回。

纯文件驱动的长期记忆。不依赖数据库、向量库、云 API 或特定平台。
任何能给 AI 读写文件的运行环境都能用同一套目录与脚本。

## 记忆库位置

**零硬编码。** 按优先级自动解析，第一个命中即用：

| 顺序 | 来源 | 说明 |
|---|---|---|
| 1 | `$MEMORY_ROOT` | 显式指定，最高优先 |
| 2 | 向上 6 层找 `memory/` 或 `.ai-memory/` | 需同时有 `MEMORY.md` 与 `INDEX.md` |
| 3 | `$HOME/.ai-memory` | 用户级默认 |
| 4 | `./memory` | 项目级兜底 |

**建议固定**，否则换目录就指向不同库：

```bash
export MEMORY_ROOT=/absolute/path/to/memory
```

目录结构：

```text
memory/
├── MEMORY.md          核心记忆，长驻上下文，预算 8000 字符
├── INDEX.md           目录索引，每轮必读，预算 2000 字符
├── notes/             主题笔记，一项目一文件
│   └── <slug>.md
├── facts/facts.md     原子事实，一行一条，可 grep
└── archive/           归档，默认不检索
    └── YYYY-MM.md
```

## 三个必守规则

1. **先读后写** — 任务开始先读 `INDEX.md`，命中主题再读对应 `notes/`。不要凭印象回答「我们之前…」。
2. **写要收敛** — 只写跨会话有复用价值的内容。一次性中间结果、大段日志、闲聊都不写。
3. **容量优先** — `MEMORY.md` 超 8000 字符必须压缩晋升，不要无限追加。

## 会话启动流程

1. 读 `INDEX.md`（≤2000 字符，全读）。
2. 读 `MEMORY.md`（≤8000 字符，超预算只读头部与命中章节）。
3. 按 `INDEX.md` 只加载与当前任务相关的 `notes/*.md`。
4. 一句话确认：「已恢复：<主题列表>」，然后直接干活，不复述内容。

## 会话收尾流程

触发：任务完成 / 用户说「记住」/ 会话将结束 / 发现稳定偏好。

1. 判断类型：`pref` / `env` / `proj` / `proc` / `err`。
2. 写入对应目标（见下表）。
3. 更新 `INDEX.md` 目录指针。
4. 一句话回报位置，不贴全文。

## 写入目标选择

| 内容 | 目标 | 命令 |
|---|---|---|
| 用户偏好、禁忌、称呼、风格 | `MEMORY.md` → `## 用户` | 手工编辑或 `-m` |
| 环境事实（路径、版本、端口） | `MEMORY.md` → `## 环境` | 手工编辑 |
| 项目状态、进度、卡点 | `notes/<slug>.md` | `-T "项目名"` |
| 可复用流程 / SOP | `notes/procedure-*.md` | `-T "流程名"` |
| 一次性事实、数值、短结论 | `facts/facts.md` | `-t tag -f "..."` |
| 失败与修正 | `notes/errors.md` | `-e "症状"` |

## 脚本

只依赖 POSIX sh 与基础命令（`mkdir cp mv rm sed grep find wc date awk tr cut head sort uniq`）。

```bash
S=<skill-dir>/scripts

# 初始化（幂等）
sh $S/mem-init.sh

# 写入
sh $S/mem-add.sh -t pref -f "key = value"      # 原子事实
sh $S/mem-add.sh -T "项目名" -s active          # 主题笔记
sh $S/mem-add.sh -T "项目名" -s done -n slug    # 指定文件名
sh $S/mem-add.sh -m "规则一句话"                # 稳定规则
sh $S/mem-add.sh -e "错误症状"                  # 错误记录

# 读取
sh $S/mem-search.sh "关键词"
sh $S/mem-search.sh -t pref
sh $S/mem-search.sh -r 7
sh $S/mem-search.sh -d notes "frida"
sh $S/mem-search.sh --brief "frida"
sh $S/mem-search.sh --files
sh $S/mem-search.sh -a "关键词"                 # 含 archive

# 维护
sh $S/mem-stat.sh
sh $S/mem-doctor.sh
sh $S/mem-doctor.sh --verbose
sh $S/mem-doctor.sh --json
sh $S/mem-compact.sh --dry-run
sh $S/mem-compact.sh --apply
sh $S/mem-monthly.sh --dry-run
sh $S/mem-monthly.sh
```

## 容量阈值

| 对象 | 警告 | 上限 |
|---|---|---|
| `MEMORY.md` | 6400 字符 | 8000 |
| `INDEX.md` | 1500 字符 | 2000 |
| 单个 `notes/*.md` | 4000 字符 | 6000 |
| `facts/facts.md` | 300 条 | 500 |
| `notes/` 文件数 | 20 个 | 30 |

## 失败处理

- 记忆库不存在 → 跑 `mem-init.sh`，不要手工散落文件。
- 检索无结果 → 明确说「库里没有」，不要猜。
- 记忆与用户当前说法冲突 → 以当前说法为准，覆写并注明变更原因。
- 条目疑似过时 → 标 `status: stale`，7 天未确认由 `mem-monthly.sh` 归档。

## 可移植

- 换机器/换 AI：只搬 `memory/` 目录。
- 各平台接入片段见 `references/portability.md`。
- 无文件系统的环境（纯网页版）用「补丁模式」，见同一文档。

## 边界

- `mem-compact.sh` / `mem-monthly.sh` 只做机械动作（备份、归档、刷 revision）。
- 语义合并、规则提炼需要模型判断，见 `references/compaction.md`。
- 不存明文凭据。只存指针，如 `cred_ref = 1Password 条目 X`。
