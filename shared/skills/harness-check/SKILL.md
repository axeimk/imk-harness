---
name: harness-check
description: 新しいプロジェクトで作業を始めるとき、またはプロジェクトの CLAUDE.md / AGENTS.md / verify スキルが未整備だと気づいたときに、プロジェクト特化層をブートストラップする。
---

# harness-check — プロジェクト特化層のブートストラップ

このスキルは「汎用ハーネスが各プロジェクトのハーネスを育てる」ための入口。以下を順に確認し、欠けているものを提案・作成する。

## 手順

1. **現状確認**（プロジェクトルートで）
   - `CLAUDE.md` があるか
   - `AGENTS.md` があるか（Codex も使うプロジェクトの場合）
   - `.claude/skills/verify/SKILL.md` があるか
   - `.claude/settings.json`（プロジェクト固有 permissions）があるか
2. **欠けているものを一覧にしてユーザーに提示し、作成の許可を得る。** 勝手に全部作らない。
3. **CLAUDE.md の作成**: `templates/CLAUDE.md.template` を土台に、リポジトリを調査して埋める（ビルド・テストコマンドは package.json / Makefile / pyproject.toml 等から実際に確認する。推測で書かない）。
4. **verify スキルの作成**: `templates/verify-SKILL.md.template` を土台に、そのプロジェクトを実際にビルド・起動・操作して変更を確認するためのレシピ（起動コマンド、確認すべき代表フロー、落とし穴）を記載する。テスト・lint・ビルドのコマンド一覧は CLAUDE.md の「コマンド」節に置き、ここには重複させない。作成後、レシピどおりに一度起動して動くことを確認する。
5. **lint / test hooks の提案**（任意）: 編集後の lint など機械的に強制したい検査があれば、ツールごとの hooks 設定を提案する（Claude Code: `.claude/settings.json`、Codex: `hooks.json` または `config.toml` の `[hooks]`、Cursor: `.cursor/hooks.json`）。テストスイート全実行のような重い処理は hooks に入れない。
6. **AGENTS.md**: CLAUDE.md と同内容でよい。差分が必要になったときだけ分ける。

## 注意

- 既存ファイルがある場合は上書きせず、不足しているセクションの追記を提案する。
- プロジェクト固有の知識のみを書く。汎用的なルール（応答スタイル等）はユーザー層 CLAUDE.md に既にあるので重複させない。
- Claude Code にはビルトインの verify スキル（変更を実行時観察で検証する汎用手順）があり、プロジェクトに verify スキルが無ければ自らブートストラップする。ここで作る verify スキルはそれと競合せず、ビルトイン verify が起動手段を探す段階で参照するプロジェクト固有レシピとして機能する（Codex / Cursor ではそのまま手順書として使う）。中身をテストコマンドの羅列にしないこと — ビルトイン verify は「テスト実行は検証ではない」という前提で動く。
