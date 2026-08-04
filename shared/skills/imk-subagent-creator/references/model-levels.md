# サブエージェントのモデル階層

- 調査日: 2026-07-30
- 用途: ユーザーがモデルを `最高` / `高` / `中` / `低` で指定したときの選択ポリシー

この階層は異なるベンダーのモデルを客観的に順位付けするものではない。このスキルが
サブエージェント定義を一貫して生成するための、ツール別モデルと推論量の対応表である。

## 対応表

| 階層 | Claude Code | `effort` | Codex | `model_reasoning_effort` | Cursor | OpenCode | `variant` |
|---|---|---|---|---|---|---|---|
| `最高` / `maximum` | `claude-fable-5` | `high` | `gpt-5.6-sol` | `max` | `kimi-k3-high` | `opencode-go/kimi-k3` | `max` |
| `高` / `high` | `claude-opus-5` | `high` | `gpt-5.6-sol` | `high` | `cursor-grok-4.5-high` | `opencode-go/gpt-5.6-luna` | `max` |
| `中` / `medium` | `claude-sonnet-5` | `medium` | `gpt-5.6-terra` | `medium` | `cursor-grok-4.5-medium` | `opencode-go/gpt-5.6-luna` | `xhigh` |
| `低` / `low` | `claude-haiku-4-5` | 省略 | `gpt-5.6-luna` | `low` | `composer-2.5` | `opencode-go/deepseek-v4-flash` | `high` |

Cursor は選択したモデルと推論量に対応する slug を `model` に書き、独立した `effort`
フィールドを追加しない。`composer-2.5` のように推論量を持たない slug もある。
Claude Haiku 4.5 は `effort` に対応しないため、`低`ではモデルだけを書く。

OpenCode の `model` は `provider/model-id` 形式で、**使える provider と model-id は
ユーザーが認証した提供元に依存する**（上表は OpenCode Go のサブスクリプションを使う前提。
Anthropic や OpenAI に直接認証している環境では別の ID になる）。書く前に
`opencode models` で一覧を取り、その中の ID を使う。

推論量は `effort` のような独立フィールドではなく **`variant`** で指定する。
`variant` に書ける値はモデルごとに違い、[models.dev](https://models.dev/api.json) の
`reasoning_options` が正（例: `gpt-5.6-luna` は `none` / `low` / `medium` / `high` /
`xhigh` / `max`、`deepseek-v4-flash` は `high` / `max`、**`kimi-k3` は `max` のみ**）。
`最高`が `max` なのは、Kimi K3 の思考が「最大 effort の on / off」しか持たないため。
**OpenCode は存在しない `variant` を書いてもエラーにせずそのまま保持する**（実機確認）ので、
起動して気づくことはできない。表に無いモデルを使うときは必ず models.dev で
`reasoning_options` を確認する。

## 定義への変換

Claude Code:

```yaml
model: claude-fable-5
effort: high
```

Codex:

```toml
model = "gpt-5.6-sol"
model_reasoning_effort = "max"
```

Cursor:

```yaml
model: kimi-k3-high
```

OpenCode:

```yaml
model: opencode-go/kimi-k3
variant: max
```

対象の階層とツールが変わったら、対応表の同じ行・列から値を選ぶ。階層指定と別に
ユーザーがモデルや推論量を明示した場合は、明示指定を優先する。

## 利用可否とフォールバック

- モデルがプラン、組織ポリシー、認証方式で利用できない場合、別階層へ黙って変更しない。
  利用できない設定と、利用可能な代案をユーザーへ返す
- Claude Fable 5 は 30 日のデータ保持が必要で、ZDR 環境では利用できない。
  Claude Code の `最高`を選ぶときは、この条件をユーザーへ知らせる
- Cursor のモデル一覧はアカウントごとに異なる。Cursor 用定義を書く前に、利用できるなら
  `cursor agent models` を実行し、対応表の slug が一覧にあることを確認する
- OpenCode のモデル一覧は認証した provider に依存する。OpenCode 用定義を書く前に
  `opencode models` を実行し、対応表の `provider/model-id` が一覧にあることを確認する
  （無ければ一覧の中から同階層に相当するものをユーザーと決める。勝手に別階層へ落とさない）。
  `variant` は検証されないため、models.dev の `reasoning_options` にある値かどうかも
  あわせて確認する
- 定義後は新しいセッションで実際に起動し、表示されたモデルと推論量を確認する

## カタログの更新

調査日から 30 日以上経過した場合、またはモデルが認識されない場合は、次の一次情報で
モデル名、ID、推論量を再確認してから対応表と調査日を更新する。

- Claude Code: https://code.claude.com/docs/en/sub-agents
- Claude モデル: https://platform.claude.com/docs/en/home
- Codex: https://developers.openai.com/codex/subagents
- OpenAI モデル: https://developers.openai.com/api/docs/models
- Cursor: https://cursor.com/docs/subagents
- Cursor の実効一覧: `cursor agent models`
- OpenCode: https://opencode.ai/docs/agents/、https://opencode.ai/docs/models/
- OpenCode の実効一覧: `opencode models`
- OpenCode のモデル別 `variant`（`reasoning_options`）: https://models.dev/api.json
