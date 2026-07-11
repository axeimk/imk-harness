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
4. **verify スキルの作成**: `templates/verify-SKILL.md.template` を土台に、そのプロジェクトで実際に動くテスト・lint・ビルドコマンドを記載する。作成後、一度実行して動くことを確認する。
5. **AGENTS.md**: CLAUDE.md と同内容でよい。差分が必要になったときだけ分ける。

## 注意

- 既存ファイルがある場合は上書きせず、不足しているセクションの追記を提案する。
- プロジェクト固有の知識のみを書く。汎用的なルール（応答スタイル等）はユーザー層 CLAUDE.md に既にあるので重複させない。
