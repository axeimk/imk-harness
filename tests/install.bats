#!/usr/bin/env bats
# install.sh の基本フロー: 配置・冪等性・dry-run・確認中止・ツール縮小時の掃除
# テスト名は ASCII にする（bats + macOS bash 3.2 は多バイトのテスト名を解決できない）

load helpers

@test "first install places instructions, settings, and skills" {
  install_tools claude,codex

  assert_block_matches "$REPO/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  diff "$REPO/claude/settings.json" "$HOME/.claude/settings.json"
  assert_skills_linked "$HOME/.claude/skills"

  assert_block_matches "$REPO/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
  diff "$REPO/codex/config.toml" "$HOME/.codex/config.toml"
  assert_skills_linked "$HOME/.agents/skills"
}

@test "claude-only install leaves codex/agents untouched" {
  install_tools claude

  [ -f "$HOME/.claude/CLAUDE.md" ]
  [ ! -e "$HOME/.codex" ]
  [ ! -e "$HOME/.agents" ]
}

@test "second install reports no changes and leaves FS identical" {
  install_tools claude,codex
  local before
  before="$(snapshot)"

  run install_tools claude,codex
  [ "$status" -eq 0 ]
  [[ "$output" == *"変更はありません"* ]]
  [ "$(snapshot)" = "$before" ]
}

@test "dry-run does not modify the FS" {
  local before
  before="$(snapshot)"

  run install_tools claude,codex --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"適用しません"* ]]
  [ "$(snapshot)" = "$before" ]
}

@test "answering n at the confirmation prompt changes nothing" {
  local before
  before="$(snapshot)"

  run bash -c "echo n | '$REPO/install.sh' --tools claude"
  [ "$status" -eq 0 ]
  [[ "$output" == *"中止しました"* ]]
  [ "$(snapshot)" = "$before" ]
}

@test "shrinking tool selection cleans up the dropped tool" {
  install_tools claude,codex
  install_tools claude

  # codex 向けの配置物は除去される（管理ブロックのみの AGENTS.md はファイルごと削除）
  [ ! -e "$HOME/.codex/AGENTS.md" ]
  [ ! -e "$HOME/.agents/skills" ]
  # コピー配置した config.toml は非破壊方針により残る
  [ -f "$HOME/.codex/config.toml" ]
  # claude 側は無傷
  assert_block_matches "$REPO/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  assert_skills_linked "$HOME/.claude/skills"
}

@test "only dangling links of removed skills are pruned" {
  install_tools claude
  # リポジトリから削除されたスキルを模したリンク切れ symlink を置く
  ln -s "$REPO/shared/skills/removed-skill" "$HOME/.claude/skills/removed-skill"

  install_tools claude

  [ ! -e "$HOME/.claude/skills/removed-skill" ]
  [ ! -L "$HOME/.claude/skills/removed-skill" ]
  assert_skills_linked "$HOME/.claude/skills"
}

@test "changed skill content is reported on reinstall" {
  install_tools claude
  local mf="$HOME/.claude/skills/.imk-harness-manifest"
  [ -f "$mf" ]
  # 前回記録のハッシュを書き換えて「前回展開時から内容が変わった」状態を作る
  # （リポジトリの実スキルは変更できないため、記録側を古くする）
  awk '$1 == "harness-check" { print $1, "stale"; next } { print }' "$mf" > "$mf.tmp"
  mv "$mf.tmp" "$mf"

  run install_tools claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"内容が更新されたスキル: harness-check"* ]]

  # 記録は現在の内容に更新され、次回は差分なしに戻る
  run install_tools claude
  [[ "$output" == *"変更はありません"* ]]
}

@test "skill update notice is shown once across multiple roots" {
  install_tools claude,codex
  local root mf
  for root in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
    mf="$root/.imk-harness-manifest"
    awk '$1 == "harness-check" { print $1, "stale"; next } { print }' "$mf" > "$mf.tmp"
    mv "$mf.tmp" "$mf"
  done

  run install_tools claude,codex
  [ "$status" -eq 0 ]
  # 両ルートで同じ更新を検知しても通知は 1 回
  [ "$(grep -c "内容が更新されたスキル" <<< "$output")" -eq 1 ]
}

@test "existing settings.json is never overwritten" {
  mkdir -p "$HOME/.claude"
  echo '{"mine": true}' > "$HOME/.claude/settings.json"

  install_tools claude

  [ "$(cat "$HOME/.claude/settings.json")" = '{"mine": true}' ]
}
