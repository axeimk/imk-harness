#!/usr/bin/env bash
# imk-harness が配置したものを取り除く。実行前に変更予定の一覧を表示し、確認を取ってから適用する。
#   - CLAUDE.md / AGENTS.md: 管理ブロックのみ除去（ブロック外のユーザーテキストは保持。
#     ブロックしかないファイルは削除し、バックアップがあれば復元）
#   - スキル: ハーネス由来の symlink のみ除去（ユーザーが自分で置いたスキルには触れない）
#   - settings.json / config.toml: コピー配置のため削除しない（サマリで案内）
#
# 使い方:
#   ./uninstall.sh              # 確認あり
#   ./uninstall.sh --yes        # 確認をスキップ
#   ./uninstall.sh --dry-run    # 変更予定の表示のみ
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
TS="$(date +%Y%m%d%H%M%S)"
. "$REPO/lib.sh"

usage() { echo "usage: ./uninstall.sh [--yes|-y] [--dry-run]"; }

ASSUME_YES=0; DRY_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)  ASSUME_YES=1; shift ;;
    --dry-run) DRY_ONLY=1; shift ;;
    *) usage; exit 1 ;;
  esac
done

apply_changes() {
  # 指示ファイル（旧方式の symlink → 管理ブロックの順に掃除）
  remove_managed_link "$HOME/.claude/CLAUDE.md"
  remove_block "$HOME/.claude/CLAUDE.md"
  remove_managed_link "$HOME/.codex/AGENTS.md"
  remove_block "$HOME/.codex/AGENTS.md"

  # スキル（旧バージョンの配置場所 ~/.codex/skills も含めて掃除）
  prune_skills_root "$HOME/.claude/skills" all
  prune_skills_root "$HOME/.agents/skills" all
  prune_skills_root "$HOME/.codex/skills" all

  # コピーで配置したファイルの案内
  local f
  for f in "$HOME/.claude/settings.json" "$HOME/.codex/config.toml"; do
    if [ -e "$f" ]; then
      notice "$f は削除していません（インストール後に編集されている可能性があるため）。不要なら手動で削除してください。"
    fi
  done

  # 復元しきれなかった古いバックアップの案内
  local leftover
  leftover="$(ls -1d "$HOME/.claude/CLAUDE.md".bak.* "$HOME/.codex/AGENTS.md".bak.* 2>/dev/null || true)"
  if [ -n "$leftover" ]; then
    notice "古いバックアップが残っています（最新のもののみ復元済み）: $(echo "$leftover" | tr '\n' ' ')"
  fi
}

run_with_confirmation "アンインストール完了" "$ASSUME_YES" "$DRY_ONLY"
