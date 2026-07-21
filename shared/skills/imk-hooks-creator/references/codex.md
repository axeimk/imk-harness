# Codex hooks 仕様

- 調査日: 2026-07-21
- 一次情報: https://developers.openai.com/codex/hooks

## 目次

1. [設定ファイルと構造](#設定ファイルと構造)
2. [トラストモデル（最重要の落とし穴）](#トラストモデル最重要の落とし穴)
3. [イベント一覧](#イベント一覧)
4. [入出力プロトコル](#入出力プロトコル)
5. [代表イベントの入出力](#代表イベントの入出力)
6. [制限事項](#制限事項)

## 設定ファイルと構造

読み込み元（複数ソースが同時にロードされ、上位が下位を置き換えることはない）:

| 場所 | スコープ |
|---|---|
| `~/.codex/hooks.json`（または `~/.codex/config.toml` の `[hooks]`） | ユーザー |
| `<repo>/.codex/hooks.json`（または `<repo>/.codex/config.toml` の `[hooks]`） | プロジェクト |

`hooks.json` を推奨する（`config.toml` の `[hooks]` でも同じ構造を書けるが、
JSON のほうが Claude Code と構造を見比べやすい）。構造は Claude Code と同じ
「イベント名 → matcher グループの配列 → hooks 配列」の 2 段ネスト:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".codex/hooks/check.sh",
            "timeout": 30,
            "statusMessage": "検査中..."
          }
        ]
      }
    ]
  }
}
```

- `command_windows` フィールドで Windows 用コマンドを上書きできる
- コマンドはセッションの cwd で実行される。リポジトリローカルの hook は
  リポジトリルートからの相対パスで書く

## トラストモデル（最重要の落とし穴）

**プロジェクトの hooks は、その `.codex/` レイヤーが信頼（trust）されるまで実行されない。**
書いたのに発火しない場合はまずこれを疑う。ユーザーに `/hooks` コマンドの操作を依頼する:

- 全 hook ソースの確認、新規・変更 hook のレビュー、信頼（内容ハッシュで記録）、個別無効化
- hook を変更するたびに再レビューが必要（内容ハッシュが変わるため）

## イベント一覧

| イベント | 発火タイミング | matcher の対象 |
|---|---|---|
| `SessionStart` | セッション開始 | 開始種別（`startup` / `resume` / `clear` / `compact`） |
| `PreToolUse` | ツール実行前 | ツール名（`Bash` / `apply_patch` / `mcp__...`） |
| `PermissionRequest` | 許可要求時 | ツール名 |
| `PostToolUse` | ツール実行後 | ツール名 |
| `UserPromptSubmit` | プロンプト送信時 | なし（matcher は無視される） |
| `PreCompact` / `PostCompact` | 圧縮前 / 後 | `manual` / `auto` |
| `SubagentStart` / `SubagentStop` | サブエージェント開始 / 終了 | エージェント種別 |
| `Stop` | ターン終了時 | なし |

`SessionEnd` や `Notification` に相当するイベントは無い（調査日時点）。

## 入出力プロトコル

**stdin**（共通フィールド。イベントごとに追加あり）:

```json
{
  "session_id": "...",
  "transcript_path": null,
  "cwd": "...",
  "hook_event_name": "PreToolUse",
  "model": "...",
  "turn_id": "...",
  "permission_mode": "default"
}
```

**exit code**: 0 = 成功（stdout の JSON を構造化応答として解釈）、2 = 失敗
（stderr をメッセージとして使用）。

**stdout JSON**（共通フィールド）:

```json
{
  "continue": true,
  "stopReason": "...",
  "systemMessage": "...",
  "suppressOutput": false
}
```

メッセージは 2,500 トークン程度で切り詰められ、超過分は一時ファイルに退避される。

## 代表イベントの入出力

**PreToolUse** — stdin に `tool_name` / `tool_use_id` / `tool_input`。出力:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny | allow",
    "permissionDecisionReason": "理由",
    "updatedInput": { "command": "書き換え後" }
  }
}
```

**PostToolUse** — stdin に `tool_response` が追加。出力でブロック（モデルへの差し戻し）:

```json
{
  "decision": "block",
  "reason": "フィードバック",
  "hookSpecificOutput": { "additionalContext": "追加文脈" }
}
```

実行済みコマンドの取り消しはできない。モデルに見せる結果の差し替えと差し戻しのみ。

**PermissionRequest** — 出力:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": { "behavior": "allow | deny", "message": "任意" }
  }
}
```

**UserPromptSubmit** — stdin に `prompt`。ブロックは `{"decision": "block", "reason": "..."}`。

**Stop / SubagentStop** — stdin に `stop_hook_active` / `last_assistant_message`。
`{"decision": "block", "reason": "継続指示"}` でターンを続行させる。

## 制限事項

（調査日時点。変わりやすいので動かないときは一次情報を確認する）

- ハンドラは `type: "command"` のみ実行される。`prompt` / `agent` タイプはパースされるが
  **黙ってスキップされる**（エラーにならない）
- `async` オプションもパースされるが機能しない
- `PreToolUse` 出力の `continue` / `stopReason` は未サポート
- 一度きりのバイパス: `--dangerously-bypass-hook-trust`（ユーザー判断でのみ使う）
