# OpenCode hooks 相当仕様（プラグイン方式）

- 調査日: 2026-08-04
- 一次情報: <https://opencode.ai/docs/plugins/>

## 要点 — シェル hooks は無い

OpenCode には Claude Code / Codex / Cursor のような「stdin で JSON を受け、
stdout / exit code で応答するコマンド実行」の hooks は**無い**。相当機能は
**プラグイン（JS/TS モジュール）**で、設定ファイルではなくコードを書く。
3 ツール用のシェルスクリプトをそのまま流用することはできない。

## 配置場所

| スコープ | 場所 |
|---|---|
| プロジェクト | `.opencode/plugins/*.js` / `*.ts`（置くだけで自動ロード） |
| ユーザー | `~/.config/opencode/plugins/*.js` / `*.ts` |
| npm パッケージ | `opencode.json` の `plugin` 配列にパッケージ名を列挙 |

ロード順: グローバル設定 → プロジェクト設定 → グローバル plugins/ → プロジェクト plugins/。
すべてのプラグインのフックが順に実行される。

## プラグインの構造

プラグインは「コンテキストを受け取り、hooks オブジェクトを返す関数」を export する。

```ts
import type { Plugin } from "@opencode-ai/plugin"

export const LintOnEdit: Plugin = async ({ $ }) => {
  return {
    "tool.execute.after": async (input, output) => {
      if (input.tool === "edit") {
        await $`./scripts/lint.sh ${input.args.filePath}`
      }
    },
  }
}
```

- フックは `output` をその場で書き換えて制御する（`return` 値では無い）
- **ブロックは `throw new Error("理由")` で行う**（`tool.execute.before` で throw すると
  ツール実行が中止される）。Cursor のような fail-open / fail-closed の設定は無い
- 外部 npm パッケージを使う場合は設定ディレクトリに `package.json` を置く
  （起動時に `bun install` される）

## 主要ユースケースのフック対応

| やりたいこと | フック |
|---|---|
| ツール実行前の検査・ブロック | `tool.execute.before`（`input.tool` で対象を絞る。throw でブロック） |
| 編集後の lint・format | `tool.execute.after`（`input.tool === "edit"` / `"write"` 等で判定） |
| プロンプト送信時の検査・文脈追加 | `experimental.chat.messages.transform` |
| セッション開始時の文脈注入 | `experimental.chat.system.transform` |
| 応答終了時の通知・検査 | `event`（`session.idle` 等のバスイベントを監視） |
| 許可ダイアログの自動判断 | `permission.ask` |

`tool.execute.before` / `after` は引数の入る場所が違う。取り違えると `undefined` を
掴んで黙って何もしない hook になるので、必ず次を確認する（型定義 `@opencode-ai/plugin`）:

| フック | `input` | `output`（書き換え可能） |
|---|---|---|
| `tool.execute.before` | `{ tool, sessionID, callID }` | `{ args }` — 実行前の引数。`output.args.command` 等を書き換えられる |
| `tool.execute.after` | `{ tool, sessionID, callID, args }` — 引数はこちら | `{ title, output, metadata }` — 実行結果 |

その他の主なフック: `chat.message`（新規メッセージ受信）、`chat.params`
（LLM へ渡すパラメータの変更）、`command.execute.before`、`shell.env`（シェルの環境変数）。

## 検証

- 設定・プラグインの変更は**再起動後に反映される**（ホットリロードされない）
- ログは `console.log` ではなく `client.app.log()` を推奨
- 構文エラーでプラグインがロードされない場合は起動ログを確認する
