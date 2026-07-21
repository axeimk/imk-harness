# Cursor hooks 仕様

- 調査日: 2026-07-21
- 一次情報: https://cursor.com/docs/hooks

## 目次

1. [設定ファイルと構造](#設定ファイルと構造)
2. [イベント一覧](#イベント一覧)
3. [matcher](#matcher)
4. [入出力プロトコル](#入出力プロトコル)
5. [代表イベントの入出力](#代表イベントの入出力)
6. [注意点](#注意点)

## 設定ファイルと構造

| 場所 | スコープ | スクリプトの実行ディレクトリ |
|---|---|---|
| `<project>/.cursor/hooks.json` | プロジェクト | プロジェクトルート |
| `~/.cursor/hooks.json` | ユーザー | `~/.cursor/` |

**Claude Code / Codex と構造が違う**: `version` フィールドが必要で、イベント名は
lowerCamelCase、matcher グループのネストが無いフラットな配列:

```json
{
  "version": 1,
  "hooks": {
    "afterFileEdit": [
      { "command": ".cursor/hooks/format.sh" }
    ],
    "beforeShellExecution": [
      { "command": ".cursor/hooks/check-net.sh", "matcher": "curl|wget|nc" }
    ]
  }
}
```

エントリごとのフィールド:

| フィールド | 意味 |
|---|---|
| `command` | 必須。スクリプトパスまたはシェルコマンド |
| `type` | `command`（デフォルト）または `prompt`（LLM に可否を判定させる） |
| `timeout` | 秒 |
| `matcher` | フィルタ（イベントにより意味が違う。後述） |
| `failClosed` | `true` で hook 失敗時にブロック（デフォルトは fail-open = 素通し） |

## イベント一覧

エージェント系の主要イベント:

| イベント | 発火タイミング | 主用途 |
|---|---|---|
| `sessionStart` / `sessionEnd` | セッション開始 / 終了 | 文脈注入・環境変数 / ログ |
| `preToolUse` / `postToolUse` / `postToolUseFailure` | ツール実行前 / 成功後 / 失敗後 | 汎用の検査・監査 |
| `beforeShellExecution` / `afterShellExecution` | シェル実行前 / 後 | コマンドの許可制御・監査 |
| `beforeMCPExecution` / `afterMCPExecution` | MCP 実行前 / 後 | MCP の許可制御・監査 |
| `beforeReadFile` | ファイル読み取り前 | 機密ファイルの読み取り制御 |
| `afterFileEdit` | ファイル編集後 | lint・format・ステージング |
| `beforeSubmitPrompt` | プロンプト送信前 | 検査・ブロック |
| `stop` | エージェントループ完了 | 完了検査・追撃メッセージ |
| `preCompact` | 圧縮前 | 観測のみ |
| `subagentStart` / `subagentStop` | サブエージェント開始 / 終了 | サブエージェント制御 |
| `afterAgentResponse` / `afterAgentThought` | 応答 / 思考の完了 | 出力の記録 |

ほかに Tab（インライン補完）専用の `beforeTabFileRead` / `afterTabFileEdit`、
アプリ起動系の `workspaceOpen` がある。

## matcher

イベントにより意味が変わる:

- `beforeShellExecution` / `afterShellExecution`: コマンド文字列全体への正規表現
- `preToolUse` / `postToolUse` 等: ツール種別（`Shell`, `Read`, `Write`, `Task`, `MCP:<tool>` など）
- `afterFileEdit`: 編集元種別（`Write`, `TabWrite` など）
- `subagentStart` / `subagentStop`: サブエージェント種別

## 入出力プロトコル

**stdin**（共通フィールド。イベントごとに追加あり）:

```json
{
  "conversation_id": "...",
  "generation_id": "...",
  "hook_event_name": "beforeShellExecution",
  "workspace_roots": ["/path/to/project"],
  "cursor_version": "...",
  "transcript_path": null
}
```

**exit code**: 0 = 成功（stdout の JSON を使用）、2 = ブロック（`permission: "deny"` 相当）、
その他 = hook 失敗。**失敗はデフォルトで素通し**（`failClosed: true` で反転）。

環境変数 `CURSOR_PROJECT_DIR`（ワークスペースルート）等がスクリプトに渡る。

## 代表イベントの入出力

**出力フィールド名が Claude Code / Codex と異なる**（`hookSpecificOutput` や
`permissionDecision` ではなく、トップレベルの `permission` / snake_case）ことに注意。

**beforeShellExecution** — stdin に `command` / `cwd`。出力:

```json
{
  "permission": "allow | deny | ask",
  "user_message": "ユーザー向け表示（任意）",
  "agent_message": "エージェント向けフィードバック（任意）"
}
```

**preToolUse** — stdin に `tool_name` / `tool_input`。出力は `permission` に加えて
`updated_input`（入力書き換え）が使える。

**beforeReadFile** — stdin に `file_path` / `content`。出力は `permission: "allow" | "deny"`。

**afterFileEdit** — stdin に `file_path` と `edits`（`old_string` / `new_string` の配列）。
出力は空でよい（後処理専用）。

**beforeSubmitPrompt** — stdin に `prompt`。出力は `{"continue": false, "user_message": "..."}`
でブロック。

**stop** — stdin に `status` / `loop_count`。出力の `followup_message` で
エージェントに追加ターンを促せる（暴走防止に `loop_limit` がある。デフォルト 5）。

**sessionStart** — 出力の `additional_context` で文脈注入、`env` でセッション内の
後続 hook に環境変数を渡せる。

## 注意点

- `hooks.json` は保存時に自動リロードされるが、反映されないときは Cursor を再起動する
- Cloud Agents では command タイプの一部イベントのみ動く（`sessionStart` /
  MCP 系 / Tab 系 / ユーザースコープ hooks は使えない）
- `type: "prompt"`（自然言語ポリシー）はローカル専用。確実性が要る検査は command で書く
