#!/usr/bin/env bash
# スキルディレクトリ 1 つを検査する可搬スクリプト。
# 「どのツール（Claude Code / Codex / Cursor）で読まれても本文が成立する」
# 互換規約（references/conventions.md）を機械検査する。
# エラーがあれば非 0 で終了する。
#
# 使い方: validate-skill.sh <skill-directory>
set -uo pipefail

if [ $# -ne 1 ] || [ ! -d "${1:-}" ]; then
  echo "使い方: $(basename "$0") <skill-directory>" >&2
  exit 2
fi

dir="${1%/}"
skill="$(basename "$dir")"
md="$dir/SKILL.md"

errors=0
err()  { echo "ERROR: ${skill}: $1"; errors=$((errors + 1)); }
warn() { echo "WARN:  ${skill}: $1"; }

# SKILL.md 先頭のフロントマター（--- 間）だけを出力する
frontmatter_of() {
  LC_ALL=C awk 'NR==1 { if ($0 !~ /^---[ \t]*$/) exit; next }
                /^---[ \t]*$/ { exit } { print }' "$1"
}

# フロントマター文字列から単一行フィールドの値を取り出す（$1=キー, $2=フロントマター）
field() {
  printf '%s\n' "$2" | LC_ALL=C awk -v k="$1" \
    'index($0, k ": ") == 1 { sub(/^[^:]*: */, ""); print; exit }'
}

if [ ! -f "$md" ]; then
  err "SKILL.md がありません"
  exit 1
fi

fm="$(frontmatter_of "$md")"
[ -n "$fm" ] || err "フロントマターがありません（1 行目が --- ではない）"

# 共通コア: name はディレクトリ名と一致し、標準の命名規則に従う
name="$(field name "$fm")"
if [ -z "$name" ]; then
  err "name がありません"
else
  [ "$name" = "$skill" ] || err "name（${name}）がディレクトリ名と一致しません"
  printf '%s' "$name" | LC_ALL=C grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' \
    || err "name は英小文字・数字・ハイフンのみ（先頭・末尾・連続ハイフン不可）"
  [ "${#name}" -le 64 ] || err "name が 64 文字を超えています"
fi

# 共通コア: description は必須・1024 文字以内（Codex では欠落がロードエラーになる）
desc="$(field description "$fm")"
if [ -z "$desc" ]; then
  err "description がありません"
elif [ "${#desc}" -gt 1024 ]; then
  err "description が 1024 文字を超えています（${#desc} 文字）"
fi

# 禁止パターン: 本文の意味を変える Claude Code 専用機能
# （Codex / Cursor では展開されず、生テキストがモデルに渡って指示が壊れる）
LC_ALL=C grep -nE '(^|[[:space:]])!`' "$md" \
  && err "動的コンテキスト注入 !\`cmd\` は使えません"
LC_ALL=C grep -n '^```!' "$md" \
  && err "動的コンテキスト注入 \`\`\`! ブロックは使えません"
LC_ALL=C grep -nF '$ARGUMENTS' "$md" \
  && err "引数展開 \$ARGUMENTS は使えません"
LC_ALL=C grep -nF '${CLAUDE_' "$md" \
  && err "\${CLAUDE_*} 置換は使えません"
printf '%s\n' "$fm" | LC_ALL=C grep -q '^context:[[:space:]]*fork' \
  && warn "context: fork は Claude Code 専用です（他ツールではインライン実行される。本文が単体で成立するか確認すること）"

# 自動発火の禁止はフロントマターと agents/openai.yaml の両方に書く（唯一の二重管理点）
dmi_true=0
[ "$(field disable-model-invocation "$fm")" = "true" ] && dmi_true=1
aii_false=0
oy="$dir/agents/openai.yaml"
if [ -f "$oy" ]; then
  LC_ALL=C grep -Eq 'allow_implicit_invocation:[[:space:]]*false' "$oy" && aii_false=1
fi
if [ "$dmi_true" -ne "$aii_false" ]; then
  if [ "$dmi_true" -eq 1 ]; then
    err "disable-model-invocation: true は Codex に伝わりません。agents/openai.yaml に policy.allow_implicit_invocation: false を併記してください"
  else
    err "agents/openai.yaml の allow_implicit_invocation: false にはフロントマターの disable-model-invocation: true を併記してください"
  fi
fi

if [ "$errors" -gt 0 ]; then
  echo "NG: ${skill}: ${errors} 件のエラー"
  exit 1
fi
echo "OK: ${skill}"
