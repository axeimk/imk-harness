# Hooks 仕様調査 — Claude Code / Codex / Cursor

- 調査日: 2026-07-21
- 目的: 3 ツールの hooks（ライフサイクルフック）仕様を確認し、imk-hooks-creator スキル
  （ADR-0017）の参照資料を作る判断材料にする

## 正規のダイジェストはスキル側にある

各ツールの仕様ダイジェストは **`shared/skills/imk-hooks-creator/references/`** が持つ
（claude-code.md / codex.md / cursor.md）。スキルの参照資料は展開先で読まれるため
自己完結が必要で、同じ内容を本ディレクトリに複製すると乖離するだけなので、
ここには調査の記録（出典・要点・判断）だけを残す。仕様の更新もスキル側の references を
直接更新する（各ファイルに調査日と一次情報 URL を記載済み）。

## 一次情報

| ツール | URL | 備考 |
|---|---|---|
| Claude Code | https://code.claude.com/docs/en/hooks | |
| Codex | https://developers.openai.com/codex/hooks | learn.chatgpt.com/docs/hooks へリダイレクト |
| Cursor | https://cursor.com/docs/hooks | Cursor 1.7（2025-09 頃）で導入 |

## 調査の要点（2026-07-21 時点）

- **3 ツールとも hooks 機構が実在する**。かつて Codex は `notify` 程度しか無かったが、
  現在はライフサイクルフック（`hooks.json` / `config.toml` の `[hooks]`）を持つ
- **共通の設計思想**: 外部コマンドを spawn し、stdin で JSON を受け、
  exit 0 + stdout JSON で構造化応答、exit 2 でブロック
- **しかし相互運用性は無い**。差異の代表例:
  - 設定構造: Claude Code / Codex は「イベント → matcher グループ → hooks」の 2 段ネスト。
    Cursor は `version` フィールド付きのフラットな配列
  - イベント名: Claude Code / Codex は PascalCase（`PreToolUse`）、Cursor は
    lowerCamelCase かつ粒度が違う（`beforeShellExecution` などツール種別ごとの専用イベント）
  - 出力スキーマ: Claude Code / Codex は `hookSpecificOutput.permissionDecision`、
    Cursor はトップレベルの `permission` / snake_case
  - Codex 固有: プロジェクト hooks は trust（`/hooks` でレビュー・信頼）されるまで
    実行されない。`command` タイプ以外はパースされるが黙ってスキップされる
  - Cursor 固有: デフォルト fail-open（hook 失敗は素通し。`failClosed` で反転）
- この「似て非なる」性質が、学習知識だけで書いたときの事故（別ツールの書式の混入、
  一部ツール分の放棄）の原因。スキルの references を正として参照させる
