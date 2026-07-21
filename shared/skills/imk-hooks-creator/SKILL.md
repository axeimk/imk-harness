---
name: imk-hooks-creator
description: Claude Code / Codex / Cursor の hooks（ライフサイクルフック）を作成・修正する。ツールごとに異なるイベント名・設定ファイル・入出力スキーマの正確な参照資料を含む。ユーザーが「hooks を作って」「編集後に lint を自動実行して」「このコマンドを機械的にブロックして」など hooks による強制・自動化を求めたとき、既存 hooks が発火しない・動かない問題を調べるとき、複数ツール向けに同じ hooks を揃えるときは必ずこのスキルを使う。
---

# imk-hooks-creator — 3 ツールの hooks 作成・修正

Claude Code / Codex / Cursor の hooks 設定を作成・修正するための手順。
3 ツールの hooks は思想が似ている（stdin で JSON を受け、stdout の JSON か exit code で
応答するコマンド実行）が、**イベント名・設定ファイルの構造・出力フィールド名はすべて異なる**。
似て非なる仕様なので、学習知識だけで書くと別ツールの書式が混入したり、
「仕様がわからない」と一部ツール分だけ書いて終わったりする。

**鉄則: 設定を書く前に、対象ツールの参照資料（`references/`）を必ず読む。**

- Claude Code → `references/claude-code.md`
- Codex → `references/codex.md`
- Cursor → `references/cursor.md`

## 手順

### 1. 要件とツールの確認

- 何を強制・自動化したいか（検査してブロックするのか、後処理を走らせるのか、文脈を注入するのか）
- 対象ツールはどれか。プロジェクトの `HARNESS.md` に使用ツールの記録があればそれに従う。
  無ければユーザーに確認する（1 ツールだけとは限らない）
- スコープはどこか（プロジェクトに共有するか、ユーザー個人の設定か）

hooks は毎回機械的に実行される。「エージェントに毎回言っても守らないこと」の強制には
向くが、テストスイート全実行のような重い処理を入れるとすべての操作が遅くなるので入れない。

### 2. 対象ツールの参照資料を読む

対象ツールすべての `references/<tool>.md` を読む。複数ツール向けに書く場合、
1 ツール分を書いた後に他ツールへ「翻訳」するのではなく、各資料のスキーマに従って
それぞれ書く（出力フィールド名の混入が典型的な事故）。

### 3. イベントと構成の設計

主要ユースケースのイベント対応表:

| やりたいこと | Claude Code | Codex | Cursor |
|---|---|---|---|
| ツール実行前の検査・ブロック | `PreToolUse` | `PreToolUse` | `preToolUse`（シェルは `beforeShellExecution`、MCP は `beforeMCPExecution`） |
| 編集後の lint・format | `PostToolUse`（matcher `Edit\|Write`） | `PostToolUse` | `afterFileEdit` |
| プロンプト送信時の検査・文脈追加 | `UserPromptSubmit` | `UserPromptSubmit` | `beforeSubmitPrompt` |
| セッション開始時の文脈注入 | `SessionStart` | `SessionStart` | `sessionStart` |
| 応答終了時の検査・継続強制 | `Stop` | `Stop` | `stop` |
| 許可ダイアログの自動判断 | `PermissionRequest` | `PermissionRequest` | `beforeShellExecution` 等の `permission` 出力 |

設定ファイルの配置:

| スコープ | Claude Code | Codex | Cursor |
|---|---|---|---|
| プロジェクト | `.claude/settings.json` の `hooks` キー | `.codex/hooks.json` | `.cursor/hooks.json` |
| ユーザー | `~/.claude/settings.json` | `~/.codex/hooks.json` | `~/.cursor/hooks.json` |

複数ツールで同じ検査をする場合、**フックスクリプトの実体は 1 本にして各ツールの設定から
呼ぶ**（ロジックのコピーは乖離する）。ただし stdin の JSON フィールド名はツールごとに
異なるので、差異はスクリプト冒頭の入力パースで吸収し、判定ロジックは共通にする。
スクリプトの置き場所はプロジェクトなら `.agents/hooks/` などツール中立のディレクトリを推奨
（スキルの `.agents/skills/` と同じ理由。単一ツールならそのツールの流儀の場所でよい）。

### 4. 実装

- 参照資料のスキーマに従って設定とスクリプトを書く。スクリプトには実行権限を付ける
- ブロック目的の hook は「失敗時にどうなるか」を確認する。Cursor はデフォルト fail-open
  （hook が落ちると素通し。`failClosed: true` で反転）。セキュリティ目的なら fail-closed 側に倒す
- スクリプト内に秘密情報を書かない。stdin の JSON にはプロンプトやコマンド全文が
  入ってくるため、ログに書き出す hook は保存先と内容に注意する

### 5. 検証

作って終わりにしない。順に確認する:

1. **構文**: JSON は `python3 -m json.tool < 設定ファイル` などで構文検査する
2. **単体**: 参照資料の stdin 例を模したサンプル JSON をスクリプトに流し、
   期待する stdout / exit code が返ることを確認する
3. **実地**: 対象ツールで実際にイベントを発火させて動作を確認する。
   Codex はプロジェクトの hooks を信頼（trust）するまで実行されない点に注意
   （`/hooks` でレビュー・信頼する。ユーザーに操作を依頼する）

## 仕様が食い違ったとき

各参照資料には調査日と一次情報の URL を記載してある。hooks の仕様は変化が速いので、
記載どおりに書いたのに動かない場合は推測で直さず、一次情報（公式ドキュメント）を
確認して原因を特定し、**参照資料側も更新する**（次回の自分やほかのエージェントが
同じ穴に落ちないようにする）。
