# Cursor の Agent Skills 仕様

- 調査日: 2026-07-12
- 一次情報: <https://cursor.com/docs/context/skills>
- 位置づけ: Agent Skills 標準にほぼ忠実で、独自拡張は少ない。
  特徴は**他ツールのディレクトリまで互換スキャンする**ことと、
  既存の Rules / Commands 機能との住み分け

## 配置場所

| 種別 | プロジェクト | ユーザー |
|---|---|---|
| ネイティブ | `.agents/skills/`、`.cursor/skills/` | `~/.agents/skills/`、`~/.cursor/skills/` |
| 互換（third-party） | `.claude/skills/`、`.codex/skills/` | `~/.claude/skills/`、`~/.codex/skills/` |

- 互換スキャンは IDE の Settings > Rules, Skills, Subagents >
  「Include third-party Plugins, Skills, and other configs」で無効化できる。
  ネイティブ側は設定に関係なく常に読まれる。cursor-agent CLI はこの設定を参照しない
  （詳細と配置方針の決定は [ADR-0003](../adr/0003-skill-placement.md)）
- 同名スキルはマージされず重複表示になる
- ネスト対応: `.cursor/skills/category/skill-name/SKILL.md` のようにカテゴリフォルダを
  挟める（識別子は SKILL.md を含むフォルダ名。中間フォルダ名は無視）。
  モノレポでは各パッケージ内の skills ディレクトリも検出され、
  そのディレクトリ配下の作業に自動でスコープされる

## SKILL.md フロントマター

| フィールド | 必須 | 説明 |
|---|---|---|
| `name` | ○ | 英小文字・数字・ハイフンのみ。**親フォルダ名と一致必須** |
| `description` | ○ | 何をするか・いつ使うか。自動発火の判定材料 |
| `paths` | × | glob パターン（カンマ区切り文字列またはリスト）。一致するファイルを扱うときにスキルを限定適用 |
| `disable-model-invocation` | × | `true` で自動適用を無効化し、明示的な `/skill-name` 呼び出し専用（従来のスラッシュコマンド相当）にする |
| `metadata` | × | 任意のキー・バリュー |

Claude Code の `allowed-tools` / `context` / `agent` / 引数展開などには対応の記述がない。

## ディレクトリ構成

標準どおり。`SKILL.md` 必須、`scripts/` `references/` `assets/` 任意。

## 起動メカニズム

- **自動**: エージェントが文脈と `description` から関連性を判定して適用
- **明示**: チャットで `/` を打ってスキル名を検索・実行
- `disable-model-invocation: true` の場合は明示起動のみ

## Rules / Commands との関係

Cursor には Skills 以前から Rules（`.cursor/rules`）と Commands（スラッシュコマンド）が
あり、Skills と役割が重なる。公式の `/migrate-to-skills` スキルが移行を支援する:

- 「Apply Intelligently」設定のルール（`alwaysApply: false` かつ globs 未指定）
  → 通常のスキルへ変換
- ユーザー / ワークスペースのスラッシュコマンド
  → `disable-model-invocation: true` のスキルへ変換
- `alwaysApply: true` のルールや globs 指定ルールは移行対象外
  （常時適用は Rules に残す。ファイル限定は Skills の `paths` が近い機能）

## ハーネスへの含意

- フロントマターは標準 + `paths` + `disable-model-invocation` のみで、
  この 2 つは Claude Code と同名・同義。**Claude Code 向けに書いたスキルは
  Cursor では概ねそのまま動く**（Claude Code 独自フィールドは無視される想定）
- ただし Claude Code の動的コンテキスト注入（`` !`cmd` ``）や `$ARGUMENTS` は
  Cursor では展開されず生テキストになるため、共有スキルでは使わない
- `name` とフォルダ名の一致は Cursor が最も厳格。共有スキルは標準の命名規則に従うこと
