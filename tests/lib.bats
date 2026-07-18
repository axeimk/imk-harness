#!/usr/bin/env bats
# lib.sh 単体: 管理ブロック操作と managed_target 判定
# テスト名は ASCII にする（bats + macOS bash 3.2 は多バイトのテスト名を解決できない）

load helpers

@test "append_block then extract_block round-trips the content" {
  src="$HOME/src.md"
  dst="$HOME/dst.md"
  printf '1 行目\n2 行目\n' > "$src"

  append_block "$src" "$dst"

  block_is_current "$src" "$dst"
  diff "$src" <(extract_block "$dst")
}

@test "remainder_is_empty detects substantial content outside the block" {
  src="$HOME/src.md"
  dst="$HOME/dst.md"
  echo "本文" > "$src"

  append_block "$src" "$dst"
  remainder_is_empty "$dst"

  echo "ブロック外の行" >> "$dst"
  ! remainder_is_empty "$dst"
}

@test "replace_block swaps only the block body" {
  src="$HOME/src.md"
  dst="$HOME/dst.md"
  echo "旧内容" > "$src"
  echo "前置きの行" > "$dst"
  append_block "$src" "$dst"

  new="$HOME/new.md"
  echo "新内容" > "$new"
  replace_block "$new" "$dst"

  block_is_current "$new" "$dst"
  head -n 1 "$dst" | grep -qF "前置きの行"
}

@test "managed_target accepts only symlinks pointing into the repo" {
  ln -s "$REPO/shared/skills/harness-check" "$HOME/managed"
  managed_target "$HOME/managed"

  ln -s /usr/bin "$HOME/unmanaged"
  ! managed_target "$HOME/unmanaged"

  echo "real" > "$HOME/regular-file"
  ! managed_target "$HOME/regular-file"
}

@test "managed_target accepts dangling links left after a repo move" {
  ln -s /nonexistent/old-path/imk-harness/shared/skills/harness-check "$HOME/dangling"
  managed_target "$HOME/dangling"

  ln -s /nonexistent/other-tool/skills/foo "$HOME/dangling-other"
  ! managed_target "$HOME/dangling-other"
}
