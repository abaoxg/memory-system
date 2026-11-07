# 安装与使用

平台无关。任何能读写文件的设备或 AI 环境都能用。

## 快速开始

```bash
# 1. 解压
unzip memory-system-skill.zip -d ~/tools/

# 2. 选持久位置当记忆库
export MEMORY_ROOT="$HOME/.ai-memory"

# 3. 初始化
sh ~/tools/memory-system/scripts/mem-init.sh

# 4. 固化路径（别省）
echo 'export MEMORY_ROOT="$HOME/.ai-memory"' >> ~/.bashrc
```

不固定 `MEMORY_ROOT` 时，脚本按「向上查找 → `$HOME/.ai-memory` → `./memory`」推断，换目录就指向不同库。

## 路径解析规则

| 顺序 | 位置 | 说明 |
|---|---|---|
| 1 | `$MEMORY_ROOT` | 显式指定，最高优先 |
| 2 | 向上 6 层找 `memory/MEMORY.md` + `INDEX.md` | 双特征才算库根 |
| 3 | 向上 6 层找 `.ai-memory/` 同上 | 隐藏目录变体 |
| 4 | `$HOME/.ai-memory` | 用户级默认 |
| 5 | `./memory` | 当前目录兜底 |

## 日常用法

```bash
S=~/tools/memory-system/scripts

# 写
sh $S/mem-add.sh -t pref -f "key = value"       # 原子事实
sh $S/mem-add.sh -T "项目名" -s active           # 主题笔记
sh $S/mem-add.sh -T "项目名" -n custom-slug      # 指定文件名
sh $S/mem-add.sh -m "规则一句话"                 # 稳定规则
sh $S/mem-add.sh -e "错误症状"                   # 错误记录

# 读
sh $S/mem-search.sh "关键词"
sh $S/mem-search.sh -t pref
sh $S/mem-search.sh -r 7
sh $S/mem-search.sh -d notes "frida"
sh $S/mem-search.sh --brief "frida"
sh $S/mem-search.sh --files
sh $S/mem-search.sh -a "关键词"                  # 含 archive

# 维护
sh $S/mem-stat.sh                    # 容量速览
sh $S/mem-doctor.sh                  # 完整体检
sh $S/mem-doctor.sh --verbose        # 含正常项
sh $S/mem-doctor.sh --json           # 机器可读
sh $S/mem-compact.sh --dry-run       # 压缩预览
sh $S/mem-compact.sh --apply         # 备份+归档
sh $S/mem-monthly.sh --dry-run       # 月度巡检预览
sh $S/mem-monthly.sh                 # 月度巡检执行
```

## 维护脚本怎么选

| 场景 | 用哪个 |
|---|---|
| 日常看容量 | `mem-stat.sh` |
| 想知道该整理什么 | `mem-doctor.sh` |
| 每月例行 + 自动归档 | `mem-monthly.sh` |
| 手动压缩 | `mem-compact.sh` |

推荐：每月跑一次 `mem-monthly.sh`，其余按需 `mem-doctor.sh`。

## mem-doctor 查什么

六类判定：

1. **容量水位** — `MEMORY.md` / `INDEX.md` / `notes` / `facts`
2. **事实晋升** — 同标签 ≥3 条，提示合并
3. **错误晋升** — `errors.md` ≥3 条，提示提炼规则
4. **陈旧归档** — `stale` >7 天 / `done` >90 天
5. **噪声清理** — 重复行 / 空条目 / 超 300 字符单条
6. **结构一致性** — `INDEX.md` 与实际文件是否对应

## mem-monthly 自动做什么

**只做无损动作：**

- 归档 `status: stale` 且超 7 天的笔记 → `archive/YYYY-MM.md`
- 同步删除 `INDEX.md` 里指向已归档文件的行
- 备份到 `archive/<日期>-backup/`

**不做：**

- 不合并语义、不提炼规则
- 不删 active 笔记
- 不碰 `facts/facts.md`

## 容量阈值

| 对象 | 警告 | 上限 |
|---|---|---|
| `MEMORY.md` | 6400 | 8000 |
| `INDEX.md` | 1500 | 2000 |
| 单个 `notes/*.md` | 4000 | 6000 |
| `facts/facts.md` | 300 条 | 500 条 |
| `notes/` 文件数 | 20 | 30 |

## slug 命名

| 输入 | 结果 |
|---|---|
| `memory-system skill` | `memory-system-skill.md` |
| `frida hook` | `frida-hook.md` |
| `目标A` | `a-578569999.md`（纯中文附 hash 防撞） |
| `!!!` | `topic-206556925.md`（无 ASCII 用 hash） |

自定义文件名加 `-n`。

## 依赖

**只要求 POSIX sh**，以及标准命令：

```
mkdir cp mv rm sed grep find wc date awk tr cut head sort uniq
```

不依赖 bash、Python、Node、gcc、数据库或云服务。

已验证：

| 环境 | 工具链 | 状态 |
|---|---|---|
| Debian | GNU coreutils / grep / sed / awk | 通过 |
| Android (Magisk/KernelSU) | BusyBox 1.36 | 通过 |
| Alpine | BusyBox | 预期通过 |
| macOS / BSD | BSD 工具链 | `sed -i` 已双路兼容 |
| Windows | Git Bash / WSL | 预期通过 |

## 各平台 AI 接入

见 `references/portability.md`。

## 已知边界

1. **不做语义压缩。** `mem-compact.sh` / `mem-monthly.sh` 只做机械动作，合并与提炼要模型按 `references/compaction.md` 执行。
2. **不做向量检索。** 靠 grep + 分层加载控制 token，零依赖。
3. **不存明文凭据。** 只存指针，形如 `cred_ref = 1Password 条目 X`。
4. **sdcardfs 环境**：不保留可执行位、不允许改 mtime。解压后需 `chmod +x scripts/*.sh`；测试归档逻辑请用 ext4 路径。
