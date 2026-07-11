# ADR-0003: スキルは各ツールのネイティブディレクトリへ symlink 配置

- ステータス: 承認済み
- 日付: 2026-07-12
- 改訂: 2026-07-12 — Codex / Cursor の実装調査を反映。配置の決定は不変。
  Cursor の重複表示は「単に許容」から「third-party 設定 OFF の案内で解消」に精緻化

## コンテキスト

スキル（SKILL.md 形式）を Claude Code / Codex / Cursor で共有したい。
2026 年 7 月時点の調査結果（ユーザー層）:

| ツール | ネイティブのスキャン場所 |
|---|---|
| Claude Code | `~/.claude/skills` のみ（`.agents` 対応は未実装 — [claude-code#31005](https://github.com/anthropics/claude-code/issues/31005)） |
| Codex | `~/.agents/skills`（公式）。`~/.codex/skills` も読むが、ソース上「Deprecated user skills location, kept for backward compatibility」と明記（[loader.rs](https://github.com/openai/codex/blob/main/codex-rs/core-skills/src/loader.rs)） |
| Cursor | ネイティブ: `~/.agents/skills`・`~/.cursor/skills`（常に読む）。互換: `~/.claude/skills`・`~/.codex/skills`（third-party 設定で無効化可） |

Cursor のスキャン対象は 2 系統に分かれることが CLI（cursor-agent 2026.07.09）の
実装確認で判明した:

- **ネイティブ扱い**（`.agents` / `.cursor`）: 設定に関係なく常に読まれる
- **互換扱い**（`.claude` / `.codex`）: IDE の Settings > Rules, Skills, Subagents >
  「Include third-party Plugins, Skills, and other configs」を OFF にすると読まれなくなる
  （プロジェクト側の `.claude/skills`・`CLAUDE.md`・`.claude/agents` も併せて対象外になる
  全か無かの設定）。ただし cursor-agent CLI はこの設定を参照せず常に ON 相当
  （[機能リクエスト](https://forum.cursor.com/t/toggle-or-allowlist-for-agent-skills-roots-stop-loading-claude-skills-and-codex-skills-when-i-only-want-cursor-agents/160199)）

同じスキルを複数箇所に置くと重複表示になる（Codex も Cursor もマージしない）。
一方、ネイティブ配置でなければ description による自動発火（progressive disclosure）が
効かない。

## 決定

**実体は `shared/skills/`（ツール非依存）に置き、install.sh が選択されたツールの
ネイティブ位置へ symlink する。Codex の自動発火を優先する。**

- Claude Code 使用時: `~/.claude/skills/` へ
- Codex または Cursor 使用時: `~/.agents/skills/` へ（両ツールともネイティブでスキャンする。
  Cursor を `~/.claude/skills` の互換スキャン頼みにすると third-party 設定 OFF で
  スキルが見えなくなるため、Cursor 使用時も必ずこちらへ配置する）
- Claude Code + Cursor 併用時は両方へ配置され、Cursor（IDE）に重複表示が生じる。
  これは上記 third-party 設定を OFF にすることで解消できるため、install.sh がその案内を
  表示する（OFF の副作用と cursor-agent CLI の未対応は上記コンテキスト参照）

## 検討した代替案

- **AGENTS.md に「作業前に該当 SKILL.md を読め」と書く誘導文方式** — Codex にネイティブの
  スキル機能がなかった時代のワークアラウンド。一度採用したが、自動発火が効かず
  モデルの指示遵守に依存するため、ネイティブ対応の判明を受けて廃止
- **重複回避を優先して物理配置を常に 1 系統にする** — 3 ツール併用時に Codex か
  Claude Code のどちらかが劣化する
- **`~/.agents/skills` への一本化** — オープン標準としては本命だが Claude Code が未対応
- **Cursor 用に `~/.cursor/skills` へ展開し third-party 設定 OFF を前提にする**（2026-07-12
  改訂時に検討）— `.agents` はネイティブ扱いで設定 OFF でも読まれ続けるため、Codex 用の
  `~/.agents/skills` と併存すると結局二重になる。回避には Codex を非推奨の
  `~/.codex/skills` へ移すしかなく本末転倒。さらに cursor-agent CLI では設定が効かず
  `~/.claude` + `~/.codex` + `~/.cursor` の三重表示になり現状より悪化する

## 結果

- 全ツールでスキルの自動発火が効く。追加・削除は `shared/skills/` と install.sh 再実行だけ
- Cursor（IDE）併用時の重複表示は third-party 設定 OFF で解消できる。ただし OFF にすると
  プロジェクト側の `.claude/` 系設定も Cursor から見えなくなる点はユーザーの選択に委ねる
- cursor-agent CLI では重複（`~/.claude` + `~/.agents` の 2 重）が残る。Cursor 側の
  設定対応待ち
- Claude Code が `.agents/skills` に対応した時点で `~/.agents/skills` の 1 箇所に
  統合して本 ADR を改訂する予定
