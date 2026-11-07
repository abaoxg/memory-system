#!/bin/sh
# mem-search.sh — 记忆库检索（默认跳过 archive）
#
#   mem-search.sh "关键词"
#   mem-search.sh -t pref              按标签
#   mem-search.sh -r 7                 近 N 天修改的文件
#   mem-search.sh -d notes "frida"     限定子目录
#   mem-search.sh --brief "frida"      只输出 文件:命中数
#   mem-search.sh --files              列出所有笔记文件
#   mem-search.sh -a "关键词"          包含 archive 一起检索
set -u

_SELF_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
export SKILL_ROOT_HINT=$(cd "$_SELF_DIR/.." 2>/dev/null && pwd)
. "$_SELF_DIR/_common.sh"

ROOT=$(resolve_memory_root)
DIR=""
BRIEF=0
LISTFILES=0
TAG=""
RECENT=""
QUERY=""
INCLUDE_ARCHIVE=0

while [ $# -gt 0 ]; do
  case "$1" in
    -t) TAG="$2"; shift 2 ;;
    -r) RECENT="$2"; shift 2 ;;
    -d) DIR="$2"; shift 2 ;;
    --brief) BRIEF=1; shift ;;
    --files) LISTFILES=1; shift ;;
    -a|--all) INCLUDE_ARCHIVE=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) QUERY="$1"; shift ;;
  esac
done

[ -d "$ROOT" ] || { say "记忆库不存在: $ROOT"; exit 1; }
ROOT=$(cd "$ROOT" 2>/dev/null && pwd)
[ -n "$DIR" ] && [ -d "$ROOT/$DIR" ] && ROOT="$ROOT/$DIR"

TMP=$(temp_dir "$ROOT")
LIST="$TMP/.ml.$$"
OUT="$TMP/.mo.$$"
HIT="$TMP/.mh.$$"
trap 'rm -f "$LIST" "$OUT" "$HIT"' EXIT INT TERM

build_list() {
  list_md "$ROOT" > "$LIST.raw"
  : > "$LIST"
  while IFS= read -r f; do
    case "$f" in
      "$ROOT"/archive/*) [ "$INCLUDE_ARCHIVE" -eq 1 ] && printf '%s\n' "$f" >> "$LIST" ;;
      */.tmp/*) : ;;
      */.git/*) : ;;
      *) printf '%s\n' "$f" >> "$LIST" ;;
    esac
  done < "$LIST.raw"
  rm -f "$LIST.raw"
}

mt() {
  date -r "$1" +%F 2>/dev/null \
    || date -d "@$(stat -c %Y "$1" 2>/dev/null || echo 0)" +%F 2>/dev/null \
    || echo "?"
}

build_list

if [ "$LISTFILES" -eq 1 ]; then
  while IFS= read -r f; do
    printf '%s  (%s)\n' "${f#$ROOT/}" "$(mt "$f")"
  done < "$LIST"
  exit 0
fi

if [ -n "$RECENT" ]; then
  say "近 $RECENT 天变更:"
  while IFS= read -r f; do
    if [ -n "$(find "$f" -mtime -"$RECENT" 2>/dev/null)" ]; then
      printf '  %s  (%s)\n' "${f#$ROOT/}" "$(mt "$f")"
    fi
  done < "$LIST"
  exit 0
fi

if [ -n "$TAG" ]; then
  say "标签 [$TAG]:"
  : > "$OUT"
  while IFS= read -r f; do
    grep -n -- "\[$TAG\]" "$f" 2>/dev/null | while IFS= read -r l; do
      printf '%s:%s\n' "${f#$ROOT/}" "$l"
    done >> "$OUT"
    grep -n -- "tags:.*\b$TAG\b" "$f" 2>/dev/null | while IFS= read -r l; do
      printf '%s:%s\n' "${f#$ROOT/}" "$l"
    done >> "$OUT"
  done < "$LIST"
  if [ -s "$OUT" ]; then
    head -50 "$OUT" | sed 's/^/  /'
  else
    say "  (无)"
  fi
  exit 0
fi

[ -n "$QUERY" ] || { say "需要关键词，或 -t/-r/--files"; exit 1; }

if [ "$BRIEF" -eq 1 ]; then
  : > "$OUT"
  while IFS= read -r f; do
    n=$(count_matches "$QUERY" "$f")
    [ "${n:-0}" -gt 0 ] 2>/dev/null && printf '%s:%s\n' "${f#$ROOT/}" "$n" >> "$OUT"
  done < "$LIST"
  if [ -s "$OUT" ]; then cat "$OUT"; else say "(无命中)"; fi
  exit 0
fi

say "检索: $QUERY"
[ "$INCLUDE_ARCHIVE" -eq 0 ] && say "（已跳过 archive/，加 -a 可包含）"
say "----------------------------------------"
: > "$OUT"
while IFS= read -r f; do
  grep -q -i -- "$QUERY" "$f" 2>/dev/null || continue
  grep -n -i -- "$QUERY" "$f" 2>/dev/null > "$HIT" || :
  while IFS= read -r l; do
    printf '%s:%s\n' "${f#$ROOT/}" "$(printf '%s' "$l" | cut -c1-200)"
  done < "$HIT" >> "$OUT"
done < "$LIST"

if [ -s "$OUT" ]; then
  cat "$OUT"
  say ""
  say "命中行数: $(count_lines "$OUT")"
else
  say "(无命中)"
fi
exit 0
