# Subagents 仕様調査 — Claude Code / Codex / Cursor

- 調査日: 2026-07-28
- 目的: 3 ツールのカスタムサブエージェント定義を比較し、
  imk-subagent-creator スキルの参照資料を作る判断材料にする

## 正規のダイジェストはスキル側にある

各ツールの仕様ダイジェストは
**`shared/skills/imk-subagent-creator/references/`** が持つ
（claude-code.md / codex.md / cursor.md）。展開先で読まれる資料を自己完結させ、
同じ仕様を二重管理しないため、ここには調査の出典・要点・設計判断だけを残す。
仕様更新はスキル側の references を直接更新する。

## 一次情報

| ツール | URL |
|---|---|
| Claude Code | https://code.claude.com/docs/en/sub-agents |
| Codex | https://developers.openai.com/codex/subagents |
| Cursor | https://cursor.com/docs/subagents |

## 調査の要点（2026-07-28 時点）

- **3 ツールとも、再利用可能なカスタムサブエージェント定義を持つ**
- 共通概念は、独立コンテキスト、親への結果返却、description による委譲判断、
  モデル・権限の専門化
- **単一の共通ファイル形式にはできない**
  - Claude Code: `.claude/agents/*.md`、YAML frontmatter + Markdown 本文
  - Codex: `.codex/agents/*.toml`、`name` / `description` /
    `developer_instructions` が必須
  - Cursor: `.cursor/agents/*.md`、YAML frontmatter + Markdown 本文
- 同じ意図でも設定名が違う
  - 読み取り専用: Claude Code は `tools` 等、Codex は
    `sandbox_mode = "read-only"`、Cursor は `readonly: true`
  - バックグラウンド固定: Claude Code は `background`、Cursor は
    `is_background`、Codex の共通定義フィールドには相当項目がない
  - 親モデル継承: Claude Code / Cursor は `model: inherit`、Codex は
    `model` の省略
- Cursor は `.claude/agents/` / `.codex/agents/` も互換走査するが、3 ツールそれぞれの
  固有設定を正確に使う場合はネイティブ定義を置き、`.cursor/` の優先順位で曖昧さをなくす
- モデルや実効権限は、組織ポリシー、親セッション、プラン、実行時上書きで変わる。
  静的な定義検査だけでなく、明示起動して実効値を確認する必要がある
- 仕様は変化中である。特に Claude Code の再読込・バックグラウンド・子エージェント、
  Codex の単独 TOML 方式、Cursor のモデルフォールバックは学習知識より公式一次情報を優先する
