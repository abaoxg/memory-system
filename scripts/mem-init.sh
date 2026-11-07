#!/bin/sh
# mem-init.sh — 初始化记忆库（幂等，不覆盖已有文件）
#
#   sh mem-init.sh                             使用自动解析的路径
#   MEMORY_ROOT=/path/to/mem sh mem-init.sh    显式指定
set -u

_SELF_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
export SKILL_ROOT_HINT=$(cd "$_SELF_DIR/.." 2>/dev/null && pwd)
. "$_SELF_DIR/_common.sh"

SKILL=$(skill_dir)
ROOT=$(resolve_memory_root)
DATE=$(today)

mkdir -p "$ROOT/notes" "$ROOT/facts" "$ROOT/archive"

created=0; skipped=0

# MEMORY.md
if [ ! -f "$ROOT/MEMORY.md" ]; then
  if [ -f "$SKILL/assets/MEMORY.template.md" ]; then
    sed "s/{{DATE}}/$DATE/g" "$SKILL/assets/MEMORY.template.md" > "$ROOT/MEMORY.md" 2>/dev/null || :
  fi
  if [ ! -f "$ROOT/MEMORY.md" ]; then
    printf '# 核心记忆\n\n## 用户\n\n## 环境\n\n## 项目\n\n## 规则\n' > "$ROOT/MEMORY.md"
  fi
  say "[init] MEMORY.md"; created=$((created+1))
else
  say "[skip] MEMORY.md"; skipped=$((skipped+1))
fi

# INDEX.md
if [ ! -f "$ROOT/INDEX.md" ]; then
  if [ -f "$SKILL/assets/INDEX.template.md" ]; then
    cat "$SKILL/assets/INDEX.template.md" > "$ROOT/INDEX.md" 2>/dev/null || :
  fi
  if [ ! -f "$ROOT/INDEX.md" ]; then
    printf '# 记忆索引\n\n## 核心\n- `MEMORY.md`\n\n## 主题笔记\n- （尚无笔记）\n\n## 原子事实\n- `facts/facts.md`\n' > "$ROOT/INDEX.md"
  fi
  say "[init] INDEX.md"; created=$((created+1))
else
  say "[skip] INDEX.md"; skipped=$((skipped+1))
fi

# facts
if [ ! -f "$ROOT/facts/facts.md" ]; then
  printf '# 原子事实\n\n格式: - [YYYY-MM-DD] [tag] key = value   # 说明\n\n' > "$ROOT/facts/facts.md"
  say "[init] facts/facts.md"; created=$((created+1))
else
  say "[skip] facts/facts.md"; skipped=$((skipped+1))
fi

# errors
if [ ! -f "$ROOT/notes/errors.md" ]; then
  printf '# 错误与修正\n\n## YYYY-MM-DD | <症状>\n- 场景:\n- 触发:\n- 报错:\n- 根因:\n- 修正规则:\n' > "$ROOT/notes/errors.md"
  say "[init] notes/errors.md"; created=$((created+1))
else
  say "[skip] notes/errors.md"; skipped=$((skipped+1))
fi

# 自检
fail=""
for f in MEMORY.md INDEX.md facts/facts.md notes/errors.md; do
  [ -f "$ROOT/$f" ] || fail="$fail $f"
done

say ""
if [ -n "$fail" ]; then
  say "初始化未完成，缺少:$fail"
  say "检查目录是否存在且可写: $ROOT"
  exit 1
fi

say "记忆库: $ROOT"
say "新建 $created 项，跳过 $skipped 项"
say ""
say "建议固定路径，避免换目录指向不同库:"
say "  export MEMORY_ROOT=$ROOT"
exit 0
