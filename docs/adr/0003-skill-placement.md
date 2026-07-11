# ADR-0003: スキルは各ツールのネイティブディレクトリへ symlink 配置

- ステータス: 承認済み
- 日付: 2026-07-12

## コンテキスト

スキル（SKILL.md 形式）を Claude Code / Codex / Cursor で共有したい。
2026 年 7 月時点の調査結果（ユーザー層）:

| ツール | ネイティブのスキャン場所 |
|---|---|
| Claude Code | `~/.claude/skills` のみ（`.agents` 対応は未実装 — [claude-code#31005](https://github.com/anthropics/claude-code/issues/31005)） |
| Codex | `~/.agents/skills`（公式ドキュメント。サードパーティ記事の `~/.codex/skills` は古い情報） |
| Cursor | `~/.agents/skills`・`~/.cursor/skills`、加えて互換で `~/.claude/skills`・`~/.codex/skills` |

Cursor が複数系統を互換スキャンするため、同じスキルを複数箇所に置くと重複表示のリスクが
ある（重複排除の仕様は非公開）。一方、ネイティブ配置でなければ description による
自動発火（progressive disclosure）が効かない。

## 決定

**実体は `shared/skills/`（ツール非依存）に置き、install.sh が選択されたツールの
ネイティブ位置へ symlink する。Cursor での重複表示は許容し、Codex の自動発火を優先する。**

- Claude Code 使用時: `~/.claude/skills/` へ
- Codex 使用時（または Cursor のみ）: `~/.agents/skills/` へ
- 3 ツール併用時は両方へ配置し、Cursor に同名スキルが二重に見える可能性を受け入れる
  （install.sh がその旨を表示する）

## 検討した代替案

- **AGENTS.md に「作業前に該当 SKILL.md を読め」と書く誘導文方式** — Codex にネイティブの
  スキル機能がなかった時代のワークアラウンド。一度採用したが、自動発火が効かず
  モデルの指示遵守に依存するため、ネイティブ対応の判明を受けて廃止
- **重複回避を優先して物理配置を常に 1 系統にする** — 3 ツール併用時に Codex か
  Claude Code のどちらかが劣化する
- **`~/.agents/skills` への一本化** — オープン標準としては本命だが Claude Code が未対応

## 結果

- 全ツールでスキルの自動発火が効く。追加・削除は `shared/skills/` と install.sh 再実行だけ
- Cursor 併用時に同名スキルが二重に見える可能性が残る
- Claude Code が `.agents/skills` に対応した時点で `~/.agents/skills` の 1 箇所に
  統合して本 ADR を改訂する予定
