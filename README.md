# memory-system

[![shellcheck](https://github.com/abaoxg/memory-system/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/abaoxg/memory-system/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

一套**零依赖、跨平台、可移植**的 AI 长期记忆系统。纯文件驱动，不依赖数据库、向量库或云服务。

给任何能读写文件的 AI 用：Claude Code、Cursor、Codex、ChatGPT、Ollama、本地模型、手机 Agent。

---

## 它解决什么问题

AI 每次新对话都是失忆的。这套东西给 AI 一个**外部硬盘**：

- 对话结束，上下文清空
- 下次开机，读 `INDEX.md` + `MEMORY.md`，历史就回来了

**关键：记忆不在模型里，在磁盘上。** 换模型、换平台、换设备，只要文件夹在，记忆就在。

---

## 核心设计：三层粒度

| 层 | 文件 | 何时读 | 上限 |
|---|---|---|---|
| L0 | `INDEX.md` | 每轮 | 2000 字符 |
| L1 | `MEMORY.md` | 每轮 | 8000 字符 |
| L2 | `notes/*.md` | 命中才读 | 单个 6000 |
| L3 | `facts/facts.md` | 需要具体值时 grep | 500 条 |
| L4 | `archive/` | 点名历史时 | — |

**为什么分层**：上下文是稀缺资源。90% 的对话只需要 L0+L1，约 500 tokens。全塞进 prompt 是 30000 tokens，差 60 倍。

---

## 零硬编码路径

按优先级自动探测，第一个命中即用：

| 顺序 | 来源 | 说明 |
|---|---|---|
| 1 | `$MEMORY_ROOT` | 显式指定，最高优先 |
| 2 | 向上 6 层找 `memory/` 或 `.ai-memory/` | **必须同时有 `MEMORY.md` 和 `INDEX.md`** |
| 3 | `$HOME/.ai-memory` | 用户级默认 |
| 4 | `./memory` | 项目级兜底 |

---

## 快速开始

```bash
# 1. 克隆
git clone https://github.com/abaoxg/memory-system.git ~/tools/memory-system

# 2. 选持久位置
export MEMORY_ROOT="$HOME/.ai-memory"

# 3. 初始化
sh ~/tools/memory-system/scripts/mem-init.sh

# 4. 固化路径（别省）
echo 'export MEMORY_ROOT="$HOME/.ai-memory"' >> ~/.bashrc
```

---

## 七个脚本

| 脚本 | 作用 | 关键参数 |
|---|---|---|
| `_common.sh` | 工具层（路径/计数/日期） | 被其他脚本 source |
| `mem-init.sh` | 初始化，幂等 | — |
| `mem-add.sh` | 写入 | `-f` 事实 / `-T` 主题 / `-m` 规则 / `-e` 错误 / `-n` 指定名 |
| `mem-search.sh` | 检索 | `-t` 标签 / `-r` 近N天 / `-d` 目录 / `--brief` / `--files` / `-a` 含归档 |
| `mem-stat.sh` | 容量速览 | — |
| `mem-doctor.sh` | 六维体检 | `--verbose` / `--json` |
| `mem-compact.sh` | 压缩执行 | `--dry-run` / `--apply` |
| `mem-monthly.sh` | 月度巡检 | `--dry-run` |

### 写入

```bash
S=~/tools/memory-system/scripts

sh $S/mem-add.sh -t pref -f "称呼 = 爸爸"        # 原子事实
sh $S/mem-add.sh -T "项目A" -s active            # 主题笔记
sh $S/mem-add.sh -T "项目A" -n custom-slug       # 指定文件名
sh $S/mem-add.sh -m "规则一句话"                 # 稳定规则
sh $S/mem-add.sh -e "错误症状"                   # 错误记录
```

### 检索

```bash
sh $S/mem-search.sh "关键词"
sh $S/mem-search.sh -t pref
sh $S/mem-search.sh -r 7
sh $S/mem-search.sh --brief "frida"
sh $S/mem-search.sh --files
```

### 维护

```bash
sh $S/mem-stat.sh                  # 容量速览
sh $S/mem-doctor.sh                # 完整体检
sh $S/mem-doctor.sh --json         # 机器可读
sh $S/mem-compact.sh --dry-run     # 压缩预览
sh $S/mem-monthly.sh               # 月度巡检
```

---

## mem-doctor 查什么

六类判定，输出四段（`[问题]` `[待办]` `[警告]` `[正常项]`）：

1. **容量水位** — 四个对象是否超标
2. **事实晋升** — 同标签 ≥3 条，直接告诉你合并成哪一行
3. **错误晋升** — `errors.md` ≥3 条，提示提炼规则
4. **陈旧归档** — `stale` >7 天 / `done` >90 天
5. **噪声清理** — 重复行 / 空条目 / 超 300 字符单条
6. **结构一致性** — `INDEX.md` 和实际文件对不对得上（能抓死链）

---

## 容量阈值

| 对象 | 警告 | 上限 |
|---|---|---|
| `MEMORY.md` | 6400 | 8000 |
| `INDEX.md` | 1500 | 2000 |
| 单个 `notes/*.md` | 4000 | 6000 |
| `facts/facts.md` | 300 条 | 500 |
| `notes/` 文件数 | 20 | 30 |

---

## 依赖

**只要求 POSIX sh**，以及标准命令：

```
mkdir cp mv rm sed grep find wc date awk tr cut head sort uniq
```

不依赖 bash、Python、Node、gcc、数据库或云服务。

### 已验证环境

| 环境 | 工具链 | 状态 |
|---|---|---|
| Debian | GNU coreutils / grep / sed / awk | 通过 |
| Android | BusyBox 1.36（Magisk/KernelSU） | 通过 |
| Alpine | BusyBox | 预期通过 |
| macOS / BSD | BSD 工具链 | `sed -i` 已双路兼容 |
| Windows | Git Bash / WSL | 预期通过 |

### 跨平台兼容处理

| 问题 | 解法 |
|---|---|
| `sed -i` 语法不同 | 双路尝试 `-i.bak` 和 `-i ''` |
| BusyBox `grep -c` 无匹配输出 `0\n0` | 统一封装 `count_matches()` 取首行 |
| `grep --include` 不支持 | 改 `find \| sort` 管道 |
| 没有 `/tmp` | 走 `$TMPDIR`，优先环境变量 |
| `> /dev/null` 让脚本 exit=1 | `say()` 改 `\|\| :`，`set -eu` 改 `set -u` |
| BSD `date` 不支持 `-d` | `date -r` 与 `date -d @` 双路 fallback |

---

## 各平台接入

详见 [`references/portability.md`](references/portability.md)，含：

- Claude Code
- Cursor
- Codex / AGENTS.md
- Ollama / LM Studio / 本地模型
- ChatGPT / 纯网页版（补丁模式）
- Termux / Android
- Windows

---

## 工具层怎么用（给 AI 的说明）

`SKILL.md` 是给 AI 读的触发契约，含：

- 三层粒度定义
- 会话启动流程（先读 `INDEX.md`）
- 会话收尾流程（判断类型 → 写对应文件）
- 写入目标选择表
- 失败处理规则

把 `SKILL.md` 全文放进系统提示，或放到 AI 平台的 skills 目录即可。

---

## 设计边界（说实话）

1. **不做语义压缩。** `mem-compact.sh` / `mem-monthly.sh` 只做机械动作（备份、归档、刷 revision）。合并规则、提炼结论需要模型判断，见 `references/compaction.md`。
2. **不做向量检索。** 纯 grep。几千行毫秒级，但语料上万条会开始吵。
3. **不存明文凭据。** 只存指针，如 `cred_ref = 1Password 条目 X`。
4. **sdcardfs 有毛病。** Android 共享存储不保留可执行位、不让改 mtime。装到 ext4 路径没这问题。

---

## 目录结构

```text
memory-system/
├── SKILL.md                    给 AI 的触发契约
├── INSTALL.md                  安装与使用说明
├── README.md                   本文件
├── references/
│   ├── schema.md               三层粒度格式 + 标签词表 + 禁写清单
│   ├── retrieval.md            L0-L4 注入分层 + 衰减权重
│   ├── compaction.md           晋升/合并/降级/归档
│   └── portability.md          各平台接入片段
├── assets/
│   ├── MEMORY.template.md
│   ├── INDEX.template.md
│   └── notes.template.md
└── scripts/
    ├── _common.sh              路径解析 + 跨平台工具层
    ├── mem-init.sh
    ├── mem-add.sh
    ├── mem-search.sh
    ├── mem-stat.sh
    ├── mem-doctor.sh
    ├── mem-compact.sh
    └── mem-monthly.sh
```

---

## 一笔 token 账

| 场景 | 每轮增量 |
|---|---|
| 不用记忆系统 | 0（但每轮重复问用户） |
| 当前规模实际 | ~500 tokens |
| 撞上限 | ~3500 tokens |
| 全塞进 prompt | ~30000 tokens |

---

## License

MIT
