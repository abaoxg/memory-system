# 多平台接入

记忆是纯文本，任何能读写文件的 AI 都能用。唯一要适配的是「怎么让它自动读」。

## 通用三步

```bash
# 1. 解压
unzip memory-system-skill.zip -d ~/tools/

# 2. 初始化
export MEMORY_ROOT="$HOME/.ai-memory"
sh ~/tools/memory-system/scripts/mem-init.sh

# 3. 固定路径
echo 'export MEMORY_ROOT="$HOME/.ai-memory"' >> ~/.bashrc
```

之后所有脚本自动找到库。

## Claude Code

把 `SKILL.md` 放到 skills 目录，或在 `CLAUDE.md` 加：

```markdown
## Memory
启动时读 $MEMORY_ROOT/INDEX.md 与 $MEMORY_ROOT/MEMORY.md，
按 INDEX 只加载相关 notes。
任务结束按 memory-system/SKILL.md 的「会话收尾流程」写回。
```

放在 `~/.claude/skills/memory-system/` 时，会按 frontmatter 的 description 自动触发。

## Cursor

`.cursorrules` 或 `.cursor/rules/memory.mdc`：

```text
启动先读 memory/INDEX.md 和 memory/MEMORY.md。
只加载 INDEX 中与当前任务相关的 notes。
收尾写入按 memory-system/SKILL.md 执行。
MEMORY.md 超 8000 字符时提醒压缩。
```

## Codex / AGENTS.md 类

```markdown
## Memory
- Read memory/INDEX.md and memory/MEMORY.md at session start.
- Load only notes referenced by INDEX.md that match the task.
- Write back per memory-system/SKILL.md 收尾流程.
- Compact when MEMORY.md exceeds 8000 chars:
  sh memory-system/scripts/mem-compact.sh --apply
```

## Ollama / LM Studio / 本地模型

system prompt：

```text
你带长期记忆。会话开始先读 memory/INDEX.md 和 memory/MEMORY.md，
按 INDEX 加载相关 notes 文件。会话结束把新偏好、项目状态、可复用流程
按 memory-system/SKILL.md 规则写回，并更新 INDEX.md。
只写跨会话可复用的内容；MEMORY.md 不超过 8000 字，超了先压缩。
禁止写入明文密码、Token、私钥。
```

## ChatGPT / 纯网页版（无文件系统）

两种退化方案：

**A. 自定义指令**

把 `MEMORY.md` 全文粘进 Settings → Personalization → Custom Instructions。
每次新会话手动贴 `INDEX.md`。

**B. 补丁模式（推荐）**

让模型每次回答末尾输出 unified diff：

```text
请在回答最后输出一个 ```patch 代码块，只包含需要写入 memory/ 的改动，
格式为 unified diff，路径相对 memory/。
```

本地应用：

```bash
cd "$MEMORY_ROOT" && patch -p1 < ~/Downloads/patch.diff
```

## Termux / Android

```bash
export MEMORY_ROOT="$HOME/storage/shared/ai-memory"
sh memory-system/scripts/mem-init.sh
```

Android 共享存储（`/storage/emulated/0`）是 sdcardfs：

- **不保留可执行位** → 解压后必须 `chmod +x scripts/*.sh`
- **不允许改 mtime** → 测试归档逻辑请用 ext4 路径（如 `/data/local/tmp`）

这两条是存储层特性，与脚本无关。

## Windows

Git Bash 或 WSL：

```bash
export MEMORY_ROOT="$HOME/ai-memory"
sh memory-system/scripts/mem-init.sh
```

脚本已对 `sed -i` 做双路兼容（`-i.bak` 与 `-i ''`）。

## 多设备同步

| 方式 | 做法 | 注意 |
|---|---|---|
| 云盘 | `memory/` 放 Syncthing / 坚果云 / iCloud | 冲突取 `updated` 较新 |
| Git | `cd memory && git init && git add -A && git commit` | 可追溯，冲突手工合并 |
| 手动 | 打包 `memory/` 搬运 | 简单，需停用一端 |

冲突解决：同 key 取 `updated` 新者；同日期取文件较大者；保留 `.conflict-<date>` 副本。

## 迁移检查清单

- [ ] `INDEX.md` 存在且条目指向真实文件
- [ ] `MEMORY.md` 在 8000 字符内
- [ ] `MEMORY_ROOT` 已写入 shell 配置
- [ ] `sh scripts/mem-stat.sh` 无报错
- [ ] 新 AI 首轮能复述「已恢复：…」
- [ ] 无明文凭据入库
- [ ] 已留备份
