#!/usr/bin/env bash
# Claude Code / Codex / Cursor のカスタムサブエージェント定義を機械検査する。
# 使い方: validate-agent.sh <claude-code|codex|cursor> <definition-file>
set -uo pipefail

if [ $# -ne 2 ] || [ ! -f "${2:-}" ]; then
  echo "使い方: $(basename "$0") <claude-code|codex|cursor> <definition-file>" >&2
  exit 2
fi

tool="$1"
file="$2"
base="$(basename "$file")"
errors=0

err() {
  echo "ERROR: ${base}: $1"
  errors=$((errors + 1))
}

warn() {
  echo "WARN:  ${base}: $1"
}

frontmatter_of() {
  LC_ALL=C awk '
    NR == 1 {
      if ($0 !~ /^---[ \t]*$/) exit
      next
    }
    /^---[ \t]*$/ { exit }
    { print }
  ' "$1"
}

yaml_field() {
  printf '%s\n' "$2" | LC_ALL=C awk -v k="$1" '
    $0 ~ "^[ \t]*" k "[ \t]*:" {
      sub("^[ \t]*" k "[ \t]*:[ \t]*", "")
      print
      exit
    }
  '
}

body_of_markdown() {
  LC_ALL=C awk '
    /^---[ \t]*$/ {
      delimiters++
      next
    }
    delimiters >= 2 { print }
  ' "$1"
}

unquote() {
  printf '%s' "$1" | LC_ALL=C awk '
    {
      if (($0 ~ /^".*"$/) || ($0 ~ /^'\''.*'\''$/)) {
        print substr($0, 2, length($0) - 2)
      } else {
        print
      }
    }
  '
}

toml_field() {
  LC_ALL=C awk -v k="$1" '
    $0 ~ "^[ \t]*" k "[ \t]*=" {
      sub("^[ \t]*" k "[ \t]*=[ \t]*", "")
      print
      exit
    }
  ' "$2"
}

validate_name() {
  local name="$1"
  printf '%s' "$name" | LC_ALL=C grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' \
    || err "name は英小文字・数字・ハイフンのみ（先頭・末尾・連続ハイフン不可）"
}

validate_boolean_yaml() {
  local key="$1" value="$2"
  if [ -n "$value" ] && [ "$value" != "true" ] && [ "$value" != "false" ]; then
    err "${key} は true または false で指定してください"
  fi
}

validate_markdown() {
  local target="$1" fm name desc body filename_name value

  case "$file" in
    *.md) ;;
    *) err "${target} の定義は .md ファイルにしてください" ;;
  esac

  fm="$(frontmatter_of "$file")"
  if [ -z "$fm" ]; then
    err "YAML frontmatter がありません（1 行目を --- にする）"
    return
  fi

  if [ "$(LC_ALL=C grep -c '^---[ \t]*$' "$file")" -lt 2 ]; then
    err "YAML frontmatter の終了マーカー --- がありません"
  fi

  name="$(unquote "$(yaml_field name "$fm")")"
  desc="$(unquote "$(yaml_field description "$fm")")"
  body="$(body_of_markdown "$file" | LC_ALL=C tr -d '[:space:]')"

  if [ "$target" = "claude-code" ]; then
    [ -n "$name" ] || err "name がありません"
    [ -n "$desc" ] || err "description がありません"
  else
    [ -n "$name" ] || warn "name は Cursor では省略可能ですが、委譲と複数ツールでの一貫性のため明示を推奨します"
    [ -n "$desc" ] || warn "description は Cursor では省略可能ですが、自動委譲のため明示を推奨します"
  fi

  if [ -n "$name" ]; then
    validate_name "$name"
    filename_name="${base%.md}"
    [ "$filename_name" = "$name" ] \
      || warn "ファイル名（${filename_name}）と name（${name}）を揃えると管理しやすくなります"
  fi
  [ -n "$body" ] || err "frontmatter 後の指示本文がありません"

  if [ "$target" = "claude-code" ]; then
    LC_ALL=C grep -Eq '^[[:space:]]*readonly[[:space:]]*:' <<< "$fm" \
      && err "readonly は Cursor のフィールドです。Claude Code では tools / disallowedTools / permissionMode を使ってください"
    LC_ALL=C grep -Eq '^[[:space:]]*is_background[[:space:]]*:' <<< "$fm" \
      && err "is_background は Cursor のフィールドです。Claude Code では background を使ってください"
    value="$(unquote "$(yaml_field background "$fm")")"
    validate_boolean_yaml background "$value"
    value="$(unquote "$(yaml_field permissionMode "$fm")")"
    case "$value" in
      ""|default|acceptEdits|auto|dontAsk|bypassPermissions|plan|manual) ;;
      *) err "未対応の permissionMode です: ${value}" ;;
    esac
    value="$(unquote "$(yaml_field isolation "$fm")")"
    case "$value" in
      ""|worktree) ;;
      *) err "isolation は worktree のみ指定できます" ;;
    esac
  else
    LC_ALL=C grep -Eq '^[[:space:]]*background[[:space:]]*:' <<< "$fm" \
      && err "background は Claude Code のフィールドです。Cursor では is_background を使ってください"
    LC_ALL=C grep -Eq '^[[:space:]]*permissionMode[[:space:]]*:' <<< "$fm" \
      && err "permissionMode は Claude Code のフィールドです。Cursor では readonly と実行モードを使ってください"
    value="$(unquote "$(yaml_field readonly "$fm")")"
    validate_boolean_yaml readonly "$value"
    value="$(unquote "$(yaml_field is_background "$fm")")"
    validate_boolean_yaml is_background "$value"
  fi
}

validate_codex() {
  local name desc instructions filename_name

  case "$file" in
    *.toml) ;;
    *) err "Codex の定義は .toml ファイルにしてください" ;;
  esac

  if command -v python3 >/dev/null 2>&1 && python3 -c 'import tomllib' >/dev/null 2>&1; then
    python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$file" \
      || err "TOML の構文が不正です"
  else
    warn "Python の tomllib が無いため TOML 全体の構文検査を省略します"
  fi

  name="$(unquote "$(toml_field name "$file")")"
  desc="$(unquote "$(toml_field description "$file")")"
  instructions="$(toml_field developer_instructions "$file")"

  [ -n "$name" ] || err "name がありません"
  [ -n "$desc" ] || err "description がありません"
  case "$instructions" in
    ""|'""'|"''"|'""""""'|"''''''") err "developer_instructions がありません、または空です" ;;
  esac

  if [ -n "$name" ]; then
    filename_name="${base%.toml}"
    [ "$filename_name" = "$name" ] \
      || warn "ファイル名（${filename_name}）と name（${name}）を揃えると管理しやすくなります"
  fi

  LC_ALL=C grep -Eq '^[[:space:]]*readonly[[:space:]]*=' "$file" \
    && err "readonly は Cursor のフィールドです。Codex では sandbox_mode = \"read-only\" を使ってください"
  LC_ALL=C grep -Eq '^[[:space:]]*(background|is_background)[[:space:]]*=' "$file" \
    && err "background / is_background は Codex カスタムエージェントの共通フィールドではありません"
  LC_ALL=C grep -Eq '^---[[:space:]]*$' "$file" \
    && err "Codex の定義は YAML frontmatter 付き Markdown ではなく TOML です"
}

case "$tool" in
  claude-code) validate_markdown claude-code ;;
  codex) validate_codex ;;
  cursor) validate_markdown cursor ;;
  *)
    echo "ERROR: 未対応のツールです: ${tool}（claude-code / codex / cursor）" >&2
    exit 2
    ;;
esac

if [ "$errors" -gt 0 ]; then
  echo "NG: ${base}: ${errors} 件のエラー"
  exit 1
fi

echo "OK: ${base}"
