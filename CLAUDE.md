# imk-harness 開発ガイド

コーディングエージェント（Claude Code / Codex / Cursor）がこのリポジトリで作業する際のガイド。
ルートの `CLAUDE.md` と `AGENTS.md` は同一内容（symlink）。

## このリポジトリは何か

Claude Code / Codex / Cursor 用の**汎用ハーネス**（ユーザー層の設定・知識・規約の一式）。
ホームディレクトリ（`~/.claude/` `~/.codex/` `~/.agents/`）へ展開して使う。
プロジェクト固有の知識は各プロジェクト側（特化層）に置く方針で、このリポジトリには
全プロジェクト共通のものだけを置く（ADR-0001）。

## ⚠ 最重要: 役割の違う指示ファイルを混同しない

- **この `CLAUDE.md`（リポジトリルート）** — このリポジトリで作業するための開発者向けガイド。
  ルートの `AGENTS.md` はこのファイルへの symlink（Codex / Cursor 向けに同一内容を提供）
- **`claude/CLAUDE.md` と `codex/AGENTS.md`** — `build.sh` の**生成物**。ホーム側ファイルの
  管理ブロックに書き込まれる中身。**直接編集禁止**。編集するのは原本の `shared/instructions/*.md`

## コマンド

```sh
./build.sh                                # shared/instructions/ から生成物を再生成
./install.sh --tools claude,codex,cursor  # ホームへ展開（プラン表示 → y/N 確認 → 適用）
./install.sh --tools claude --dry-run     # 変更予定の表示のみ（FS 無変更）
./install.sh --tools claude --yes         # 確認スキップ
./uninstall.sh [--yes|--dry-run]          # アンインストール
bash -n lib.sh install.sh uninstall.sh    # 構文チェック
```

### テスト（fake HOME パターン）

自動テストはない。動作確認は `$HOME` を一時ディレクトリに差し替えて行う（実ホームに触れない）:

```sh
H=$(mktemp -d)
HOME="$H" ./install.sh --tools claude,codex --yes
find "$H" | sort            # 配置結果の確認
HOME="$H" ./uninstall.sh --yes
rm -rf "$H"
```

検証すべき代表ケース: dry-run で FS 不変 / n 応答で無変更中止 / 再実行で「変更はありません」
（冪等性）/ 管理ブロック外のユーザーテキスト保持 / ツール選択縮小時の掃除 /
ユーザー自身が置いたスキルに触れないこと。

## アーキテクチャ

データフローは一方向:

```
shared/instructions/*.md（原本）
  → build.sh が連結 → claude/CLAUDE.md, codex/AGENTS.md（生成物）
  → install.sh がホーム側ファイルの「管理ブロック」（マーカー間）に書き込む
shared/skills/*/ （スキル実体）
  → install.sh が各ツールのネイティブ位置へ symlink
     （Claude: ~/.claude/skills, Codex/Cursor: ~/.agents/skills — ADR-0003）
```

- **管理ブロック方式**（ADR-0004): ホーム側の CLAUDE.md / AGENTS.md は実ファイルで、
  ASCII マーカー `<!-- >>> imk-harness:begin >>> -->` 〜 `<!-- <<< imk-harness:end <<< -->`
  の間だけをハーネスが所有する。ブロック外はユーザーの自由編集エリアで、絶対に変更しない
- **2 段階実行**（ADR-0005): install/uninstall は同一の `apply_changes()` を
  `DRYRUN=1`（プラン収集のみ・FS 無変更）→ 確認 → `DRYRUN=0`（本実行）の 2 回実行する。
  **ファイルを変更する処理は必ず `lib.sh` のヘルパー経由で書く**（直接 rm/cp/ln を
  スクリプトに書くと dry-run とプラン表示が壊れる）。新しい変更系ヘルパーには
  DRYRUN 分岐（`plan "..."` / 実行）を必ず実装する
- **非破壊方針**（ADR-0006): 削除・変更してよいのは `managed_target`（symlink 先が
  このリポジトリ配下）と判定できるものだけ。settings.json / config.toml は
  `copy_if_absent`（上書き・削除禁止）。ユーザーへの案内は `notice "..."` に積むと
  最後にサマリ表示される

## シェルスクリプトの制約

- **macOS 標準 bash 3.2 互換で書く**。特に「変数の直後に全角文字」は変数名の誤認で
  落ちるため `${VAR}` 形式にする。実装後は次で機械検査:
  `grep -nP '\$\{?[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]' lib.sh install.sh uninstall.sh build.sh`
- 日本語を含むテキスト処理は sed でなく **awk + ASCII マーカー + `LC_ALL=C`**
  （macOS sed は多バイトで "illegal byte sequence" を起こす）

## 設計変更時のルール

設計判断は `docs/adr/` に記録されている。既存の決定を覆す変更をするときは、
新しい ADR を追加し、古い ADR のステータスを「廃止（ADR-XXXX により置換）」に変更する。
特に ADR-0003（スキル配置）は Claude Code が `.agents/skills` に対応した時点で
改訂する前提（[claude-code#31005](https://github.com/anthropics/claude-code/issues/31005)）。

ユーザー環境に展開されるファイル（`shared/` 配下と生成物）には、このリポジトリ内部への
参照（ADR 番号、`docs/` へのパス等）を書かない。展開先では参照できず、展開先プロジェクトが
独自の ADR を持っている場合はエージェントを混乱させる。
