---
name: imk-subagent-creator
description: Claude Code / Codex / Cursor / OpenCode のカスタムサブエージェント定義を作成・修正・検証する。ツールごとに異なる配置場所、Markdown / TOML 形式、モデル・権限・バックグラウンド設定の正確な参照資料とテンプレートを含む。ユーザーが「サブエージェントを作って」「レビュー担当や調査担当を定義して」「.claude/agents・.codex/agents・.cursor/agents・.opencode/agents を整備して」と依頼したとき、既存のカスタムエージェントが発見・起動・委譲されない問題を調べるとき、複数ツール向けに同じ役割を揃えるときは必ずこのスキルを使う。単に今回の作業をサブエージェントへ委譲するだけで、再利用する定義ファイルを作らない依頼には使わない。
---

# imk-subagent-creator — 4 ツールのサブエージェント定義作成

Claude Code / Codex / Cursor / OpenCode のカスタムサブエージェント定義を作成・修正する。
4 ツールとも「独立したコンテキストで専門タスクを実行し、親へ結果を返す」仕組みだが、
**定義形式・設定フィールド・呼び出し方は異なる**。共通の役割を先に設計し、
各ツールのネイティブ形式へ個別に変換する。

**定義を書く前に、対象ツールの参照資料を必ず読む。**

- Claude Code → `references/claude-code.md`
- Codex → `references/codex.md`
- Cursor → `references/cursor.md`
- OpenCode → `references/opencode.md`
- `最高` / `高` / `中` / `低`のモデル階層を使う → `references/model-levels.md`

## 手順

### 1. 用途・対象・スコープを確認する

次を会話とプロジェクトから特定し、結果を変える情報だけが不足していればユーザーに確認する。

- 担当させる仕事と、実際の利用例 2〜3 件
- 親エージェントがいつ委譲すべきか。明示呼び出し専用か、自動委譲も期待するか
- 期待する返却物と完了条件
- 対象ツール（Claude Code / Codex / Cursor / OpenCode）
- プロジェクト共有か、ユーザー個人用か
- 読み取り専用か、編集・コマンド実行を許すか
- 親のモデルを継承するか、`最高` / `高` / `中` / `低`の階層または特定モデルを使うか
- 同時実行、バックグラウンド、永続メモリ、MCP、スキル事前読込などが本当に必要か

配置先:

| スコープ | Claude Code | Codex | Cursor | OpenCode |
|---|---|---|---|---|
| プロジェクト | `.claude/agents/<name>.md` | `.codex/agents/<name>.toml` | `.cursor/agents/<name>.md` | `.opencode/agents/<name>.md` |
| ユーザー | `~/.claude/agents/<name>.md` | `~/.codex/agents/<name>.toml` | `~/.cursor/agents/<name>.md` | `~/.config/opencode/agents/<name>.md` |

ユーザー個人用ファイルを作るときは、ホームへ直接置くか、原本リポジトリで管理して
展開するかを確認する。管理リポジトリがあれば原本側を編集する。

### 2. サブエージェントが適切か判定する

次のいずれかに当てはまる役割へ使う。

- 調査ログなどの大量の中間出力を親のコンテキストから隔離したい
- 独立した複数の仕事を並列化したい
- 読み取り専用など、親より狭い権限や道具で専門化したい
- 同じ専門家役を複数のタスクで繰り返し使う
- 実装とは別の視点で独立検証したい

1 回で終わる短い定型処理はスキル、常に守るプロジェクト規約は CLAUDE.md / AGENTS.md、
機械的な強制は hooks を使う。サブエージェント起動の順序や結果の引き継ぎ自体が
再利用ワークフローなら、親向けスキルにオーケストレーションを書き、
各サブエージェント定義には自分の役割だけを書き分ける。

### 3. 共通の役割契約を設計する

ツール別ファイルを書く前に、次の共通部分を決める。

1. **名前** — 複数ツールで揃えるなら英小文字とハイフンだけの短い名前にする
2. **description** — 何をする役割かと、親がいつ委譲すべきかを書く。隣接する役割との境界も示す
3. **責務** — 自分が判断・調査・変更する範囲
4. **非責務** — 親へ戻す判断、変更してはいけない対象
5. **作業方法** — 必要な証拠、検証、停止条件
6. **返却形式** — 親が次の判断に使える、短く明確な結果

親の会話履歴がそのまま見える前提にしない。毎回変わる対象・入力は親からの委譲メッセージで
渡させ、定義ファイルには繰り返し使う役割・制約・返却形式だけを書く。

### 4. モデルと推論量を選ぶ

ユーザーがモデル階層を指定したら `references/model-levels.md` を読み、対象ツールの
正規モデル ID と推論量へ変換する。たとえば「最高モデルで」と言われた場合、
Claude Code / Codex / Cursor / OpenCode で同じ文字列を使わず、対応表の各ツール列を使う。

- モデル指定が無ければ、親モデルと推論量の継承を既定にする
- 階層と別にモデルまたは推論量が明示されたら、その明示指定を優先する
- Cursor はモデル一覧の完全な slug を使い、独立した `effort` を書かない
- モデルが利用できなければ別モデルへ黙って変更せず、利用できない設定と代案を返す
- 固定後は実行時表示でモデルと推論量を確認する

### 5. 対象ツールの形式へ変換する

対象ツールの参照資料とテンプレートを使う。

- Claude Code: `templates/claude-code-agent.md.template`
- Codex: `templates/codex-agent.toml.template`
- Cursor: `templates/cursor-agent.md.template`
- OpenCode: `templates/opencode-agent.md.template`

複数ツール向けではネイティブファイルをそれぞれ作る。Cursor は `.claude/agents/` と
`.codex/agents/` も互換スキャンするが、同名定義が複数見える場合の意図を明確にするため
`.cursor/agents/` に Cursor 用を置く（Cursor 用が優先される）。OpenCode は他ツールの
配置を互換スキャンしないため、必ずネイティブ位置に置く。

設定を機械的にコピーしない。特に次はツール固有である。

| 意図 | Claude Code | Codex | Cursor | OpenCode |
|---|---|---|---|---|
| 指示本文 | Markdown 本文 | `developer_instructions` | Markdown 本文 | Markdown 本文（frontmatter 後がそのまま prompt） |
| 親モデルを継承 | `model: inherit` または省略 | `model` を省略 | `model: inherit` または省略 | `model` を省略 |
| 推論量を固定 | `effort` | `model_reasoning_effort` | 対応する `model` slug | `variant`（値はモデルごとに違う） |
| 読み取り専用 | `tools` / `disallowedTools` / `permissionMode` | `sandbox_mode = "read-only"` | `readonly: true` | `permission` で `edit: deny`（必要なら `bash: deny`） |
| 常時バックグラウンド | `background: true` | 定義ファイルの共通フィールドなし | `is_background: true` | 定義ファイルの共通フィールドなし |

モデル名・利用可否・推論量は変化しやすい。ユーザーに理由が無ければ継承を既定にし、
固定する場合は対象ツールの現在のモデル一覧を確認する。秘密情報や認証情報を定義へ書かない。

### 6. 機械検査する

スキルディレクトリを基準に、対象ファイルごとに実行する。

```sh
scripts/validate-agent.sh claude-code .claude/agents/<name>.md
scripts/validate-agent.sh codex .codex/agents/<name>.toml
scripts/validate-agent.sh cursor .cursor/agents/<name>.md
scripts/validate-agent.sh opencode .opencode/agents/<name>.md
```

フロントマター / TOML の必須項目、命名、本文、別ツールの代表的なフィールド混入を検査する。
エラーを直して再実行し、通るまで繰り返す。

### 7. 実地テストする

新しいセッションで次を順に試す。

1. **発見** — 対象ツールが名前と description を認識する
2. **明示起動** — 名前を指定して小さな代表タスクを依頼する
3. **権限** — 読み取り専用なら書き込みを行わず、必要な道具だけが使える
4. **返却** — 定義した形式で、親が利用できる結果を返す
5. **自動委譲** — 期待する場合だけ、名前を出さない代表クエリでも選ばれるか確認する
6. **near-miss** — 隣接するが対象外の依頼で誤って選ばれないか確認する

モデルや権限には組織ポリシー、親セッション、プランによる上書きがある。
設定ファイルの記述だけで保証されたと判断せず、実行時の表示と実際の挙動を確認する。

## 既存定義の修正

- まず対象ツールの参照資料を読み、別ツールのフィールドが混ざっていないか確認する
- 名前の変更は呼び出し側を壊すため、必要性と参照箇所を調べてから行う
- description が広すぎる / 狭すぎる場合は、実際の発火・不発火クエリから境界を書き直す
- 役割が複数ある定義は分割する。ただし曖昧な汎用役を大量に増やさない
- 仕様どおりに書いても動かない場合は、参照資料記載の一次情報を確認し、
  仕様変更なら参照資料も更新する
