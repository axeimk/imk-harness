# テスト共通ヘルパー。各テストは一時ディレクトリを HOME にして実行する（実ホームに触れない）。
# fake-home.sh（対話作業用・状態を再利用する）とは別に、テストごとに独立した HOME を作る。

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FAKE_HOME="$(mktemp -d)"
  export HOME="$FAKE_HOME"
  # lib.sh のヘルパー（extract_block 等）をアサーションに再利用する
  TS="$(date +%Y%m%d%H%M%S)"
  . "$REPO/lib.sh"
}

teardown() {
  rm -rf "$FAKE_HOME"
}

# fake HOME 配下のファイルツリー（比較用スナップショット）
snapshot() { find "$HOME" | LC_ALL=C sort; }

install_tools() {
  local tools="$1"; shift
  "$REPO/install.sh" --tools "$tools" --yes "$@"
}

uninstall_all() { "$REPO/uninstall.sh" --yes; }

# dst の管理ブロックの中身が src と一致していること
assert_block_matches() {
  local src="$1" dst="$2"
  [ -f "$dst" ]
  has_block "$dst"
  diff <(cat "$src") <(extract_block "$dst")
}

# shared/skills/ の全スキルが root 配下にリポジトリへの symlink として並んでいること
assert_skills_linked() {
  local root="$1" d name
  for d in "$REPO"/shared/skills/*/; do
    name="$(basename "${d%/}")"
    [ -L "$root/$name" ]
    [ "$(readlink "$root/$name")" = "${d%/}" ]
  done
}
