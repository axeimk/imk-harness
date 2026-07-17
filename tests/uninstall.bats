#!/usr/bin/env bats
# uninstall.sh: 残骸なしの撤去・ユーザーの持ち物の保持・バックアップ復元
# テスト名は ASCII にする（bats + macOS bash 3.2 は多バイトのテスト名を解決できない）

load helpers

@test "install then uninstall leaves no harness artifacts" {
  install_tools claude,codex
  uninstall_all

  # 残ってよいのはコピー配置した settings.json / config.toml と、
  # 空になった ~/.agents（rmdir で畳むのは skills ディレクトリまで）だけ
  [ "$(snapshot)" = "$(printf '%s\n' \
    "$HOME" \
    "$HOME/.agents" \
    "$HOME/.claude" \
    "$HOME/.claude/settings.json" \
    "$HOME/.codex" \
    "$HOME/.codex/config.toml")" ]
}

@test "skills the user placed themselves survive uninstall" {
  install_tools claude
  mkdir -p "$HOME/.claude/skills/my-own-skill"
  echo "mine" > "$HOME/.claude/skills/my-own-skill/SKILL.md"

  uninstall_all

  [ -f "$HOME/.claude/skills/my-own-skill/SKILL.md" ]
  assert_harness_links_removed "$HOME/.claude/skills"
}

@test "uninstall removes only the block when user text exists outside it" {
  install_tools claude
  echo "ブロック外のメモ" >> "$HOME/.claude/CLAUDE.md"

  uninstall_all

  [ -f "$HOME/.claude/CLAUDE.md" ]
  grep -qF "ブロック外のメモ" "$HOME/.claude/CLAUDE.md"
  ! has_block "$HOME/.claude/CLAUDE.md"
}

@test "block-only file is deleted and its backup restored" {
  install_tools claude
  echo "退避されていた元の内容" > "$HOME/.claude/CLAUDE.md.bak.20200101000000"

  uninstall_all

  [ -f "$HOME/.claude/CLAUDE.md" ]
  [ "$(cat "$HOME/.claude/CLAUDE.md")" = "退避されていた元の内容" ]
}

# root 配下にハーネス由来（リポジトリを指す）のリンクが残っていないこと
assert_harness_links_removed() {
  local root="$1" l
  for l in "$root"/*; do
    { [ -e "$l" ] || [ -L "$l" ]; } || continue
    ! managed_target "$l"
  done
}
