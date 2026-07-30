# Codex カスタムエージェント仕様

- 調査日: 2026-07-30
- 一次情報: https://developers.openai.com/codex/subagents

## 目次

1. [配置とファイル形式](#配置とファイル形式)
2. [必須・任意フィールド](#必須任意フィールド)
3. [モデル・権限・継承](#モデル権限継承)
4. [全体設定](#全体設定)
5. [呼び出しと検証](#呼び出しと検証)
6. [旧形式との区別](#旧形式との区別)

## 配置とファイル形式

| 場所 | スコープ |
|---|---|
| `.codex/agents/<name>.toml` | プロジェクト |
| `~/.codex/agents/<name>.toml` | ユーザー |

1 ファイルが 1 つのカスタムエージェントを定義する。Markdown ではなく、
通常の Codex セッション設定と同じ TOML の設定レイヤーとして読み込まれる。

```toml
name = "code-reviewer"
description = "コード変更の正しさ、セキュリティ、テスト不足をレビューする。"
sandbox_mode = "read-only"

developer_instructions = """
コードオーナーとして変更をレビューする。
具体的な証拠とファイル参照を付け、重要な問題から返す。
スタイルだけの指摘は、実害がある場合を除いて行わない。
"""
```

識別子は `name` フィールド。ファイル名を一致させるのが最も単純だが、必須ではない。

## 必須・任意フィールド

必須:

| フィールド | 意味 |
|---|---|
| `name` | Codex が起動・参照に使うエージェント名 |
| `description` | いつ使うべきかを親へ示す説明 |
| `developer_instructions` | エージェントの中核指示 |

カスタムエージェントは `config.toml` と同じ設定レイヤーなので、必要に応じて
次のような通常設定も書ける。

- `model`
- `model_reasoning_effort`
- `sandbox_mode`
- `[mcp_servers.<name>]`
- `[[skills.config]]`

対応する `config.toml` キーだけを使う。Claude Code の `tools` や Cursor の
`readonly` など、別ツールのフィールドを移植しない。

## モデル・権限・継承

カスタムエージェントファイルに `model` / `model_reasoning_effort` があれば、その値が
最優先される。ファイルで省略した設定は個別に次の順で解決される。

1. 明示的な起動時指定
2. `[agents]` の既定
3. 親セッションの値

モデルだけを変えて推論量が明示されていない場合、そのモデルの既定推論量が使われることがある。
固定する理由が無ければ両方を省略し、親または全体設定を継承する。

`model_reasoning_effort` は `low` / `medium` / `high` / `xhigh` / `max` を基本とし、
対応モデルとアカウントでは `ultra` も使える。モデルごとに対応範囲が異なるため、
実行時の表示でも確認する。

ツール非依存のモデル階層から選ぶ場合は `references/model-levels.md` の Codex 列を使う。
現行 GPT-5.6 系の正規 ID は、能力優先が `gpt-5.6-sol`、バランス型が
`gpt-5.6-terra`、速度・コスト優先が `gpt-5.6-luna`。

`sandbox_mode = "read-only"` で読み取り専用の既定を与えられる。省略した
`sandbox_mode` / MCP / スキル設定は親から継承する。

ただし、親ターンで対話的に選んだ permissions / sandbox / `--yolo` などの
実行時上書きは子の起動時にも再適用される。非対話実行で新しい承認を表示できない場合、
承認が必要な操作は失敗する。定義ファイルだけを見て実効権限を断定しない。

## 全体設定

並列数や既定モデルは `.codex/config.toml` または `~/.codex/config.toml` の
`[agents]` に置く。

```toml
[agents]
enabled = true
max_concurrent_threads_per_session = 6
# default_subagent_model = "..."
# default_subagent_reasoning_effort = "medium"
```

主なフィールド:

| フィールド | 意味 |
|---|---|
| `enabled` | multi-agent ツールの有効化。既定は true |
| `max_concurrent_threads_per_session` | メイン以外で同時に開けるスレッド上限 |
| `default_subagent_model` | 子の既定モデル |
| `default_subagent_reasoning_effort` | 子の既定推論量 |
| `interrupt_message` | 中断時にモデル可視メッセージを残すか |

`max_threads` は `max_concurrent_threads_per_session` のレガシー別名。
新規設定では現行名を使う。カスタム名が組み込みの `default` / `worker` / `explorer`
と重なると、カスタム定義が優先されるため意図せず上書きしない。

## 呼び出しと検証

Codex は明示的な依頼、または適用される AGENTS.md / スキルの指示を受けて委譲する。
カスタムエージェント名を指定した自然言語で、最初に小さな代表タスクを試す。

```text
code-reviewer を使って、このブランチの変更を読み取り専用でレビューして。
```

CLI では `/agent` または `/subagents` からスレッドを確認できる。検証時は次を見る。

- `name` と `description` が親から認識される
- 指定したカスタムエージェントが実際に選ばれる
- モデル / 推論量 / sandbox が期待どおりか
- 親へ返す結果が `developer_instructions` の形式に従うか

## 旧形式との区別

設定リファレンスには、`config.toml` で `[agents.<role>]` に `description` と
`config_file` を登録する形式も残っている。

```toml
[agents.reviewer]
description = "..."
config_file = "./agents/reviewer.toml"
```

現行の Subagents ガイドは `.codex/agents/*.toml` の単独ファイルを新規作成方法として
案内しているため、新規定義は単独ファイル方式を使う。既存プロジェクトが登録方式を
採用している場合は、目的なく混在・移行せず、そのプロジェクトの動作を確認して合わせる。
カスタムエージェント形式は成熟途中と公式にも記載されているため、挙動が食い違ったら
一次情報と対象 Codex バージョンを確認する。
