# ADR-0009: 共有スキルのツール間差異はネイティブ吸収（graceful degradation 規約）で扱う

- ステータス: 承認済み
- 日付: 2026-07-12

## コンテキスト

`shared/skills/` のスキルは symlink で配布されるため（ADR-0003）、同一の SKILL.md が
Claude Code / Codex / Cursor の全ツールから読まれる。一方、Skills の仕様には
ツール独自の拡張があり（調査の詳細は [docs/skills-spec/](../skills-spec/README.md)）、
性質で 3 種類に分けられる:

1. **無害な差分** — 対応しないツールが無視する加算的フロントマター。
   Claude Code 専用の `allowed-tools` `when_to_use` 等、
   Claude Code / Cursor 共通の `disable-model-invocation` `paths`
2. **有害な差分** — 本文の意味を変える機能。Claude Code の動的コンテキスト注入
   `` !`cmd` `` や引数展開 `$ARGUMENTS` `${CLAUDE_*}` は、Codex / Cursor では
   展開されず生テキストのままモデルに渡り、指示文が壊れる
3. **表現が割れる差分** — 「モデルからの自動発火を禁止」は Claude Code / Cursor では
   フロントマター `disable-model-invocation: true`、Codex では別ファイル
   `agents/openai.yaml` の `policy.allow_implicit_invocation: false` に書く

## 決定

**変換レイヤーは作らず、「各ツールは他ツールの拡張をエラーにせず無視する」という
性質そのものを吸収機構として使う。** 共有スキルは次の規約に従う。要約は 1 行:
「どのツールで読まれても本文が成立すること（graceful degradation）」。

1. **共通コアは必須**: `name`（ディレクトリ名と一致、英小文字・数字・ハイフン、
   64 文字以内）と `description`（1024 文字以内。Codex では欠落がロードエラーになる）
2. **本文は全ツールに同一に読まれる前提で書く**: `` !`cmd` `` 注入・` ```! ` ブロック・
   `$ARGUMENTS` / `$N` / `${CLAUDE_*}` は共有スキルでは使わない
3. **加算的フロントマターは「効かないツールでも本文が成立する」ことを条件に許可**:
   `disable-model-invocation` `paths` `allowed-tools` 等は書いてよいが、
   本文がその存在に依存してはならない
4. **Codex 固有の指定は `agents/openai.yaml` に分離する**（Codex の公式機構。
   他ツールはただの補助ファイルとして無視する）。自動発火を禁止するスキルは
   フロントマターの `disable-model-invocation: true` と openai.yaml の
   `policy.allow_implicit_invocation: false` の**両方**に書く（唯一の二重管理点）
5. **規約は `check-skills.sh` で機械検査する**: 命名規則・description の有無と長さ・
   禁止パターンの混入・4 の整合・リポジトリ内部参照（ADR 番号等）の混入を検査する

## 検討した代替案

- **共通サブセット強制**（`name` + `description` + 本文のみに制限）— 実装ゼロだが、
  無害な加算フィールドまで禁止する根拠がない。`allowed-tools` による権限プロンプト削減や
  手動起動専用化という正当な要求を実現する手段がなくなる
- **ビルド変換**（`shared/instructions` と同様に、原本からツール別スキルを生成して
  出し分ける）— 有害な差分まで吸収できる唯一の完全解であり理想形。ただし
  「共通 + ツール別差分」の独自メタ形式の発明、bash 3.2 + awk での YAML 加工、
  「直接編集禁止の生成物」ゾーンの拡大（symlink 先が生成物になり、編集→即反映の
  ライブ編集が壊れる）というコストに対し、現時点で出し分けを必要とする共有スキルが
  存在しない。**再検討条件**: `$ARGUMENTS` や `` !`cmd` `` 等を使いたい共有スキルが
  実際に現れたら、本 ADR を見直しビルド変換（またはツール限定配布）を検討する
- **ツール限定配布**（スキルごとに配布先ツールを宣言し `link_skills()` が絞る）—
  本決定と直交する補完策。ツール固有機能に全面依存するスキルが現れた時点で
  追加を検討する（上記の再検討条件と同じ）

## 結果

- `install.sh` / `lib.sh` は無変更。symlink 配置とライブ編集性を維持したまま
  3 ツール互換が規約として保証される
- `check-skills.sh` を新設。スキルの追加・変更時に実行する
- 有害な差分（動的注入・引数展開）は禁止であって吸収ではない。これらを使う
  スキルは当面書けない（再検討条件は上記）
- 発火ポリシーの二重管理（フロントマター + openai.yaml）が残るが、
  `check-skills.sh` の整合検査で乖離を防ぐ
