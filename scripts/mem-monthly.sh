#!/bin/sh
# mem-monthly.sh — 月度巡检：体检 + 自动归档 stale + 备份
#
#   mem-monthly.sh             执行
#   mem-monthly.sh --dry-run   只看
set -u

_SELF_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
export SKILL_ROOT_HINT=$(cd "$_SELF_DIR/.." 2>/dev/null && pwd)
. "$_SELF_DIR/_common.sh"

SKILL=$(skill_dir)
ROOT=$(resolve_memory_root)
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

[ -d "$ROOT" ] || { say "记忆库不存在: $ROOT"; exit 1; }
ROOT=$(cd "$ROOT" 2>/dev/null && pwd)
DATE=$(today); MONTH=$(this_month)

say "===== 月度巡检 $DATE ====="
say ""

sh "$SKILL/scripts/mem-doctor.sh"

say ""
say "===== 归档 stale ====="
moved=0
if [ -d "$ROOT/notes" ]; then
  for f in "$ROOT"/notes/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    [ "$base" = "errors.md" ] && continue
    st=$(fm_get "$f" status)
    [ "$st" = "stale" ] || continue
    older_than "$f" 7 || continue

    if [ "$DRY" -eq 1 ]; then
      say "  [dry] 将归档: $base"
    else
      mkdir -p "$ROOT/archive" 2>/dev/null || :
      {
        printf '\n## 归档 %s | %s\n\n' "$DATE" "$base"
        cat "$f"
      } >> "$ROOT/archive/$MONTH.md"
      rm -f "$f"
      if [ -f "$ROOT/INDEX.md" ]; then
        grep -v "notes/$base" "$ROOT/INDEX.md" > "$ROOT/INDEX.md.t" 2>/dev/null && mv "$ROOT/INDEX.md.t" "$ROOT/INDEX.md"
      fi
      say "  已归档: $base"
    fi
    moved=$((moved + 1))
  done
fi
[ "$moved" -eq 0 ] && say "  无需归档"

if [ "$DRY" -eq 0 ]; then
  say ""
  say "===== 备份 ====="
  BK="$ROOT/archive/$DATE-backup"
  if [ -d "$BK" ]; then
    say "  今日已备份，跳过"
  else
    mkdir -p "$BK" 2>/dev/null || :
    [ -f "$ROOT/MEMORY.md" ] && cp -a "$ROOT/MEMORY.md" "$BK/" 2>/dev/null || :
    [ -f "$ROOT/INDEX.md" ] && cp -a "$ROOT/INDEX.md" "$BK/" 2>/dev/null || :
    [ -d "$ROOT/notes" ] && cp -a "$ROOT/notes" "$BK/" 2>/dev/null || :
    [ -d "$ROOT/facts" ] && cp -a "$ROOT/facts" "$BK/" 2>/dev/null || :
    say "  $BK"
  fi
fi

say ""
say "===== 手动跟进 ====="
say "  晋升/合并需语义判断，看上方「待办」区逐条处理。"
say "  核对: MEMORY_ROOT=$ROOT sh $SKILL/scripts/mem-stat.sh"
[ "$DRY" -eq 1 ] && { say ""; say "(--dry-run，未改动)"; }
exit 0
