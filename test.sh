#!/usr/bin/env bash
# 自動テスト（bats）を実行する。テストは一時ディレクトリを HOME にして走るため実ホームには触れない。
# bats は npm の devDependency として管理している（初回は npm install）。
set -euo pipefail
cd "$(dirname "$0")"

bats="node_modules/.bin/bats"
if [ ! -x "$bats" ]; then
  echo "bats が見つかりません。先に依存を取得してください: npm install" >&2
  exit 1
fi
exec "$bats" tests "$@"
