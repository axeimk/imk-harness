# Codex の Skills 仕様

- 調査日: 2026-07-12
- 一次情報: <https://developers.openai.com/codex/skills>（learn.chatgpt.com/docs/build-skills へ
  リダイレクト）、実装
  [`codex-rs/core-skills/src/model.rs`](https://github.com/openai/codex/blob/main/codex-rs/core-skills/src/model.rs)・
  [`loader.rs`](https://github.com/openai/codex/blob/main/codex-rs/core-skills/src/loader.rs)
- 位置づけ: SKILL.md のフロントマターは**最小限**（実質 `name` / `description` のみ）。
  独自拡張は別ファイル **`agents/openai.yaml`** に分離するのが特徴

## 配置場所と優先順位（loader.rs より）

| スコープ | パス | 備考 |
|---|---|---|
| Repo | `$CWD` からリポジトリルートまでの各祖先の `.agents/skills/` | プロジェクト用 |
| User | `~/.agents/skills/` | 公式のユーザー配置 |
| User | `$CODEX_HOME/skills/`（= `~/.codex/skills/`） | **非推奨**（後方互換のため残置） |
| System | `$CODEX_HOME/skills/.system/` | 組み込み |
| Admin | `/etc/codex/skills/` | システム管理者向け |

- 同名スキルはマージされず**両方が候補に列挙される**（重複表示）
- プラグイン由来・追加設定由来のスキルルートも合流する

## SKILL.md フロントマター（実装がパースするフィールド）

| フィールド | 必須 | 制約・挙動 |
|---|---|---|
| `name` | × | 省略時は親ディレクトリ名。最大 64 文字 |
| `description` | **○** | 欠落はロードエラー。最大 1024 文字 |
| `metadata.short-description` | × | 短い説明。最大 1024 文字 |

- 各フィールドは単一行に正規化される（連続空白は 1 スペースに）
- YAML パース失敗時は修復を試みる（コロンを含むスカラ値のクオート補完等）
- 上記以外のフィールド（Claude Code の `allowed-tools` 等）は解釈されない

## `agents/openai.yaml`（Codex 独自の追加設定）

スキルディレクトリ内の `agents/openai.yaml` に置く。無ければ黙って無視される
（他ツールからは単なる補助ファイルに見えるため、共有スキルに同梱しても無害）。

> 注: ファイル名は `openai.yaml`（`openai.yml` ではない）。パスは
> `<skill>/agents/openai.yaml` 固定。

```
my-skill/
├── SKILL.md
└── agents/
    └── openai.yaml
```

### `interface` セクション — 表示・見た目

| フィールド | 型 | 説明 |
|---|---|---|
| `display_name` | string | ユーザー向け表示名 |
| `short_description` | string | 短い説明 |
| `icon_small` | path | 小アイコン（SVG 推奨） |
| `icon_large` | path | 大アイコン（PNG 推奨） |
| `brand_color` | string | ブランドカラー（16 進） |
| `default_prompt` | string | スキル選択時の既定プロンプト |

### `policy` セクション — 発火ポリシー

| フィールド | 型 | デフォルト | 説明 |
|---|---|---|---|
| `allow_implicit_invocation` | bool | `true` | `false` で暗黙発火（description マッチ）を禁止し、明示的な `$skill` 呼び出しのみにする。Claude Code / Cursor の `disable-model-invocation: true` に相当 |
| `products` | list | 空 | 対象製品の限定 |

### `dependencies` セクション — 依存ツール（MCP 等）

`tools` の配列。各要素:

| フィールド | 必須 | 説明 |
|---|---|---|
| `type` | ○ | ツール種別（`mcp` 等） |
| `value` | ○ | ツール識別子 |
| `description` | × | 説明 |
| `transport` | × | 転送方式（`streamable_http` 等） |
| `command` | × | 起動コマンド |
| `url` | × | URL |

## 起動メカニズム

- **明示起動**: `$skill-name` 記法、または `/skills` からの選択
- **暗黙起動**: `description` がタスクにマッチすると Codex が自動選択。
  description の冒頭に主要ユースケースとトリガーワードを置くことが推奨される
- description 一覧は**コンテキストの最大 2%（不明時 8000 文字）**に制限。
  発火後に SKILL.md 全文がロードされる
- 変更は自動検出されるが、反映されない場合は再起動が必要

## ハーネスへの含意

- 共有スキルは `name` + `description` + Markdown 本文で書けば Codex でそのまま動く
- Codex にだけ見た目や発火ポリシーを指定したければ `agents/openai.yaml` を
  同梱すればよく、SKILL.md 側に非互換を持ち込まずに済む
- Claude Code の `disable-model-invocation: true` に相当する制御は、Codex では
  `agents/openai.yaml` の `policy.allow_implicit_invocation: false` で表現する
  （フロントマターだけでは伝わらない点に注意）
