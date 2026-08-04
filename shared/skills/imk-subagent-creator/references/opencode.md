# OpenCode カスタムサブエージェント仕様

- 調査日: 2026-08-04
- 一次情報: <https://opencode.ai/docs/agents/>、ローカルの opencode 1.18.12

## 目次

1. [配置と優先順位](#配置と優先順位)
2. [ファイル形式とフィールド](#ファイル形式とフィールド)
3. [モデル・権限](#モデル権限)
4. [呼び出しと検証](#呼び出しと検証)

## 配置と優先順位

| 場所 | スコープ |
|---|---|
| `.opencode/agents/<name>.md`（`.opencode/agent/` も可） | プロジェクト |
| `~/.config/opencode/agents/<name>.md`（`agent/` も可） | ユーザー |

- 他ツール（`.claude/agents/` 等）の互換走査は**無い**。OpenCode 向けには必ず
  上記のネイティブ位置に置く
- ファイル名（`.md` を除く）がエージェント名になる。frontmatter の `name` も
  書けるが、ファイル名と揃える
- 定義は `opencode.json` の `agent` キーに JSON で書くこともできるが、
  自明でない定義はファイル形式を推奨（公式の指針）

## ファイル形式とフィールド

YAML frontmatter + Markdown 本文。**本文がそのままプロンプトになる**
（frontmatter に `prompt:` を書かない）。

```markdown
---
description: 認証・決済・機密データを扱う変更時にセキュリティを監査する
mode: subagent
permission:
  edit: deny
  bash: deny
---

セキュリティ上重要な経路を特定し、根拠と重要度を付けて問題を返す。
コードは変更しない。
```

| フィールド | 必須 | 意味 |
|---|---:|---|
| `description` | ○ | 何をする役割か・いつ委譲すべきか。自動委譲の判断材料 |
| `mode` | × | `primary` / `subagent` / `all`（既定は `all`）。サブエージェント定義は `subagent` を明示する |
| `model` | × | `provider/model-id` 形式（例: `anthropic/claude-sonnet-4-6`）。省略時、サブエージェントは呼び出し元のモデルを継承 |
| `variant` | × | そのモデルの推論量プリセット（`high` / `max` / `xhigh` 等。値はモデルごとに違う）。`model` を指定したときだけ効く |
| `permission` | × | ツールごとの `allow` / `ask` / `deny`。パターン指定可 |
| `hidden` | × | `true` で `@` オートコンプリートから隠す（Task ツールからは呼べる） |
| `steps` | × | エージェントの最大反復回数 |
| `options` | × | プロバイダ固有のモデルオプション（OpenAI 系の `reasoningEffort`、Anthropic 系の `thinking.budgetTokens` 等） |
| `temperature` / `top_p` / `color` / `disable` | × | 補助オプション |

- **未知フィールドはエラーにならず `options` へ黙って吸い込まれる**（実機確認:
  `readonly: true` と書くと `options: { readonly: true }` になり、権限は変わらない）。
  他ツールのフィールド（`readonly` / `is_background` / `effort` 等）を混ぜないこと。
  誤りが起動時に発覚しないため、`scripts/validate-agent.sh opencode` で機械検査する
- frontmatter に `prompt:` を書いても本文が優先される（実機確認）。指示は本文に書く
- `tools` フィールドは非推奨。`permission` を使う

## モデル・権限

- **親モデル継承**: `model` を省略する（サブエージェントは呼び出し元プライマリの
  モデルを使う）
- **推論量の固定**: `effort` のような独立フィールドは無く、`variant` にモデルごとの
  プリセット名を書く。書ける値はモデル依存で、**存在しない値を書いてもエラーにならず
  そのまま保持される**（実機確認）。階層指定からの変換は `references/model-levels.md` に従う
- **読み取り専用**: `permission` で `edit: deny`、必要に応じて `bash: deny`。
  一括の `readonly` フィールドは無い
- **委譲制御**: 親側の `permission.task`（glob パターン）で、呼び出せる
  サブエージェントを制限できる
- **バックグラウンド固定**: 定義ファイルの共通フィールドは無い
- ビルトイン（`build` / `plan` / `general` / `explore`）は同名キー・同名ファイルで
  上書きできる

## 呼び出しと検証

- 明示起動: メッセージで `@agent-name` とメンション
- 自動委譲: プライマリエージェントが description を見て Task ツールで呼ぶ
- 検証: `opencode debug agent <name>` で解決された設定を確認する。
  設定変更は再起動後に反映される（ホットリロードされない）
