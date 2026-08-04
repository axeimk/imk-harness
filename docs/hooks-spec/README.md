# Hooks 仕様調査 — Claude Code / Codex / Cursor / OpenCode

- 調査日: 2026-07-21（OpenCode: 2026-08-04 追加）
- 目的: 各ツールの hooks（ライフサイクルフック）仕様を確認し、imk-hooks-creator スキル
  （ADR-0017）の参照資料を作る判断材料にする

## 正規のダイジェストはスキル側にある

各ツールの仕様ダイジェストは **`shared/skills/imk-hooks-creator/references/`** が持つ
（claude-code.md / codex.md / cursor.md / opencode.md）。スキルの参照資料は展開先で読まれるため
自己完結が必要で、同じ内容を本ディレクトリに複製すると乖離するだけなので、
ここには調査の記録（出典・要点・判断）だけを残す。仕様の更新もスキル側の references を
直接更新する（各ファイルに調査日と一次情報 URL を記載済み）。

## 一次情報

| ツール | URL | 備考 |
|---|---|---|
| Claude Code | https://code.claude.com/docs/en/hooks | |
| Codex | https://developers.openai.com/codex/hooks | learn.chatgpt.com/docs/hooks へリダイレクト |
| Cursor | https://cursor.com/docs/hooks | Cursor 1.7（2025-09 頃）で導入 |
| OpenCode | https://opencode.ai/docs/plugins/ | シェル hooks は無くプラグイン（JS/TS）方式 |

## 調査の要点（2026-07-21 時点）

- **3 ツールとも hooks 機構が実在する**。かつて Codex は `notify` 程度しか無かったが、
  現在はライフサイクルフック（`hooks.json` / `config.toml` の `[hooks]`）を持つ
- **共通の設計思想**: 外部コマンドを spawn し、stdin で JSON を受け、
  exit 0 + stdout JSON で構造化応答、exit 2 でブロック
- **しかし相互運用性は無い**。差異の代表例:
  - 設定構造: Claude Code / Codex は「イベント → matcher グループ → hooks」の 2 段ネスト。
    Cursor は `version` フィールド付きのフラットな配列
  - イベント名: Claude Code / Codex は PascalCase（`PreToolUse`）、Cursor は
    lowerCamelCase かつ粒度が違う（`beforeShellExecution` などツール種別ごとの専用イベント）
  - 出力スキーマ: Claude Code / Codex は `hookSpecificOutput.permissionDecision`、
    Cursor はトップレベルの `permission` / snake_case
  - Codex 固有: プロジェクト hooks は trust（`/hooks` でレビュー・信頼）されるまで
    実行されない。`command` タイプ以外はパースされるが黙ってスキップされる
  - Cursor 固有: デフォルト fail-open（hook 失敗は素通し。`failClosed` で反転）
- この「似て非なる」性質が、学習知識だけで書いたときの事故（別ツールの書式の混入、
  一部ツール分の放棄）の原因。スキルの references を正として参照させる

## OpenCode 追加調査の要点（2026-08-04 時点）

- **OpenCode にはシェル hooks が無い**。相当機能はプラグイン（JS/TS モジュール）で、
  設定ファイルではなくコードを書く。他 3 ツールの「コマンドを spawn し、stdin の JSON を
  読み、exit code / stdout で応答する」モデルとは前提から異なる
- 配置は `.opencode/plugins/` / `~/.config/opencode/plugins/` に置くだけで自動ロードされる
  （設定への登録は npm パッケージとして使う場合のみ）
- ブロックは戻り値ではなく **`throw`**。`tool.execute.before` で例外を投げるとツール実行が
  中止される。Cursor のような fail-open / fail-closed の切り替えは無い
- フック名は他 3 ツールのイベント名と一対一に対応しない（例: 応答終了は専用イベントでなく
  `event` でバスイベント `session.idle` を監視する、プロンプト・システム指示への介入は
  `experimental.` 接頭辞つき）
- **同じ hook を 4 ツールへ揃える依頼では、OpenCode だけスクリプトを共有できない**。
  判定ロジックを共通シェルスクリプトに置き、プラグインからそれを実行する形にすれば
  ロジックの二重管理は避けられる — この方針を imk-hooks-creator の SKILL.md に記載した
- 型定義（`npm pack @opencode-ai/plugin`）の `Hooks` interface が実質の一次情報。
  ドキュメントのイベント一覧はバスイベントとフックが混在して読めるため、
  引数の形（`tool.execute.after` の引数は `input.args`、`output` は実行結果）は
  型定義で確認する
