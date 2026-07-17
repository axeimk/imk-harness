#!/usr/bin/env bats
# 管理ブロック方式: ブロック外のユーザーテキスト保持・既存ファイルへの追記・旧 symlink からの移行
# テスト名は ASCII にする（bats + macOS bash 3.2 は多バイトのテスト名を解決できない）

load helpers

@test "existing CLAUDE.md gets the block appended and keeps its content" {
  mkdir -p "$HOME/.claude"
  echo "ユーザー自身の指示" > "$HOME/.claude/CLAUDE.md"

  install_tools claude

  head -n 1 "$HOME/.claude/CLAUDE.md" | grep -qF "ユーザー自身の指示"
  assert_block_matches "$REPO/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
}

@test "text outside the block survives a block update" {
  install_tools claude
  echo "ブロック外のメモ" >> "$HOME/.claude/CLAUDE.md"
  # ブロックの中身を書き換えて「更新が必要な状態」を作る
  tampered="$(mktemp)"
  echo "tampered" > "$tampered"
  replace_block "$tampered" "$HOME/.claude/CLAUDE.md"
  rm "$tampered"

  install_tools claude

  assert_block_matches "$REPO/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  grep -qF "ブロック外のメモ" "$HOME/.claude/CLAUDE.md"
}

@test "legacy symlink migrates to a real file based on its backup" {
  mkdir -p "$HOME/.claude"
  ln -s "$REPO/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  echo "退避されていた元の内容" > "$HOME/.claude/CLAUDE.md.bak.20200101000000"

  install_tools claude

  [ -f "$HOME/.claude/CLAUDE.md" ]
  [ ! -L "$HOME/.claude/CLAUDE.md" ]
  grep -qF "退避されていた元の内容" "$HOME/.claude/CLAUDE.md"
  assert_block_matches "$REPO/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  [ ! -e "$HOME/.claude/CLAUDE.md.bak.20200101000000" ]
}
