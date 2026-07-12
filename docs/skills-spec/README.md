# Skills 仕様調査 — Claude Code / Codex / Cursor

- 調査日: 2026-07-12
- 目的: 3 ツールの Skills 独自仕様を把握し、`shared/skills/` で共有する際に
  差異を吸収する仕組み（将来の ADR）の判断材料にする
- スキルの**配置場所**に関する決定は [ADR-0003](../adr/0003-skill-placement.md) 参照。
  本ディレクトリは配置ではなく **SKILL.md の書式・機能仕様** を扱う

## ドキュメント構成

| ファイル | 内容 |
|---|---|
| [claude-code.md](claude-code.md) | Claude Code の Skills 仕様（拡張フロントマター、動的コンテキスト注入 ほか） |
| [codex.md](codex.md) | Codex の Skills 仕様（`agents/openai.yaml` ほか） |
| [cursor.md](cursor.md) | Cursor の Agent Skills 仕様（Rules との関係 ほか） |

## 共通基盤: Agent Skills オープン標準

3 ツールとも [Agent Skills](https://agentskills.io/specification) オープン標準を基礎にしている。
標準が定めるのは次のとおり:

### ディレクトリ構成

```
skill-name/
├── SKILL.md          # 必須: メタデータ + 指示
├── scripts/          # 任意: 実行可能コード
├── references/       # 任意: 参照ドキュメント
└── assets/           # 任意: テンプレート・静的リソース
```

### SKILL.md フロントマター（標準で定義されるフィールド）

| フィールド | 必須 | 制約 |
|---|---|---|
| `name` | ○ | 最大 64 文字。英小文字・数字・ハイフンのみ。先頭/末尾ハイフン不可、連続ハイフン不可。**親ディレクトリ名と一致すること** |
| `description` | ○ | 最大 1024 文字。「何をするか」と「いつ使うか」の両方を書く |
| `license` | × | ライセンス名か同梱ライセンスファイルへの参照 |
| `compatibility` | × | 最大 500 文字。環境要件（対象製品、必要パッケージ、ネットワーク等）。通常は不要 |
| `metadata` | × | 任意のキー・バリューのマップ。仕様外の追加情報の置き場 |
| `allowed-tools` | × | 事前承認ツールのスペース区切り文字列。**実験的**（対応はツール依存） |

### Progressive disclosure（段階的読み込み）

1. **メタデータ**（約 100 トークン）: `name` + `description` は起動時に全スキル分読み込まれる
2. **本文**（推奨 5000 トークン未満）: スキル発火時に SKILL.md 全体が読み込まれる
3. **リソース**: `scripts/` `references/` `assets/` は必要時のみ

SKILL.md は 500 行未満に保ち、詳細は別ファイルへ切り出すのが推奨。
検証には [`skills-ref validate`](https://github.com/agentskills/agentskills/tree/main/skills-ref) が使える。

## 3 ツール差分の要約

### フロントマター対応表

| フィールド | Claude Code | Codex | Cursor |
|---|---|---|---|
| `name` | ○（省略時ディレクトリ名。表示名にのみ影響） | ○（省略時ディレクトリ名） | ○（必須。フォルダ名と一致） |
| `description` | 推奨（省略時は本文の第 1 段落） | **必須**（欠落はロードエラー） | ○（必須） |
| `metadata` | －（無視） | △（`metadata.short-description` のみ解釈） | ○（任意 k-v） |
| `disable-model-invocation` | ○ | －（openai.yaml の `policy.allow_implicit_invocation` が相当） | ○ |
| `paths`（glob 限定） | ○ | － | ○ |
| `allowed-tools` | ○（発火中の事前承認） | － | － |
| `user-invocable` / `when_to_use` / `argument-hint` / `arguments` / `model` / `effort` / `context` / `agent` / `hooks` / `disallowed-tools` / `shell` | ○（独自拡張） | － | － |

（－ = ドキュメント / 実装上サポートの記述なし。未知フィールドは 3 ツールともエラーにせず無視するのが標準の想定）

### 拡張メカニズムの対応表

| 機能 | Claude Code | Codex | Cursor |
|---|---|---|---|
| 追加設定ファイル | なし（すべてフロントマター） | **`agents/openai.yaml`**（表示・依存・ポリシー） | なし |
| 動的コンテキスト注入 | ○ `` !`cmd` `` / ` ```! ` ブロック | － | － |
| 引数展開 | ○ `$ARGUMENTS` `$0`〜 `$name` ほか | － | － |
| 明示起動の記法 | `/skill-name` | `$skill-name`（`/skills` で一覧） | `/skill-name` |
| description 一覧のコンテキスト予算 | コンテキストの 1%（設定で変更可）。1 件 1536 文字上限 | コンテキストの 2% または 8000 文字 | （公表値なし） |
| 同名スキルの扱い | 階層で上書き（enterprise > personal > project） | マージせず両方列挙 | マージせず両方列挙 |

## ハーネス（shared/skills）への示唆

> この調査を受けた設計判断は [ADR-0009](../adr/0009-skill-graceful-degradation.md)
> （ネイティブ吸収 / graceful degradation 規約）に記録した。規約の機械検査は
> `./check-skills.sh`。以下は判断材料として残す調査時点の所見。

1. **共通部分に寄せるのが基本**: 3 ツール共通で機能するのは
   「`name` + `description` のフロントマター + Markdown 本文 + 相対パス参照の補助ファイル」
   のみ。現行の `harness-check` はこの共通部分に収まっている
2. **description は必ず書く**: Codex ではエラー、他 2 ツールでも自動発火の生命線
3. **Claude Code 拡張（`` !`cmd` `` や `$ARGUMENTS` 等）を共有スキルに書くと、
   Codex / Cursor ではプレースホルダが生テキストとしてモデルに渡る**。
   共有スキルでは使わないか、ツール別に差し替える仕組みが要る
4. **Codex 固有の見た目・ポリシーは `agents/openai.yaml` に分離できる**。
   SKILL.md 本体を汚さないため、共有スキルとの相性は良い
   （他ツールは `agents/` ディレクトリを単なる補助ファイルとして無視する）
5. **`name` はディレクトリ名と一致させ、標準の命名規則（小文字・数字・ハイフン）を守る**。
   Cursor は一致を必須とし、標準のバリデータも要求する

## 情報源

- Agent Skills 標準: <https://agentskills.io/specification>
- Claude Code: <https://code.claude.com/docs/en/skills>
- Codex: <https://developers.openai.com/codex/skills>（learn.chatgpt.com へリダイレクト）、
  実装 <https://github.com/openai/codex/tree/main/codex-rs/core-skills/src>
- Cursor: <https://cursor.com/docs/context/skills>
