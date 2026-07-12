# Claude Code の Skills 仕様

- 調査日: 2026-07-12
- 一次情報: <https://code.claude.com/docs/en/skills>
- 位置づけ: [Agent Skills 標準](https://agentskills.io) に準拠しつつ、
  **3 ツール中もっとも拡張が多い**。カスタムコマンド（`.claude/commands/`）は
  スキルに統合済み（同じフロントマターを共有）

## 配置場所

| レベル | パス | 適用範囲 |
|---|---|---|
| Enterprise | managed settings 経由 | 組織全体 |
| Personal | `~/.claude/skills/<name>/SKILL.md` | 全プロジェクト |
| Project | `.claude/skills/<name>/SKILL.md` | そのプロジェクト |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | プラグイン有効範囲（`plugin:skill` 名前空間） |

- 同名スキルは **enterprise > personal > project** で上書き。バンドルスキルも同名で上書き可
- ネストされた `.claude/skills/`（モノレポのパッケージ配下等）も読み込む。
  名前衝突時は `apps/web:deploy` のようにディレクトリ修飾名になる
- 親ディレクトリ方向にも探索（サブディレクトリで起動してもリポジトリルートのスキルを拾う）
- `--add-dir` / `/add-dir` で追加したディレクトリの `.claude/skills/` も読む
  （`settings.json` の `permissions.additionalDirectories` では読まない）
- **symlink を辿る**。同一実体が複数箇所から届く場合は 1 回だけロード
  （このハーネスの symlink 配置方式が成立する根拠）
- スキルディレクトリはファイル監視され、セッション中の追加・編集・削除が即反映
  （新しいトップレベル skills ディレクトリの新設のみ再起動が必要）

## フロントマター（全フィールド任意。description のみ推奨）

| フィールド | 説明 |
|---|---|
| `name` | 一覧での表示名。**省略時はディレクトリ名**。コマンド名（`/xxx`）は原則ディレクトリ名から決まり、`name` では変わらない（例外: プラグインルート直下の SKILL.md のみ `name` がコマンド名になる） |
| `description` | 何をするか・いつ使うか。自動発火の判定材料。省略時は本文第 1 段落を使用。`when_to_use` と合算で一覧上 1536 文字に切り詰め |
| `when_to_use` | 発火条件の追記（トリガーフレーズ等）。一覧では description に連結 |
| `argument-hint` | 補完時に表示する引数ヒント（例: `[issue-number]`） |
| `arguments` | 名前付き位置引数の宣言。`$name` 置換に使う。スペース区切り文字列か YAML リスト |
| `disable-model-invocation` | `true` でモデルからの自動発火を禁止（ユーザーの `/name` のみ）。description も一覧に載らない。デフォルト `false` |
| `user-invocable` | `false` で `/` メニューから隠す（モデルのみ発火可）。デフォルト `true` |
| `allowed-tools` | スキル発火中、確認なしで使えるツール。スペース/カンマ区切りか YAML リスト。**利用可能ツールを制限するのではなく事前承認を与える** |
| `disallowed-tools` | 発火中にツールプールから除外するツール。次のユーザーメッセージで解除 |
| `model` | 発火中のモデル上書き（そのターンのみ）。`inherit` 可 |
| `effort` | 発火中の effort 上書き（`low`〜`max`） |
| `context` | `fork` で分離されたサブエージェントコンテキストで実行 |
| `agent` | `context: fork` 時に使うサブエージェント種別（`Explore` / `Plan` / `general-purpose` / カスタム。省略時 `general-purpose`） |
| `hooks` | スキルのライフサイクルに限定した hooks |
| `paths` | glob パターン。一致するファイルを扱うときだけ自動発火の対象になる |
| `shell` | `` !`cmd` `` の実行シェル。`bash`（デフォルト）/ `powershell` |

フロントマター YAML が壊れている場合、本文はメタデータ空でロードされる
（`/name` は動くが自動発火しない）。

## 文字列置換（本文内）

| 変数 | 内容 |
|---|---|
| `$ARGUMENTS` | 起動時引数の全文。本文に無い場合は末尾に `ARGUMENTS: <値>` が付加される |
| `$ARGUMENTS[N]` / `$N` | 0 始まりの位置引数（シェル風クオートで分割） |
| `$name` | `arguments` フロントマターで宣言した名前付き引数 |
| `${CLAUDE_SESSION_ID}` | セッション ID |
| `${CLAUDE_EFFORT}` | 現在の effort レベル |
| `${CLAUDE_SKILL_DIR}` | その SKILL.md のあるディレクトリ（同梱スクリプト参照用） |
| `${CLAUDE_PROJECT_DIR}` | プロジェクトルート。本文と `allowed-tools` の両方で展開される |

リテラル `$` は `\$` でエスケープ。

## 動的コンテキスト注入（Claude Code 独自）

- `` !`command` ``（行頭または空白直後のみ認識）は、**モデルに渡る前に**
  シェルで実行され、出力に置換される
- 複数行は ` ```! ` フェンスブロック
- 置換は元ファイルに対して 1 回だけ（出力の再スキャンなし）
- `settings.json` の `disableSkillShellExecution: true` で無効化可能
  （プレースホルダは `[shell command execution disabled by policy]` に置換）

## コンテキストへの載り方

- 通常時: 全スキルの `name` + `description` 一覧が常駐、本文は発火時にロード
- 発火した本文はセッション中コンテキストに残留（同一内容の再発火は短い注記のみ）
- auto-compaction 時はスキルごと先頭 5000 トークン・合計 25000 トークンの予算内で再添付
- 一覧の予算はコンテキストの 1%（`skillListingBudgetFraction` /
  `SLASH_COMMAND_TOOL_CHAR_BUDGET` で変更可）。溢れると発火頻度の低いものから
  description が落とされる。1 件あたり 1536 文字上限（`skillListingMaxDescChars`）

## 可視性の外部制御

- `settings.json` の `skillOverrides` で、SKILL.md を編集せずに
  `on` / `name-only` / `user-invocable-only` / `off` を指定できる
  （共有リポジトリのスキルを個人設定で黙らせる用途。プラグインスキルは対象外）
- 権限ルール `Skill(name)` / `Skill(name *)` で発火可否を制御、
  `Skill` を deny すると全スキル無効

## スキルのスタック起動

`/code-review /fix-issue 123` のように 1 メッセージに複数スキルを並べられる
（先頭 + 最大 5 個まで展開。末尾テキストは各スキルの `$ARGUMENTS` になる）。
