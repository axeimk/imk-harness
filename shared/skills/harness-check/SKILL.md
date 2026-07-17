---
name: harness-check
description: プロジェクト特化層（CLAUDE.md / AGENTS.md、verify スキル、HARNESS.md など）をブートストラップ・整備する。ユーザーが明示的に起動を求めたとき（新規プロジェクトの立ち上げ、特化層の整備・見直しの依頼）だけ使う。エージェントの判断で自発的に起動・提案しない。
---

# harness-check — プロジェクト特化層のブートストラップ

このスキルは「汎用ハーネスが各プロジェクトのハーネスを育てる」ための入口。以下を順に確認し、欠けているものを提案・作成する。

## 手順

1. **使用ツールの確認**: このプロジェクトで使うコーディングエージェント（Claude Code / Codex / Cursor）をユーザーに確認する。既存ファイルの有無から推測しない（CLAUDE.md しか無いプロジェクトでこれから Codex を使い始めることもある）。`HARNESS.md` に記録済みならそれに従い、再確認しない。回答は手順 8 で `HARNESS.md` に記録する。以降の手順の要否と配置場所はこの選択で決まる。
2. **現状確認**（プロジェクトルートで）
   - `HARNESS.md`（採否の記録）があるか。旧規約の記録（CLAUDE.md / AGENTS.md の「ハーネス」節）が残っていないかも確認する
   - `CLAUDE.md` があるか（Claude Code を使う場合）
   - `AGENTS.md` があるか（Codex / Cursor を使う場合）
   - verify スキルがあるか（Claude Code: `.claude/skills/verify/SKILL.md`、Codex / Cursor: `.agents/skills/verify/SKILL.md`）
   - `CONTEXT.md`（プロジェクト用語集）があるか
   - プロジェクト固有 permissions / hooks があるか（Claude Code: `.claude/settings.json`、Codex: `config.toml`、Cursor: `.cursor/`）
3. **欠けているものを項目ごとに提示し、要る / 要らないをユーザーに選ばせる。** 勝手に全部作らない。`HARNESS.md` に「使わない」と記録済みの項目は一覧に載せない（ユーザーが明示的に見直しを求めたときを除く）。
4. **CLAUDE.md / AGENTS.md の作成**: `templates/CLAUDE.md.template` を土台に、リポジトリを調査して埋める（ビルド・テストコマンドは package.json / Makefile / pyproject.toml 等から実際に確認する。推測で書かない）。ファイル名は使用ツールに合わせる。両方必要な場合は AGENTS.md（ツール非依存側）を実体にし、CLAUDE.md をそこへの symlink にする（コピーを 2 つ置くと乖離する）。差分が必要になったときだけ実ファイルに分ける。
5. **verify スキルの作成**: `templates/verify-SKILL.md.template` を土台に、そのプロジェクトを実際にビルド・起動・操作して変更を確認するためのレシピ（起動コマンド、確認すべき代表フロー、落とし穴）を記載する。テスト・lint・ビルドのコマンド一覧は CLAUDE.md / AGENTS.md の「コマンド」節に置き、ここには重複させない。
   - 配置は使用ツールに合わせる（Claude Code: `.claude/skills/verify/`、Codex / Cursor: `.agents/skills/verify/`）。両方必要な場合は `.agents/skills/verify/` に実体を置き、`.claude/skills/verify` → `../../.agents/skills/verify` の symlink を張る（`.agents` がツール非依存の場所。コピーを 2 つ置くと乖離する）
   - description はテンプレートのままにせず、プロジェクト名と対象（何を変更したときに使うか）を入れて具体化する
   - 作成後、imk-skill-creator スキル（あれば）に同梱の `scripts/validate-skill.sh` で検査し、レシピどおりに一度起動して動くことを確認する
6. **CONTEXT.md の作成**（選ばれた場合）: domain-modeling スキル（あれば）の手順とテンプレートに従う。その時点で確立している用語だけを書き、リポジトリを走査した一括収集はしない。確立した用語がまだ無いプロジェクトでは「最初の用語が確定したときに作る」で足りるので、無理に作らない。
7. **lint / test hooks の提案**（任意）: 編集後の lint など機械的に強制したい検査があれば、使用ツールごとの hooks 設定を提案する（Claude Code: `.claude/settings.json`、Codex: `hooks.json` または `config.toml` の `[hooks]`、Cursor: `.cursor/hooks.json`）。テストスイート全実行のような重い処理は hooks に入れない。
8. **採否の記録**: 使用ツール（手順 1）と、「要らない」と選ばれた項目をプロジェクトルートの `HARNESS.md` に記録し、以後どのエージェントも再確認・再提案しないようにする（例: `- verify スキル: 使わない（2026-07-12 ユーザー判断）`）。ファイルが無ければ `templates/HARNESS.md.template` を土台に作る。

## 注意

- このスキルが提案する規約はデフォルトの提供であり、強制ではない。ユーザーの「要らない」は記録して尊重する。
- 旧規約では採否を CLAUDE.md / AGENTS.md の「ハーネス」節に記録していた。この節を見つけたら、記録を `HARNESS.md` へ移して節を削除する移行を提案する（勝手に移さない。移行するまでは節の記録も尊重する）。
- 既存ファイルがある場合は上書きせず、不足しているセクションの追記を提案する。
- プロジェクト固有の知識のみを書く。汎用的なルール（応答スタイル等）はユーザー層 CLAUDE.md に既にあるので重複させない。
- Claude Code にはビルトインの verify スキル（変更を実行時観察で検証する汎用手順）があり、プロジェクトに verify スキルが無ければ自らブートストラップする。ここで作る verify スキルはそれと競合せず、ビルトイン verify が起動手段を探す段階で参照するプロジェクト固有レシピとして機能する（Codex / Cursor ではそのまま手順書として使う）。中身をテストコマンドの羅列にしないこと — ビルトイン verify は「テスト実行は検証ではない」という前提で動く。
