# Claude Code hooks 仕様

- 調査日: 2026-07-21
- 一次情報: https://code.claude.com/docs/en/hooks

## 目次

1. [設定ファイルと構造](#設定ファイルと構造)
2. [イベント一覧](#イベント一覧)
3. [matcher](#matcher)
4. [ハンドラの種類](#ハンドラの種類)
5. [入出力プロトコル](#入出力プロトコル)
6. [代表イベントの入出力](#代表イベントの入出力)
7. [環境変数と注意点](#環境変数と注意点)

## 設定ファイルと構造

| 場所 | スコープ |
|---|---|
| `~/.claude/settings.json` | ユーザー（全プロジェクト） |
| `.claude/settings.json` | プロジェクト（コミット共有可） |
| `.claude/settings.local.json` | プロジェクト個人用（gitignore 対象） |

構造は「イベント名 → matcher グループの配列 → hooks 配列」の 2 段ネスト:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/lint.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

## イベント一覧

日常的に使う主要イベント:

| イベント | 発火タイミング | 主用途 |
|---|---|---|
| `PreToolUse` | ツール実行前 | 検査・ブロック・入力書き換え |
| `PostToolUse` | ツール成功後 | lint / format、結果の検査 |
| `PostToolUseFailure` | ツール失敗後 | 失敗時の後処理 |
| `PermissionRequest` | 許可ダイアログ表示時 | 自動許可 / 拒否 |
| `UserPromptSubmit` | プロンプト処理前 | 検査・文脈追加・ブロック |
| `SessionStart` | セッション開始・再開 | 文脈注入・環境準備 |
| `SessionEnd` | セッション終了 | 後片付け・ログ |
| `Stop` | 応答完了時 | 完了条件の検査・継続強制 |
| `SubagentStart` / `SubagentStop` | サブエージェント開始 / 終了 | サブエージェント制御 |
| `PreCompact` / `PostCompact` | コンテキスト圧縮前 / 後 | 圧縮の観測・抑止 |
| `Notification` | 通知送出時 | デスクトップ通知連携 |

ほかに `Setup` / `UserPromptExpansion` / `StopFailure` / `PostToolBatch` / `TaskCreated` /
`TaskCompleted` / `InstructionsLoaded` / `ConfigChange` / `CwdChanged` / `FileChanged` /
`Elicitation` / `ElicitationResult` / `MessageDisplay` / `WorktreeCreate` / `WorktreeRemove` /
`TeammateIdle` がある。必要になったら一次情報を確認する。

## matcher

- `"*"`・`""`・省略 = 全マッチ
- 英数字・`|`・`,`・スペースのみ → 完全一致（複数指定は `Edit|Write`）
- それ以外の文字を含む → JavaScript 正規表現（アンカーなし）。例: `mcp__memory__.*`
- 何にマッチするかはイベントで異なる: ツール系イベントはツール名、`SessionStart` は
  開始種別（`startup` / `resume` / `clear` / `compact`）、`PreCompact` は `manual` / `auto`、
  `SubagentStart` はエージェント種別など。`UserPromptSubmit` / `Stop` は matcher 非対応
- MCP ツール名は `mcp__<server>__<tool>` 形式

ハンドラには `if` フィールドで permission ルール形式の追加条件も書ける
（例: `"if": "Bash(git *)"` — Bash 全体でなく git コマンドのときだけ実行）。

## ハンドラの種類

`type` は 5 種: `command`（外部コマンド）/ `http`（POST 送信）/ `mcp_tool`（MCP ツール呼び出し）/
`prompt`（モデルに可否を判定させる）/ `agent`（サブエージェントで検証、実験的）。
基本は `command`。主なフィールド:

| フィールド | 意味 |
|---|---|
| `command` | 実行するコマンド。`args` 配列を付けると exec 形式（シェル解釈なし） |
| `timeout` | 秒。デフォルト 600（イベントにより短い既定あり） |
| `statusMessage` | 実行中にスピナーへ出す表示文言 |
| `async` | `true` で非ブロッキング実行（command のみ） |

パス置換 `${CLAUDE_PROJECT_DIR}`（プロジェクトルート）が `command` / `args` 内で使える。

## 入出力プロトコル

**stdin**（共通フィールド。イベントごとに追加フィールドあり）:

```json
{
  "session_id": "...",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "..." }
}
```

**exit code**:

| code | 意味 |
|---|---|
| 0 | 成功。stdout を JSON として解釈（JSON でなければ文脈テキスト扱いのイベントもある） |
| 2 | ブロック。stderr がブロック理由として使われる |
| その他 | 非ブロッキングエラー。処理は続行 |

**stdout JSON**（exit 0 時、共通フィールド）:

```json
{
  "continue": true,
  "stopReason": "continue: false 時の理由",
  "systemMessage": "ユーザーに見せる警告",
  "suppressOutput": false
}
```

## 代表イベントの入出力

**PreToolUse** — 出力で許可 / 拒否 / 入力書き換え:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow | deny | ask",
    "permissionDecisionReason": "理由",
    "updatedInput": { "command": "書き換え後" }
  }
}
```

**PostToolUse** — stdin に `tool_response` が追加。出力でブロック（Claude に差し戻し）と文脈追加:

```json
{
  "decision": "block",
  "reason": "Claude に渡すフィードバック",
  "hookSpecificOutput": { "hookEventName": "PostToolUse", "additionalContext": "追加文脈" }
}
```

**UserPromptSubmit** — stdin に `prompt`。exit 0 + プレーン stdout は文脈として追加される。
ブロックは `{"decision": "block", "reason": "..."}`。

**Stop / SubagentStop** — stdin に `stop_hook_active`。`{"decision": "block", "reason": "..."}`
で応答終了を差し止め、reason を指示として続行させる（`stop_hook_active` が true のときに
また block すると無限ループになるので必ず確認する）。

**PermissionRequest** — 出力:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": { "behavior": "allow | deny", "updatedInput": {} }
  }
}
```

**SessionStart** — 出力の `hookSpecificOutput.additionalContext` で文脈注入。

## 環境変数と注意点

- hook プロセスには `CLAUDE_PROJECT_DIR`（プロジェクトルート）が渡る
- 設定変更は `/hooks` メニューまたは settings.json 直接編集。直接編集した場合、
  実行中セッションには即時反映されないことがある（新しいセッションで確認する）
- `disableAllHooks: true`（settings.json）で全 hooks を無効化できる
