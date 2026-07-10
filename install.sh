#!/usr/bin/env bash
# imk-harness をホームディレクトリへ展開する。
# - 生成物・スキルは symlink（リポジトリ側の編集が即反映される）
# - 既存の実ファイルは .bak.<timestamp> に退避
# - settings.json / config.toml は既存があれば触らない（手動マージ）
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
TS="$(date +%Y%m%d%H%M%S)"

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    mv "$dst" "$dst.bak.$TS"
    echo "backup: $dst -> $dst.bak.$TS"
  fi
  ln -s "$src" "$dst"
  echo "link:   $dst -> $src"
}

copy_if_absent() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ]; then
    echo "skip:   $dst は既存のため変更しません。$src の内容を手動でマージしてください。"
  else
    cp "$src" "$dst"
    echo "copy:   $dst"
  fi
}

# 1. 原本から生成
"$REPO/build.sh"

# 2. Claude Code
link "$REPO/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
copy_if_absent "$REPO/claude/settings.json" "$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude/skills"
for d in "$REPO"/claude/skills/*/; do
  d="${d%/}"
  link "$d" "$HOME/.claude/skills/$(basename "$d")"
done

# 3. Codex
link "$REPO/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
copy_if_absent "$REPO/codex/config.toml" "$HOME/.codex/config.toml"

echo "done."
