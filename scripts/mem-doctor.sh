#!/bin/sh
# mem-doctor.sh — 记忆库体检：问题 / 待办 / 警告
#
#   mem-doctor.sh            体检
#   mem-doctor.sh --verbose  含正常项
#   mem-doctor.sh --json     机器可读
set -u

_SELF_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
export SKILL_ROOT_HINT=$(cd "$_SELF_DIR/.." 2>/dev/null && pwd)
. "$_SELF_DIR/_common.sh"

ROOT=$(resolve_memory_root)
MODE="human"
VERBOSE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --json) MODE="json"; shift ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) say "未知参数: $1"; exit 1 ;;
  esac
done

[ -d "$ROOT" ] || { say "记忆库不存在: $ROOT"; exit 1; }
ROOT=$(cd "$ROOT" 2>/dev/null && pwd)
DATE=$(today)

BUDGET_MEMORY=8000
WARN_MEMORY=6400
BUDGET_INDEX=2000
BUDGET_NOTE=6000
WARN_FACTS=500
WARN_NOTES=30
STALE_DAYS=7
DONE_DAYS=90

TMP=$(temp_dir "$ROOT")
WORK="$TMP/.doc.$$"
: > "$WORK"
trap 'rm -f "$WORK"' EXIT INT TERM

add() { printf '%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" >> "$WORK"; }

# 1. 容量
if [ -f "$ROOT/MEMORY.md" ]; then
  c=$(count_chars "$ROOT/MEMORY.md")
  pct=$((c * 100 / BUDGET_MEMORY))
  if [ "$c" -gt "$BUDGET_MEMORY" ]; then
    add "ERROR" "MEMORY.md 超预算" "${c} 字符 / ${BUDGET_MEMORY} (${pct}%)" "mem-compact.sh --apply 后手工降级"
  elif [ "$c" -gt "$WARN_MEMORY" ]; then
    add "WARN" "MEMORY.md 接近上限" "${c} 字符 / ${BUDGET_MEMORY} (${pct}%)" "规划晋升与降级"
  else
    add "OK" "MEMORY.md 容量正常" "${c} 字符 (${pct}%)" ""
  fi
else
  add "ERROR" "MEMORY.md 缺失" "" "运行 mem-init.sh"
fi

if [ -f "$ROOT/INDEX.md" ]; then
  c=$(count_chars "$ROOT/INDEX.md")
  if [ "$c" -gt "$BUDGET_INDEX" ]; then
    add "WARN" "INDEX.md 过长" "${c} 字符 / ${BUDGET_INDEX}" "索引只留指针"
  else
    add "OK" "INDEX.md 容量正常" "${c} 字符" ""
  fi
else
  add "ERROR" "INDEX.md 缺失" "" "运行 mem-init.sh"
fi

# 2. facts 晋升
FACTS="$ROOT/facts/facts.md"
if [ -f "$FACTS" ]; then
  total=$(count_matches '^- \[' "$FACTS")
  if [ "$total" -gt "$WARN_FACTS" ]; then
    add "WARN" "facts 条目过多" "${total} 条 / 建议 ${WARN_FACTS}" "按月分片 facts/YYYY-MM.md"
  else
    add "OK" "facts 条目数正常" "${total} 条" ""
  fi

  TAGTMP="$TMP/.tag.$$"
  grep -o '^- \[[0-9-]*\] \[[a-z]*\]' "$FACTS" 2>/dev/null \
    | sed 's/.*\[\([a-z]*\)\]/\1/' | sort | uniq -c | sort -rn > "$TAGTMP" 2>/dev/null
  [ -f "$TAGTMP" ] || : > "$TAGTMP"

  while read -r n tag; do
    [ -n "${tag:-}" ] || continue
    [ "${n:-0}" -ge 3 ] 2>/dev/null || continue
    sample=$(grep -- "\[$tag\]" "$FACTS" 2>/dev/null | head -3 | sed 's/^- \[[0-9-]*\] //')
    add "ACTION" "标签 [$tag] 可晋升" "${n} 条同标签" "合并为 MEMORY.md 一行: $(printf '%s' "$sample" | tr '\n' ';')"
  done < "$TAGTMP"
  rm -f "$TAGTMP"
else
  add "ERROR" "facts/facts.md 缺失" "" "运行 mem-init.sh"
fi

# 3. 错误晋升
ERR="$ROOT/notes/errors.md"
if [ -f "$ERR" ]; then
  ec=$(count_matches '^## ' "$ERR")
  if [ "$ec" -ge 3 ]; then
    add "ACTION" "错误记录可提炼" "${ec} 条" "同根因 >=2 次晋升为 MEMORY.md 规则"
  else
    add "OK" "错误记录正常" "${ec} 条" ""
  fi
fi

# 4. 陈旧归档
ND="$ROOT/notes"
if [ -d "$ND" ]; then
  ncount=0
  for f in "$ND"/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    ncount=$((ncount + 1))
    [ "$base" = "errors.md" ] && continue

    c=$(count_chars "$f")
    st=$(fm_get "$f" status)

    [ "$c" -gt "$BUDGET_NOTE" ] && add "WARN" "notes/$base 过长" "${c} 字符 / ${BUDGET_NOTE}" "压缩「现状」与「变更记录」"

    case "$st" in
      stale)
        if older_than "$f" "$STALE_DAYS"; then
          add "ACTION" "notes/$base 待归档" "stale 超 ${STALE_DAYS} 天" "mem-monthly.sh 会自动归档"
        else
          add "WARN" "notes/$base 已标 stale" "等待确认" "确认后改 active 或 done"
        fi
        ;;
      done)
        older_than "$f" "$DONE_DAYS" && add "ACTION" "notes/$base 可归档" "done 超 ${DONE_DAYS} 天" "并入 archive/<月>.md"
        ;;
      "")
        add "WARN" "notes/$base 缺 status" "无 frontmatter" "补 status: active|paused|done|stale"
        ;;
    esac
  done

  if [ "$ncount" -gt "$WARN_NOTES" ]; then
    add "WARN" "notes 文件过多" "${ncount} 个 / 建议 ${WARN_NOTES}" "归档 done 项目或分子目录"
  else
    add "OK" "notes 数量正常" "${ncount} 个" ""
  fi
fi

# 5. 噪声
if [ -f "$FACTS" ]; then
  dup=$(grep '^- \[' "$FACTS" 2>/dev/null | sort | uniq -d | wc -l | tr -d ' \n')
  [ "${dup:-0}" -gt 0 ] 2>/dev/null && add "WARN" "facts 有重复行" "${dup} 组" "删除多余副本"

  empty=$(count_matches '^- \[[0-9-]*\] \[[a-z]*\][[:space:]]*$' "$FACTS")
  [ "${empty:-0}" -gt 0 ] 2>/dev/null && add "WARN" "facts 有空条目" "${empty} 条" "删除或补全"

  longl=$(awk '/^- \[/ && length($0) > 300 {n++} END {print n+0}' "$FACTS" 2>/dev/null)
  [ "${longl:-0}" -gt 0 ] 2>/dev/null && add "WARN" "facts 有超长条目" "${longl} 条 >300 字符" "拆分或移入 notes"
fi

# 6. 结构一致性
if [ -f "$ROOT/INDEX.md" ] && [ -d "$ND" ]; then
  for f in "$ND"/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    [ "$base" = "errors.md" ] && continue
    grep -q "notes/$base" "$ROOT/INDEX.md" 2>/dev/null || \
      add "WARN" "notes/$base 未登记" "INDEX.md 无对应行" "补一行或删除孤立文件"
  done

  REFTMP="$TMP/.ref.$$"
  grep -o 'notes/[^`|]*\.md' "$ROOT/INDEX.md" 2>/dev/null | sort -u > "$REFTMP" 2>/dev/null
  [ -f "$REFTMP" ] || : > "$REFTMP"
  while read -r ref; do
    [ -n "${ref:-}" ] || continue
    [ -f "$ROOT/$ref" ] || add "ERROR" "INDEX 指向不存在" "$ref" "删除该行或补建文件"
  done < "$REFTMP"
  rm -f "$REFTMP"
fi

# 输出
if [ "$MODE" = "json" ]; then
  esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
  printf '{"root":"%s","date":"%s","items":[' "$(esc "$ROOT")" "$DATE"
  first=1
  while IFS='|' read -r lvl title detail action; do
    [ -n "${lvl:-}" ] || continue
    [ "$first" -eq 1 ] || printf ','
    first=0
    printf '{"level":"%s","title":"%s","detail":"%s","action":"%s"}' \
      "$(esc "$lvl")" "$(esc "$title")" "$(esc "$detail")" "$(esc "$action")"
  done < "$WORK"
  printf ']}\n'
  exit 0
fi

say "============================================"
say " 记忆库体检  $DATE"
say " 根目录: $ROOT"
say "============================================"
say ""

nok=0; nwarn=0; nerr=0; nact=0
while IFS='|' read -r lvl title detail action; do
  case "${lvl:-}" in
    OK) nok=$((nok+1)) ;;
    WARN) nwarn=$((nwarn+1)) ;;
    ERROR) nerr=$((nerr+1)) ;;
    ACTION) nact=$((nact+1)) ;;
  esac
done < "$WORK"

say "[ 问题 ]"
found=0
while IFS='|' read -r lvl title detail action; do
  [ "${lvl:-}" = "ERROR" ] || continue
  found=1
  say "  x $title"
  [ -n "$detail" ] && say "      $detail"
  [ -n "$action" ] && say "      -> $action"
done < "$WORK"
[ "$found" -eq 0 ] && say "  无"
say ""

say "[ 待办 ]"
found=0
while IFS='|' read -r lvl title detail action; do
  [ "${lvl:-}" = "ACTION" ] || continue
  found=1
  say "  * $title"
  [ -n "$detail" ] && say "      $detail"
  [ -n "$action" ] && say "      -> $action"
done < "$WORK"
[ "$found" -eq 0 ] && say "  无"
say ""

say "[ 警告 ]"
found=0
while IFS='|' read -r lvl title detail action; do
  [ "${lvl:-}" = "WARN" ] || continue
  found=1
  say "  ! $title"
  [ -n "$detail" ] && say "      $detail"
  [ -n "$action" ] && say "      -> $action"
done < "$WORK"
[ "$found" -eq 0 ] && say "  无"
say ""

if [ "$VERBOSE" -eq 1 ]; then
  say "[ 正常项 ]"
  while IFS='|' read -r lvl title detail action; do
    [ "${lvl:-}" = "OK" ] || continue
    say "  + $title  $detail"
  done < "$WORK"
  say ""
fi

say "--------------------------------------------"
printf ' 正常 %d | 警告 %d | 错误 %d | 待办 %d\n' "$nok" "$nwarn" "$nerr" "$nact"
say "--------------------------------------------"
exit 0
