#!/bin/sh
# mem-stat.sh — 容量速览与超限告警
set -u

_SELF_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
export SKILL_ROOT_HINT=$(cd "$_SELF_DIR/.." 2>/dev/null && pwd)
. "$_SELF_DIR/_common.sh"

ROOT=$(resolve_memory_root)
BUDGET=8000
NBUDGET=6000

[ -d "$ROOT" ] || { say "记忆库不存在: $ROOT"; exit 1; }
ROOT=$(cd "$ROOT" 2>/dev/null && pwd)

say "记忆库: $ROOT"
if [ -n "${MEMORY_ROOT:-}" ]; then
  say "来源: \$MEMORY_ROOT"
else
  say "来源: 自动解析（建议 export MEMORY_ROOT 固定）"
fi
say ""

if [ -f "$ROOT/MEMORY.md" ]; then
  c=$(count_chars "$ROOT/MEMORY.md")
  pct=$((c * 100 / BUDGET))
  printf 'MEMORY.md   %6s 字符  %3s%% / %s  %s 行\n' "$c" "$pct" "$BUDGET" "$(count_lines "$ROOT/MEMORY.md")"
  [ "$c" -gt "$BUDGET" ] && say "  !! 超预算 -> mem-compact.sh --apply"
  printf '  revision=%s  updated=%s\n' "$(fm_get "$ROOT/MEMORY.md" revision)" "$(fm_get "$ROOT/MEMORY.md" updated)"
else
  say "MEMORY.md   缺失"
fi

say ""
say "主题笔记:"
found=0
if [ -d "$ROOT/notes" ]; then
  for f in "$ROOT"/notes/*.md; do
    [ -f "$f" ] || continue
    found=1
    c=$(count_chars "$f")
    mark=""
    [ "$c" -gt "$NBUDGET" ] && mark="  !! 超预算"
    printf '  %-34s %6s 字符  %-8s%s\n' "$(basename "$f")" "$c" "$(fm_get "$f" status)" "$mark"
  done
fi
[ "$found" -eq 0 ] && say "  (无)"

say ""
if [ -f "$ROOT/facts/facts.md" ]; then
  n=$(count_matches '^- \[' "$ROOT/facts/facts.md")
  say "原子事实: $n 条"
  if [ "$n" -gt 0 ]; then
    say "标签分布:"
    grep -o '^- \[[0-9-]*\] \[[a-z]*\]' "$ROOT/facts/facts.md" 2>/dev/null \
      | sed 's/.*\[\([a-z]*\)\]/\1/' | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
  fi
else
  say "原子事实: 缺失"
fi

say ""
if [ -d "$ROOT/archive" ]; then
  n=$(find "$ROOT/archive" -type f 2>/dev/null | wc -l | tr -d ' \n')
  say "归档: ${n:-0} 个文件"
fi

if [ -f "$ROOT/INDEX.md" ]; then
  say "INDEX.md: $(count_chars "$ROOT/INDEX.md") 字符"
else
  say "INDEX.md: 缺失"
fi
exit 0
