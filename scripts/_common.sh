#!/bin/sh
# _common.sh — 共享工具层：路径解析 + 跨平台兼容 + 计数
#
# 设计目标：零硬编码。任何平台、任何目录结构都能跑。
# 依赖：仅 POSIX sh + 基础命令
#
# 调用方约定（每个脚本开头必须这样做）：
#   _SELF_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
#   export SKILL_ROOT_HINT=$(cd "$_SELF_DIR/.." 2>/dev/null && pwd)
#   . "$_SELF_DIR/_common.sh"

# ---------- skill 根目录 ----------
skill_dir() {
  if [ -n "${SKILL_ROOT_HINT:-}" ] && [ -d "$SKILL_ROOT_HINT" ]; then
    printf '%s' "$SKILL_ROOT_HINT"
  fi
}

# ---------- 记忆库路径解析 ----------
# 优先级: $MEMORY_ROOT > 向上找 memory/.ai-memory > $HOME/.ai-memory > ./memory

is_memory_root() {
  [ -d "$1" ] || return 1
  [ -f "$1/MEMORY.md" ] || return 1
  [ -f "$1/INDEX.md" ] || return 1
  return 0
}

resolve_memory_root() {
  if [ -n "${MEMORY_ROOT:-}" ]; then
    printf '%s' "$MEMORY_ROOT"
    return 0
  fi

  _d=$(pwd)
  _i=0
  while [ "$_i" -lt 6 ]; do
    if is_memory_root "$_d/memory"; then
      printf '%s' "$_d/memory"; return 0
    fi
    if is_memory_root "$_d/.ai-memory"; then
      printf '%s' "$_d/.ai-memory"; return 0
    fi
    _p=$(dirname "$_d")
    [ "$_p" = "$_d" ] && break
    _d="$_p"
    _i=$((_i + 1))
  done

  if [ -n "${HOME:-}" ] && [ "$HOME" != "/" ] && is_memory_root "$HOME/.ai-memory"; then
    printf '%s' "$HOME/.ai-memory"; return 0
  fi

  printf '%s' "$(pwd)/memory"
}

# ---------- 临时目录（不依赖 /tmp） ----------
temp_dir() {
  _r="$1"
  _t="${TMPDIR:-}"
  if [ -n "$_t" ] && [ -d "$_t" ] && [ -w "$_t" ]; then
    printf '%s' "$_t"; return 0
  fi
  if [ -d "$_r" ] && [ -w "$_r" ]; then
    mkdir -p "$_r/.tmp" 2>/dev/null && printf '%s' "$_r/.tmp" && return 0
  fi
  printf '%s' "${HOME:-.}"
}

# ---------- 计数（跨平台安全） ----------
# BusyBox 下 grep -c 无匹配置 0 且退出码 1；某些实现输出带空格

count_matches() {
  _n=$(grep -c -- "$1" "$2" 2>/dev/null || :)
  [ -z "$_n" ] && _n=0
  printf '%s' "$_n" | head -1 | tr -d ' \n'
}

count_lines() {
  _n=$(wc -l < "$1" 2>/dev/null || :)
  [ -z "$_n" ] && _n=0
  printf '%s' "$_n" | tr -d ' \n'
}

count_chars() {
  _n=$(wc -m < "$1" 2>/dev/null || :)
  [ -z "$_n" ] && _n=0
  printf '%s' "$_n" | tr -d ' \n'
}

# ---------- 文件遍历（替代 grep --include） ----------
list_md() {
  find "$1" -type f -name '*.md' 2>/dev/null | sort
}

# ---------- frontmatter ----------
fm_get() {
  sed -n "s/^$2:[[:space:]]*//p" "$1" 2>/dev/null | head -1
}

# ---------- 日期 ----------
today() {
  date +%F 2>/dev/null || date +%Y-%m-%d
}

this_month() {
  date +%Y-%m 2>/dev/null || date +%Y-%m
}

# 文件是否早于 N 天
older_than() {
  [ -n "$(find "$1" -mtime +"$2" 2>/dev/null)" ] 2>/dev/null
}

# ---------- 输出 ----------
# 关键：始终返回 0，避免 stdout 被重定向到 /dev/null 时触发 set -e 退出
say() {
  printf '%s\n' "$*" 2>/dev/null || :
  return 0
}
