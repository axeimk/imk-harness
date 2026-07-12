---
name: verify
description: このプロジェクト（imk-harness）の変更を実際に動かして確認するためのレシピ。install.sh / uninstall.sh / lib.sh / build.sh / shared/ 配下を変更したら、報告の前に fake HOME パターン（$HOME を一時ディレクトリに差し替えて実際に展開）で変更が動くことを確認する。
---

# verify — imk-harness の動作確認レシピ

変更が実際に動くことを、インストーラを本当に実行して確認するための手順。
検査スクリプト（`./check-skills.sh` `./check-shell.sh`）は CLAUDE.md / AGENTS.md の
「コマンド」節を参照。検査が通ることは検証ではない — 実際に展開して配置結果を見る。

## fake HOME パターン（基本形）

自動テストはない。`scripts/fake-home.sh` 経由でインストーラを実行する。
このラッパーが `$HOME` を一時ディレクトリに差し替えるので、実ホームには触れない
（`HOME="$H"` の付け忘れ事故が起きない）。リポジトリルートで:

```sh
S=.claude/skills/verify/scripts/fake-home.sh
"$S" ./install.sh --tools claude,codex --yes
find "$("$S" --path)" | sort    # 配置結果の確認
"$S" ./uninstall.sh --yes
find "$("$S" --path)" | sort    # 残骸がないことの確認
"$S" --reset                    # 後始末（fake HOME を破棄）
```

fake HOME のパスは `--reset` するまで再利用されるので、install → 確認 → uninstall を
同じ環境に対して行える。install.sh は冒頭で build.sh を自動実行するので、
`shared/instructions/` を編集した場合もこのレシピだけで生成物の反映まで確認できる。

## 確認すべき代表フロー（変更内容に応じて選ぶ）

- **dry-run で FS 不変**: `--dry-run` の前後で `find "$H" | sort` の結果が同一
- **n 応答で無変更中止**: `--yes` を付けずに実行し n を入力 → 何も変更されない
- **冪等性**: install を 2 回実行し、2 回目が「変更はありません」になる
- **管理ブロック外のユーザーテキスト保持**: fake HOME 側の `~/.claude/CLAUDE.md` の
  マーカー外に行を追記 → install 再実行でもその行が残る。uninstall では
  ブロックだけが除去され追記行は残る
- **ツール選択縮小時の掃除**: `--tools claude,codex` で入れた後 `--tools claude` で
  再実行 → codex 向けの配置物が除去される
- **ユーザー自身が置いたスキルに触れない**: fake HOME の skills ディレクトリに
  手動でディレクトリを作る → uninstall 後も残る

## 落とし穴

- インストーラを直接実行しない。必ず `fake-home.sh` 経由にする（直接実行すると
  実環境に展開される）
- install.sh は対話式（y/N 確認）なので、非対話の確認では `--yes` を付ける
- 生成物（`claude/CLAUDE.md` `codex/AGENTS.md`）を直接編集して試さない。
  原本は `shared/instructions/`（install.sh 実行時に再生成されて上書きされる）
