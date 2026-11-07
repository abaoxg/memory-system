#!/bin/sh
# mem-compact.sh — 压缩计划与执行
#
#   mem-compact.sh --dry-run   只看方案
#   mem-compact.sh --apply     备份 + 归档 stale + 刷 revision
set -u

_SELF_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
export SKILL_ROOT_HINT=$(cd "$_SELF_DIR/.." 2>/dev/null && pwd)
. "$_SELF_DIR/_common.sh"

ROOT=$(resolve_memory_root)
BUDGET=8000
NBUDGET=6000
MODE="dry"

case "${1:-}" in
  --apply) MODE="apply" ;;
  --dry-run|"") MODE="dry" ;;
  -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
  *) say "未知参数: $1"; exit 1 ;;
esac

[ -d "$ROOT" ] || { say "记忆库不存在: $ROOT"; exit 1; }
ROOT=$(cd "$ROOT" 2>/dev/null && pwd)
DATE=$(today); MONTH=$(this_month)

say "== 压缩检查 ($MODE) =="
say "根目录: $ROOT"
say ""

PLAN=""

if [ -f "$ROOT/MEMORY.md" ]; then
  c=$(count_chars "$ROOT/MEMORY.md")
  say "MEMORY.md: $c / $BUDGET"
  if [ "$c" -gt "$BUDGET" ]; then
    over=$((c - BUDGET))
    say "  -> 超出 $over 字符"
    PLAN="$PLAN
- MEMORY.md 超 $over 字符: 把 90 天未命中项目降级到 notes/"
  fi
fi

for f in "$ROOT"/notes/*.md; do
  [ -f "$f" ] || continue
  c=$(count_chars "$f")
  if [ "$c" -gt "$NBUDGET" ]; then
    say "$(basename "$f"): $c / $NBUDGET -> 需摘要化"
    PLAN="$PLAN
- notes/$(basename "$f") 超 $((c - NBUDGET)) 字符: 压缩「现状」「变更记录」"
  fi
done

if [ -d "$ROOT/notes" ]; then
  for f in "$ROOT"/notes/*.md; do
    [ -f "$f" ] || continue
    st=$(fm_get "$f" status)
    if [ "$st" = "stale" ] && older_than "$f" 7; then
      say "$(basename "$f"): stale 超 7 天"
      PLAN="$PLAN
- notes/$(basename "$f") 归档到 archive/$MONTH.md"
    elif [ "$st" = "done" ] && older_than "$f" 90; then
      PLAN="$PLAN
- notes/$(basename "$f") done 超 90 天: 归档"
    fi
  done
fi

if [ -f "$ROOT/facts/facts.md" ]; then
  say ""
  say "事实晋升候选 (同 tag >= 3):"
  grep -o '^- \[[0-9-]*\] \[[a-z]*\]' "$ROOT/facts/facts.md" 2>/dev/null \
    | sed 's/.*\[\([a-z]*\)\]/\1/' | sort | uniq -c \
    | awk '$1>=3{printf "  [%s] %s 条 -> 可合并入 MEMORY.md\n",$2,$1}'
fi

say ""
say "== 计划 =="
if [ -z "$PLAN" ]; then
  say "无需压缩。"
else
  printf '%s\n' "$PLAN"
fi

if [ "$MODE" != "apply" ]; then
  say ""
  say "(dry-run，未改动。执行: $0 --apply)"
  exit 0
fi

# 备份
BK="$ROOT/archive/$DATE-backup"
mkdir -p "$BK" 2>/dev/null || :
[ -f "$ROOT/MEMORY.md" ] && cp -a "$ROOT/MEMORY.md" "$BK/" 2>/dev/null || :
[ -f "$ROOT/INDEX.md" ] && cp -a "$ROOT/INDEX.md" "$BK/" 2>/dev/null || :
[ -d "$ROOT/notes" ] && cp -a "$ROOT/notes" "$BK/" 2>/dev/null || :
[ -d "$ROOT/facts" ] && cp -a "$ROOT/facts" "$BK/" 2>/dev/null || :
say ""
say "已备份: archive/$DATE-backup/"

# 归档 stale
ARCH="$ROOT/archive/$MONTH.md"
if [ -d "$ROOT/notes" ]; then
  for f in "$ROOT"/notes/*.md; do
    [ -f "$f" ] || continue
    st=$(fm_get "$f" status)
    [ "$st" = "stale" ] || continue
    older_than "$f" 7 || continue
    base=$(basename "$f")
    {
      printf '\n## 归档 %s | %s\n\n' "$DATE" "$base"
      cat "$f"
    } >> "$ARCH"
    rm -f "$f"
    if [ -f "$ROOT/INDEX.md" ]; then
      grep -v "notes/$base" "$ROOT/INDEX.md" > "$ROOT/INDEX.md.t" 2>/dev/null && mv "$ROOT/INDEX.md.t" "$ROOT/INDEX.md"
    fi
    say "已归档: $base"
  done
fi

# 刷 meta
if [ -f "$ROOT/MEMORY.md" ]; then
  cur=$(sed -n 's/^revision:[[:space:]]*//p' "$ROOT/MEMORY.md" | head -1)
  case "$cur" in ''|*[!0-9]*) cur=0 ;; esac
  sed -i.bak "s/^revision:.*/revision: $((cur + 1))/" "$ROOT/MEMORY.md" 2>/dev/null || \
    sed -i '' "s/^revision:.*/revision: $((cur + 1))/" "$ROOT/MEMORY.md" 2>/dev/null || :
  sed -i.bak "s/^updated:.*/updated: $DATE/" "$ROOT/MEMORY.md" 2>/dev/null || \
    sed -i '' "s/^updated:.*/updated: $DATE/" "$ROOT/MEMORY.md" 2>/dev/null || :
  rm -f "$ROOT/MEMORY.md.bak" 2>/dev/null || :
fi

say ""
say "完成。语义合并仍需人工/模型处理（见 references/compaction.md）。"
exit 0
