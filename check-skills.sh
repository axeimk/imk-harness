#!/usr/bin/env bash
# shared/skills/ の各スキルが共有規約（ADR-0009: graceful degradation）を満たすか検査する。
# スキルの追加・変更時に実行する。エラーがあれば非 0 で終了する。
set -uo pipefail
cd "$(dirname "$0")"

errors=0
err()  { echo "ERROR: $1"; errors=$((errors + 1)); }
warn() { echo "WARN:  $1"; }

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

for dir in shared/skills/*/; do
  dir="${dir%/}"
  skill="$(basename "$dir")"
  md="$dir/SKILL.md"

  if [ ! -f "$md" ]; then
    err "${skill}: SKILL.md がありません"
    continue
  fi

  fm="$(frontmatter_of "$md")"
  [ -n "$fm" ] || err "${skill}: フロントマターがありません（1 行目が --- ではない）"

  # 規約 1: name はディレクトリ名と一致し、標準の命名規則に従う
  name="$(field name "$fm")"
  if [ -z "$name" ]; then
    err "${skill}: name がありません"
  else
    [ "$name" = "$skill" ] || err "${skill}: name（${name}）がディレクトリ名と一致しません"
    printf '%s' "$name" | LC_ALL=C grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' \
      || err "${skill}: name は英小文字・数字・ハイフンのみ（先頭・末尾・連続ハイフン不可）"
    [ "${#name}" -le 64 ] || err "${skill}: name が 64 文字を超えています"
  fi

  # 規約 1: description は必須・1024 文字以内（Codex では欠落がロードエラーになる）
  desc="$(field description "$fm")"
  if [ -z "$desc" ]; then
    err "${skill}: description がありません"
  elif [ "${#desc}" -gt 1024 ]; then
    err "${skill}: description が 1024 文字を超えています（${#desc} 文字）"
  fi

  # 規約 2: 本文の意味を変える Claude Code 専用機能は共有スキルでは使わない
  # （Codex / Cursor では展開されず、生テキストがモデルに渡って指示が壊れる）
  LC_ALL=C grep -nE '(^|[[:space:]])!`' "$md" \
    && err "${skill}: 動的コンテキスト注入 !\`cmd\` は使えません"
  LC_ALL=C grep -n '^```!' "$md" \
    && err "${skill}: 動的コンテキスト注入 \`\`\`! ブロックは使えません"
  LC_ALL=C grep -nF '$ARGUMENTS' "$md" \
    && err "${skill}: 引数展開 \$ARGUMENTS は使えません"
  LC_ALL=C grep -nF '${CLAUDE_' "$md" \
    && err "${skill}: \${CLAUDE_*} 置換は使えません"
  printf '%s\n' "$fm" | LC_ALL=C grep -q '^context:[[:space:]]*fork' \
    && warn "${skill}: context: fork は Claude Code 専用です（他ツールではインライン実行される。本文が単体で成立するか確認すること）"

  # 規約 4: 自動発火の禁止はフロントマターと agents/openai.yaml の両方に書く
  dmi_true=0
  [ "$(field disable-model-invocation "$fm")" = "true" ] && dmi_true=1
  aii_false=0
  oy="$dir/agents/openai.yaml"
  if [ -f "$oy" ]; then
    LC_ALL=C grep -Eq 'allow_implicit_invocation:[[:space:]]*false' "$oy" && aii_false=1
  fi
  if [ "$dmi_true" -ne "$aii_false" ]; then
    if [ "$dmi_true" -eq 1 ]; then
      err "${skill}: disable-model-invocation: true は Codex に伝わりません。agents/openai.yaml に policy.allow_implicit_invocation: false を併記してください"
    else
      err "${skill}: agents/openai.yaml の allow_implicit_invocation: false にはフロントマターの disable-model-invocation: true を併記してください"
    fi
  fi

  # 展開先で解決できないリポジトリ内部参照の混入を防ぐ（CLAUDE.md の方針）
  LC_ALL=C grep -rnE 'ADR-[0-9]{4}|docs/adr/' "$dir" \
    && err "${skill}: リポジトリ内部への参照（ADR 番号等）は展開先で解決できません"
done

if [ "$errors" -gt 0 ]; then
  echo "NG: ${errors} 件のエラー"
  exit 1
fi
echo "OK: すべてのスキルが共有規約を満たしています"
