#!/usr/bin/env bash
# imk-harness をホームディレクトリへ展開する。再実行するとアップデートになる:
#   - CLAUDE.md / AGENTS.md の管理ブロック更新
#   - 選択から外したツールの配置物を掃除（バックアップがあれば復元）
#   - リポジトリから削除されたスキルの宙吊りリンクを掃除
# 実行前に変更予定の一覧を表示し、確認を取ってから適用する。
# アンインストールは ./uninstall.sh
#
# 使い方:
#   ./install.sh                              # 対話式で使うツールを選ぶ
#   ./install.sh --tools claude,codex,cursor  # ツールを指定
#   ./install.sh --tools claude --yes         # 確認をスキップ（CI 等）
#   ./install.sh --tools claude --dry-run     # 変更予定の表示のみ
#
# 配置ポリシー:
#   - CLAUDE.md / AGENTS.md は実ファイルにマーカー付きの「管理ブロック」を書き込む。
#     ブロックの外はユーザーの自由編集エリアで、更新・アンインストールでも保持される
#   - スキルは各ツールがネイティブに読む場所へ symlink する
#       Claude Code: ~/.claude/skills
#       Codex:       ~/.agents/skills（公式のスキャン場所。description による自動発火が効く）
#       Cursor:      ~/.agents/skills（ネイティブ扱いで常にスキャンされる）
#   - Claude + Codex + Cursor 併用時、Cursor には ~/.claude/skills の互換スキャンで同名スキルが
#     二重に見える。Cursor の third-party 設定 OFF で解消できるため案内する（ADR-0003）
#   - 既存の実ファイルを置き換える場合は .bak.<timestamp> に退避
#   - settings.json / config.toml は既存があれば触らない（手動マージ）
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
TS="$(date +%Y%m%d%H%M%S)"
. "$REPO/lib.sh"

usage() { echo "usage: ./install.sh [--tools claude,codex,cursor] [--yes|-y] [--dry-run]"; }

# --- 引数パース ---
TOOLS_ARG=""; ASSUME_YES=0; DRY_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --tools)
      if [ -z "${2:-}" ]; then usage; exit 1; fi
      TOOLS_ARG="$2"; shift 2 ;;
    --yes|-y)   ASSUME_YES=1; shift ;;
    --dry-run)  DRY_ONLY=1; shift ;;
    *) usage; exit 1 ;;
  esac
done

# --- ツール選択 ---
USE_CLAUDE=0; USE_CODEX=0; USE_CURSOR=0
if [ -n "$TOOLS_ARG" ]; then
  IFS=',' read -ra sel <<< "$TOOLS_ARG"
  for t in "${sel[@]}"; do
    case "$t" in
      claude) USE_CLAUDE=1 ;;
      codex)  USE_CODEX=1 ;;
      cursor) USE_CURSOR=1 ;;
      *) echo "unknown tool: $t (claude / codex / cursor)"; exit 1 ;;
    esac
  done
else
  ask() { local a; read -r -p "$1 [y/N]: " a; [ "$a" = "y" ] || [ "$a" = "Y" ]; }
  ask "Claude Code を使いますか?" && USE_CLAUDE=1 || true
  ask "Codex を使いますか?"       && USE_CODEX=1  || true
  ask "Cursor を使いますか?"      && USE_CURSOR=1 || true
fi

if [ $((USE_CLAUDE + USE_CODEX + USE_CURSOR)) -eq 0 ]; then
  echo "ツールが選択されていません。中止します。"
  exit 1
fi

# ~/.agents/skills が必要か（Codex / Cursor はともにネイティブでスキャンする — ADR-0003）
NEED_AGENTS=0
if [ "$USE_CODEX" -eq 1 ] || [ "$USE_CURSOR" -eq 1 ]; then
  NEED_AGENTS=1
fi

# --- 原本から生成（リポジトリ内の生成であり $HOME への変更ではないため確認対象外）---
"$REPO/build.sh"

# --- 変更内容の定義（DRYRUN=1 ではプラン収集、DRYRUN=0 で本実行）---
apply_changes() {
  # 1. 指示ファイル・設定
  if [ "$USE_CLAUDE" -eq 1 ]; then
    write_managed_block "$REPO/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    copy_if_absent "$REPO/claude/settings.json" "$HOME/.claude/settings.json"
  fi
  if [ "$USE_CODEX" -eq 1 ]; then
    write_managed_block "$REPO/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
    copy_if_absent "$REPO/codex/config.toml" "$HOME/.codex/config.toml"
  fi

  # 2. スキル配置
  if [ "$USE_CLAUDE" -eq 1 ]; then
    link_skills "$HOME/.claude/skills"
  fi
  if [ "$NEED_AGENTS" -eq 1 ]; then
    link_skills "$HOME/.agents/skills"
  fi

  # 3. アップデート時の掃除
  #    使っている場所: 削除済みスキルの宙吊りリンクのみ除去
  #    使わなくなった場所: ハーネス由来の配置物をすべて除去（バックアップがあれば復元）
  if [ "$USE_CLAUDE" -eq 1 ]; then
    prune_skills_root "$HOME/.claude/skills" stale
  else
    prune_skills_root "$HOME/.claude/skills" all
    remove_managed_link "$HOME/.claude/CLAUDE.md"  # 旧方式の symlink
    remove_block "$HOME/.claude/CLAUDE.md"
  fi
  if [ "$NEED_AGENTS" -eq 1 ]; then
    prune_skills_root "$HOME/.agents/skills" stale
  else
    prune_skills_root "$HOME/.agents/skills" all
  fi
  if [ "$USE_CODEX" -eq 0 ]; then
    remove_managed_link "$HOME/.codex/AGENTS.md"  # 旧方式の symlink
    remove_block "$HOME/.codex/AGENTS.md"
  fi
  prune_skills_root "$HOME/.codex/skills" all  # 旧バージョンの配置場所を掃除

  # 4. Cursor 向け案内
  if [ "$USE_CURSOR" -eq 1 ]; then
    if [ "$USE_CLAUDE" -eq 1 ]; then
      notice "Cursor には ~/.claude/skills の互換スキャンで同名スキルが二重に見えます。Cursor Settings > Rules, Skills, Subagents > 'Include third-party Plugins, Skills, and other configs' を OFF にすると解消します（OFF にするとプロジェクト側の .claude/ 系設定も Cursor から見えなくなる点に注意。ADR-0003 参照）。"
    fi
    notice "Cursor のユーザーレベル常駐指示: Cursor Settings > Rules, Skills, Subagents の User Rules に claude/CLAUDE.md の内容を貼り付けてください。"
  fi
}

run_with_confirmation "インストール完了" "$ASSUME_YES" "$DRY_ONLY"
