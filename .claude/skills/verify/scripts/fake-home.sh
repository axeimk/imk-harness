#!/usr/bin/env bash
# 動作確認用ラッパー: 引数のコマンドを fake HOME で実行する（実 $HOME に触れない）。
# HOME の差し替えをスクリプト側で行うため、HOME="$H" の付け忘れで実ホームに
# 展開してしまう事故が構造的に起きない。
#
# 使い方（リポジトリルートで実行。パスは fake HOME を破棄するまで再利用される）:
#   .claude/skills/verify/scripts/fake-home.sh ./install.sh --tools claude --yes
#   .claude/skills/verify/scripts/fake-home.sh --path    # fake HOME のパスを表示
#   .claude/skills/verify/scripts/fake-home.sh --reset   # fake HOME を破棄
set -euo pipefail
cd "$(dirname "$0")/../../../.."  # .claude/skills/verify/scripts → リポジトリルート

state=".fake-home"  # fake HOME のパスの記録先（gitignore 済み）

if [ "${1:-}" = "--reset" ]; then
  if [ -f "$state" ]; then
    dir="$(cat "$state")"
    case "$dir" in
      "${TMPDIR:-/tmp}"*) rm -rf "$dir" ;;  # 一時領域を指しているときだけ消す
    esac
    rm -f "$state"
  fi
  echo "fake HOME を破棄しました"
  exit 0
fi

dir=""
if [ -f "$state" ]; then
  dir="$(cat "$state")"
fi
if [ -z "$dir" ] || [ ! -d "$dir" ]; then
  dir="$(mktemp -d)"
  echo "$dir" > "$state"
fi
if [ "$dir" = "${HOME}" ] || [ "$dir" = "/" ]; then
  echo "ERROR: fake HOME のパスが不正です: ${dir}" >&2
  exit 1
fi

case "${1:-}" in
  --path)
    echo "$dir"
    exit 0
    ;;
  "")
    echo "使い方: $0 <コマンド...> | --path | --reset" >&2
    exit 2
    ;;
esac

HOME="$dir" "$@"
