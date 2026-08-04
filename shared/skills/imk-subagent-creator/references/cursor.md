# Cursor カスタムサブエージェント仕様

- 調査日: 2026-07-30
- 一次情報: https://cursor.com/docs/subagents

## 目次

1. [配置と優先順位](#配置と優先順位)
2. [ファイル形式とフィールド](#ファイル形式とフィールド)
3. [モデル・権限・バックグラウンド](#モデル権限バックグラウンド)
4. [コンテキストとツール](#コンテキストとツール)
5. [呼び出しと検証](#呼び出しと検証)

## 配置と優先順位

Cursor はネイティブ定義に加え、Claude Code / Codex の互換配置も走査する。

| 場所 | スコープ |
|---|---|
| `.cursor/agents/` | プロジェクト（Cursor ネイティブ） |
| `.claude/agents/` | プロジェクト（Claude Code 互換） |
| `.codex/agents/` | プロジェクト（Codex 互換） |
| `~/.cursor/agents/` | ユーザー（Cursor ネイティブ） |
| `~/.claude/agents/` | ユーザー（Claude Code 互換） |
| `~/.codex/agents/` | ユーザー（Codex 互換） |

- ユーザー定義よりプロジェクト定義が優先される
- 同名なら `.cursor/` が `.claude/` / `.codex/` より優先される
- 複数ツール向けにそれぞれ定義を置く場合、Cursor 用を `.cursor/agents/` に置けば
  Cursor がどれを使うか明確になる

## ファイル形式とフィールド

Cursor ネイティブ定義は YAML frontmatter + Markdown 本文。

```markdown
---
name: security-auditor
description: 認証・決済・機密データを扱う変更時にセキュリティを監査する
model: inherit
readonly: true
is_background: false
---

セキュリティ上重要な経路を特定し、根拠と重要度を付けて問題を返す。
コードは変更しない。
```

| フィールド | 必須 | 既定 | 意味 |
|---|---:|---|---|
| `name` | No | ファイル名 | 表示名・識別子。英小文字とハイフンを推奨 |
| `description` | No | なし | Task ツールのヒント。自動委譲の判断材料 |
| `model` | No | `inherit` | 親モデル継承またはモデル ID |
| `readonly` | No | `false` | ファイル編集・状態変更コマンドを制限 |
| `is_background` | No | `false` | 親をブロックせずバックグラウンド実行 |

公式上 `name` / `description` は省略可能だが、複数ツールでの一貫性と委譲精度のため
明示する。Claude Code の `background` ではなく `is_background` である点に注意する。

## モデル・権限・バックグラウンド

`model: inherit` または省略で親モデルを使う。モデル ID を固定でき、モデルごとの
速度・推論量・コンテキスト等のパラメータを角括弧で付けられる。Cursor のモデル一覧では
推論量を含む slug も提供される。カスタムサブエージェントには一覧の完全な slug を
`model` に書き、独立した `effort` フィールドを追加しない。`composer-2.5` のように
推論量を持たない slug では、モデルだけを固定する。

ツール非依存のモデル階層から選ぶ場合は `references/model-levels.md` の Cursor 列を使う。
対象アカウントで `cursor agent models` を実行できるなら、定義前に slug の存在を確認する。
利用できる ID とパラメータは変化するため、固定時は現在のモデル一覧を確認する。

次の場合、Cursor は設定モデルを別の互換モデルへフォールバックする。

- チーム管理者が対象モデルを禁止している
- 現在のプランで利用できない
- 旧リクエスト制プランで必要な Max Mode が有効でない

`readonly: true` は書き込みを制限する。実際にどのコマンドが許可されるかは
親セッションのモード・sandbox・組織設定にも依存するため、代表タスクで確認する。

`is_background: true` は長時間処理や並列ワークストリーム向け。親が次へ進む前に
結果を必要とする役割では `false` のままにする。

## コンテキストとツール

- サブエージェントは独立した新しいコンテキストで始まり、親の過去の会話履歴を持たない
- 親が必要な文脈を委譲 prompt に含める
- サブエージェントは親から MCP を含むツールを継承する
- Cloud subagent は例外で、ローカル MCP でなくチームの Cloud Agents 設定を使う
- Cursor 2.5 以降は深さ制限内で子サブエージェントを起動できるが、Task ツールや
  hooks / tool policy で禁止されることがある
- バックグラウンドサブエージェントの状態は `~/.cursor/subagents/` に書かれる

読み取り専用だから不要な MCP ツールまで見えなくなるとは限らない。
機密性や副作用が重要な場合は、親の MCP / sandbox / hooks 側も確認する。

## 呼び出しと検証

明示呼び出し:

```text
/security-auditor 決済モジュールの変更を監査して
```

自然言語で「security-auditor を使って」と指定することもできる。
自動委譲はタスクの複雑さ、スコープ、カスタム定義の `description`、現在の文脈で決まる。
自動利用を期待する場合は `description` に具体的な対象とタイミングを書く。

検証では次を見る。

1. 明示呼び出しで定義が発見される
2. `model` の実効値が期待どおりか
3. `readonly` / `is_background` が実際に効くか
4. 独立コンテキストでも必要な入力を受け取り、所定の結果を返せるか
5. 自動委譲と near-miss の境界が適切か

認識されない場合は配置、同名定義の優先順位、現在のモデル / プランで Task ツールが
利用可能かを確認し、新しいセッションでも再試行する。
