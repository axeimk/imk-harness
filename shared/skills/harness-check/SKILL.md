---
name: harness-check
description: プロジェクトスコープのハーネス（CLAUDE.md / AGENTS.md、verify スキル、HARNESS.md など）をブートストラップ・整備する。ユーザーが明示的に起動を求めたとき（新規プロジェクトの立ち上げ、プロジェクトスコープの整備・見直しの依頼）だけ使う。エージェントの判断で自発的に起動・提案しない。
---

# harness-check — プロジェクトスコープのブートストラップ

このスキルは「汎用ハーネスが各プロジェクトのハーネスを育てる」ための入口。以下を順に確認し、欠けているものを提案・作成する。

## ユーザーへの確認方法

このスキル内のユーザーへの確認（使用ツール、各項目の要否など）は **1 回に 1 問ずつ**行う。
複数の項目をまとめて提示して一括で回答させない（前の回答が後の質問の要否や内容を変えるため）。

質問には毎回、選択肢を明示する。選択肢を提示してユーザーに選ばせる質問ツール
（Claude Code: AskUserQuestion、Codex: request_user_input、Cursor: AskQuestion）を使い、1 回の呼び出しに 1 問だけ載せる。

## 手順

1. **使用ツールの確認**: このプロジェクトで使うコーディングエージェント（Claude Code / Codex / Cursor）をユーザーに確認する。既存ファイルの有無から推測しない（CLAUDE.md しか無いプロジェクトでこれから Codex を使い始めることもある）。`HARNESS.md` に記録済みならそれに従い、再確認しない。回答は手順 11 で `HARNESS.md` に記録する。以降の手順の要否と配置場所はこの選択で決まる。
2. **現状確認**（プロジェクトルートで）
   - `HARNESS.md`（採否の記録）があるか。旧規約の記録（CLAUDE.md / AGENTS.md の「ハーネス」節）が残っていないかも確認する
   - `CLAUDE.md` があるか（Claude Code を使う場合）
   - `AGENTS.md` があるか（Codex / Cursor を使う場合）
   - CLAUDE.md / AGENTS.md に「作業の進め方」節（検証・報告の運用ルール）があるか
   - verify スキルがあるか（Claude Code: `.claude/skills/verify/SKILL.md`、Codex / Cursor: `.agents/skills/verify/SKILL.md`）
   - tdd スキルがあるか（配置は verify スキルと同じ規約）
   - domain-modeling / grilling スキルがあるか（配置は verify スキルと同じ規約）
   - `CONTEXT.md`（プロジェクト用語集）があるか
   - ADR 置き場（`docs/adr/` など設計記録のディレクトリ）があるか
   - プロジェクト固有 permissions / hooks があるか（Claude Code: `.claude/settings.json`、Codex: `config.toml`、Cursor: `.cursor/`）
3. **欠けているものを 1 項目ずつ提示し、要る / 要らないをユーザーに選ばせる**（「ユーザーへの確認方法」に従う）。勝手に全部作らない。domain-modeling と grilling は別項目として提示する（grilling は単独で成立する）。`HARNESS.md` に「使わない」と記録済みの項目は一覧に載せない（ユーザーが明示的に見直しを求めたときを除く。見直し時は欠けているものに加え、既存の要素についても継続 / 廃止を確認する）。
   選択に矛盾がある場合（例: CLAUDE.md / AGENTS.md を不採用にしたまま tdd / CONTEXT.md / ADR を採用する — トリガーの追記先が無く、他のエージェントが規約を発見できない）は、作成に入る前にまとめて提示し、どちらを変えるかユーザーに確認する。それでも変えない場合はトリガー追記を省いて導入し、その制約を `HARNESS.md` に記録する。
4. **CLAUDE.md / AGENTS.md の作成**: `templates/CLAUDE.md.template` を土台に、リポジトリを調査して埋める（ビルド・テストコマンドは package.json / Makefile / pyproject.toml 等から実際に確認する。推測で書かない）。ファイル名は使用ツールに合わせる。両方必要な場合は AGENTS.md（ツール非依存側）を実体にし、CLAUDE.md をそこへの symlink にする（コピーを 2 つ置くと乖離する）。差分が必要になったときだけ実ファイルに分ける。
   テンプレートの「作業の進め方」節はデフォルト案であり、そのまま貼らずプロジェクトの実態と他項目の採否に合わせて調整する（例: verify スキルを使わないなら該当項目を「既知の方法で動作確認する」に書き換える。hooks で lint を強制しているなら手動実行の指示は省く）。既存の CLAUDE.md / AGENTS.md にこの節が無い場合は追記を提案する（作業の進め方はユーザースコープでは定めないため、この節が無いとエージェントごとの振る舞いが揃わない）。
5. **verify スキルの作成**: `templates/verify-SKILL.md.template` を土台に、そのプロジェクトを実際にビルド・起動・操作して変更を確認するためのレシピ（起動コマンド、確認すべき代表フロー、落とし穴）を記載する。テスト・lint・ビルドのコマンド一覧は CLAUDE.md / AGENTS.md の「コマンド」節に置き、ここには重複させない。
   - 配置は使用ツールに合わせる（Claude Code: `.claude/skills/verify/`、Codex / Cursor: `.agents/skills/verify/`）。両方必要な場合は `.agents/skills/verify/` に実体を置き、`.claude/skills/verify` → `../../.agents/skills/verify` の symlink を張る（`.agents` がツール非依存の場所。コピーを 2 つ置くと乖離する）
   - description はテンプレートのままにせず、プロジェクト名と対象（何を変更したときに使うか）を入れて具体化する
   - 作成後、imk-skill-creator スキル（あれば）に同梱の `scripts/validate-skill.sh` で検査し、レシピどおりに一度起動して動くことを確認する
6. **tdd スキルの作成**（選ばれた場合）: `templates/tdd-SKILL.md.template` を土台に、テスト駆動で実装を進めるためのプロジェクト固有レシピ（テストの置き場所・命名、単一テストの実行コマンド、Red → Green → Refactor の回し方、プロジェクトの流儀）を記載する。単一テストの実行コマンドは実際に動かして確認する（推測で書かない）。配置と symlink の規約、description の具体化、作成後の検査は verify スキル（手順 5）と同じ。あわせて CLAUDE.md / AGENTS.md に「実装は TDD で進める。手順は tdd スキルに従う」のトリガーを 1〜2 行で追記する（サイクルの詳細は常駐指示に書かず、スキル側が持つ）。テストコマンドがまだ無いプロジェクトでは、先にテスト基盤の整備を提案してから導入する。基盤の整備を断られた場合、tdd は導入不可として不採用扱いにし、`HARNESS.md` に理由（テスト基盤が無いため）とともに記録する。
7. **domain-modeling / grilling スキルの導入**（選ばれた場合）: 同梱の `templates/domain-modeling/`・`templates/grilling/` をプロジェクトのスキル置き場へ複製する（`SKILL.md.template` は `SKILL.md` に改名し、LICENSE・`templates/` もそのまま含める）。配置と symlink の規約、作成後の検査は verify スキル（手順 5）と同じ。中身は汎用のデフォルト案なのでそのまま置いてよいが、プロジェクトの流儀（既存の用語集・設計記録の規約）に合わせて調整・育成してよい。
   - domain-modeling は CONTEXT.md（手順 8）と ADR（手順 9）の運用を能動的に支えるスキル。どちらも使わないプロジェクトでは導入の意味が薄いため、原則不採用を推奨する。それでも導入する場合は理由を `HARNESS.md` に記録する
   - grilling は単体で成立する（domain-modeling が無い場合は記録部分が省かれるだけ）
8. **CONTEXT.md の作成**（選ばれた場合）: domain-modeling スキル（導入した場合）の手順とテンプレートに従う。導入しない場合は同梱の `templates/domain-modeling/templates/CONTEXT.md.template` を土台にする。その時点で確立している用語だけを書き、リポジトリを走査した一括収集はしない。確立した用語がまだ無いプロジェクトでは「最初の用語が確定したときに作る」で足りるので、無理に作らない。採用したら CLAUDE.md / AGENTS.md に「`CONTEXT.md`（用語集）の語彙で会話・命名する」の 1 行を追記する。
9. **ADR（設計記録）の導入**（選ばれた場合）: `templates/adr-README.md.template` から `docs/adr/README.md` を作成し、CLAUDE.md / AGENTS.md に「設計記録」節を追記する。節はトリガーだけを持たせ、2 行以内に収める（例: 「設計上の決定は `docs/adr/` に記録する。基準と形式は `docs/adr/README.md` に従う」）。記録する基準・形式・運用の詳細は README 側が持つので、常駐指示には書かない。**最初の ADR はここでは書かない** — 記録すべき決定が出た時点で、README を手本にどのエージェントでも書ける。既存の ADR 置き場・形式があるプロジェクトではそれを尊重し、README の配置は規約が明文化されていない場合の提案にとどめる。
10. **permissions / hooks の提案**（任意）: 頻用コマンドの許可リスト（permissions）や、編集後の lint など機械的に強制したい検査（hooks）があれば、使用ツールごとの設定を提案する（permissions — Claude Code: `.claude/settings.json`、Codex: `config.toml`、Cursor: `.cursor/`。hooks — Claude Code: `.claude/settings.json`、Codex: `hooks.json` または `config.toml` の `[hooks]`、Cursor: `.cursor/hooks.json`）。テストスイート全実行のような重い処理は hooks に入れない。
11. **採否の記録**: 使用ツール（手順 1）と、「要らない」と選ばれた項目をプロジェクトルートの `HARNESS.md` に記録し、以後どのエージェントも再確認・再提案しないようにする（例: `- verify スキル: 使わない（2026-07-12 ユーザー判断）`）。ファイルが無ければ `templates/HARNESS.md.template` を土台に作る。

## 注意

- このスキルが提案する規約はデフォルトの提供であり、強制ではない。ユーザーの「要らない」は記録して尊重する。
- 旧規約では採否を CLAUDE.md / AGENTS.md の「ハーネス」節に記録していた。この節を見つけたら、記録を `HARNESS.md` へ移して節を削除する移行を提案する（勝手に移さない。移行するまでは節の記録も尊重する）。
- 既存ファイルがある場合は上書きせず、不足しているセクションの追記を提案する。
- プロジェクトに関する知識のみを書く。応答スタイル等のユーザー個人の好みはユーザースコープ（ホーム側の CLAUDE.md / AGENTS.md）に属するので書かない。
- Claude Code にはビルトインの verify スキル（変更を実行時観察で検証する汎用手順）があり、プロジェクトに verify スキルが無ければ自らブートストラップする。ここで作る verify スキルはそれと競合せず、ビルトイン verify が起動手段を探す段階で参照するプロジェクト固有レシピとして機能する（Codex / Cursor ではそのまま手順書として使う）。中身をテストコマンドの羅列にしないこと — ビルトイン verify は「テスト実行は検証ではない」という前提で動く。
