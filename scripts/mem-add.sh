#!/bin/sh
# mem-add.sh — 写入一条记忆
#
#   mem-add.sh -f "key = value"                 原子事实（默认）
#   mem-add.sh -t pref -f "key = value"         带标签
#   mem-add.sh -T "主题名" -s active            新建/更新主题笔记
#   mem-add.sh -T "主题名" -n custom-slug       手动指定文件名
#   mem-add.sh -m "规则文本"                     追加到 MEMORY.md 规则区
#   mem-add.sh -e "错误症状"                     追加错误记录
set -u

_SELF_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
export SKILL_ROOT_HINT=$(cd "$_SELF_DIR/.." 2>/dev/null && pwd)
. "$_SELF_DIR/_common.sh"

SKILL=$(skill_dir)
ROOT=$(resolve_memory_root)
DATE=$(today)

TAG="misc"
MODE="fact"
TOPIC=""
STATUS="active"
SLUG_OVERRIDE=""
PAYLOAD=""

while [ $# -gt 0 ]; do
  case "$1" in
    -t) TAG="$2"; shift 2 ;;
    -f) MODE="fact"; PAYLOAD="$2"; shift 2 ;;
    -T) MODE="topic"; TOPIC="$2"; shift 2 ;;
    -s) STATUS="$2"; shift 2 ;;
    -n) SLUG_OVERRIDE="$2"; shift 2 ;;
    -e) MODE="error"; PAYLOAD="$2"; shift 2 ;;
    -m) MODE="rule"; PAYLOAD="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) PAYLOAD="$1"; shift ;;
  esac
done

[ -d "$ROOT" ] || { say "记忆库不存在: $ROOT"; say "运行: sh $SKILL/scripts/mem-init.sh"; exit 1; }

slugify() {
  _s=$(printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-')
  _s=${_s#-}; _s=${_s%-}
  _h=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
  if [ -z "$_s" ]; then
    _s="topic-$_h"
  elif [ "${#_s}" -le 2 ]; then
    _s="$_s-$_h"
  fi
  printf '%s' "$_s"
}

bump_revision() {
  _f="$ROOT/MEMORY.md"
  [ -f "$_f" ] || return 0
  _cur=$(sed -n 's/^revision:[[:space:]]*//p' "$_f" | head -1)
  case "$_cur" in ''|*[!0-9]*) _cur=0 ;; esac
  sed -i.bak "s/^revision:.*/revision: $((_cur + 1))/" "$_f" 2>/dev/null || \
    sed -i '' "s/^revision:.*/revision: $((_cur + 1))/" "$_f" 2>/dev/null || :
  sed -i.bak "s/^updated:.*/updated: $DATE/" "$_f" 2>/dev/null || \
    sed -i '' "s/^updated:.*/updated: $DATE/" "$_f" 2>/dev/null || :
  rm -f "$_f.bak" 2>/dev/null || :
}

# 在 INDEX.md「## 主题笔记」区末尾插入一行
index_add_row() {
  _f="$ROOT/INDEX.md"
  [ -f "$_f" ] || return 0
  _line="$1"
  grep -qF -- "$_line" "$_f" 2>/dev/null && return 0

  _tmp="$_f.tmpnew"
  awk -v line="$_line" '
    BEGIN { insec=0; done=0 }
    {
      if ($0 ~ /^## 主题笔记[[:space:]]*$/) { insec=1; print; next }
      if (insec==1 && $0 ~ /^## /) {
        if (done==0) { print line; print ""; done=1 }
        insec=0; print; next
      }
      if (insec==1 && $0 ~ /^- （尚无/) { next }
      if (insec==1 && $0 == "") { next }
      print
    }
    END {
      if (insec==1 && done==0) { print line; print "" }
    }
  ' "$_f" > "$_tmp" 2>/dev/null
  if [ -s "$_tmp" ]; then
    mv "$_tmp" "$_f"
  else
    rm -f "$_tmp"
  fi
}

case "$MODE" in
  fact)
    [ -n "$PAYLOAD" ] || { say "缺少内容"; exit 1; }
    printf -- '- [%s] [%s] %s\n' "$DATE" "$TAG" "$PAYLOAD" >> "$ROOT/facts/facts.md"
    say "[fact] facts/facts.md <- $PAYLOAD"
    ;;
  rule)
    [ -n "$PAYLOAD" ] || { say "缺少内容"; exit 1; }
    printf -- '- %s\n' "$PAYLOAD" >> "$ROOT/MEMORY.md"
    bump_revision
    say "[rule] MEMORY.md <- $PAYLOAD"
    ;;
  topic)
    [ -n "$TOPIC" ] || { say "缺少 -T 主题名"; exit 1; }
    if [ -n "$SLUG_OVERRIDE" ]; then SLUG="$SLUG_OVERRIDE"; else SLUG=$(slugify "$TOPIC"); fi
    [ -n "$SLUG" ] || SLUG="topic-$(date +%s)"
    F="$ROOT/notes/$SLUG.md"
    if [ ! -f "$F" ]; then
      if [ -f "$SKILL/assets/notes.template.md" ]; then
        sed -e "s|{{TOPIC}}|$SLUG|g" -e "s|{{TITLE}}|$TOPIC|g" -e "s|{{DATE}}|$DATE|g" \
            -e "s|^status:.*|status: $STATUS|" "$SKILL/assets/notes.template.md" > "$F" 2>/dev/null || :
      fi
      if [ ! -f "$F" ]; then
        printf -- '---\ntopic: %s\nstatus: %s\ncreated: %s\nupdated: %s\ntags: []\n---\n\n# %s\n\n## 目标\n\n## 现状\n\n## 关键结论\n\n## 下一步\n\n## 变更记录\n- %s: 创建\n' \
          "$SLUG" "$STATUS" "$DATE" "$DATE" "$TOPIC" "$DATE" > "$F"
      fi
      index_add_row "- \`notes/$SLUG.md\` — $TOPIC"
      say "[topic] notes/$SLUG.md (status=$STATUS)"
    else
      sed -i.bak "s/^status:.*/status: $STATUS/" "$F" 2>/dev/null || sed -i '' "s/^status:.*/status: $STATUS/" "$F" 2>/dev/null || :
      sed -i.bak "s/^updated:.*/updated: $DATE/" "$F" 2>/dev/null || sed -i '' "s/^updated:.*/updated: $DATE/" "$F" 2>/dev/null || :
      rm -f "$F.bak" 2>/dev/null || :
      printf -- '- %s: status -> %s\n' "$DATE" "$STATUS" >> "$F"
      say "[topic] notes/$SLUG.md (status=$STATUS)"
    fi
    ;;
  error)
    [ -n "$PAYLOAD" ] || { say "缺少内容"; exit 1; }
    {
      printf '\n## %s | %s\n' "$DATE" "$PAYLOAD"
      printf -- '- 场景:\n- 触发:\n- 报错:\n- 根因:\n- 修正规则:\n'
    } >> "$ROOT/notes/errors.md"
    say "[error] notes/errors.md <- $PAYLOAD"
    ;;
esac
exit 0
