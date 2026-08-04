# ADR-0019: OpenCode を 4 番目の対応ツールとして追加する

- ステータス: 承認済み
- 日付: 2026-08-04

## コンテキスト

これまでの対応ツールは Claude Code / Codex / Cursor の 3 つだった。ここに OpenCode
（調査時点 1.18.12）が加わる。OpenCode を調べると、既存の設計判断をそのまま適用できる
部分と、できない部分がはっきり分かれた。

| 観点 | OpenCode の実態 |
|---|---|
| スキルの探索場所 | ネイティブは `~/.config/opencode/skills`。加えて `~/.claude/skills` と `~/.agents/skills` もスキャンし、**同名スキルは重複排除する** |
| グローバル指示 | ネイティブは `~/.config/opencode/AGENTS.md`。無い場合のみ `~/.claude/CLAUDE.md` へフォールバックする |
| 設定ファイル | `~/.config/opencode/opencode.json`（設定ディレクトリは XDG 準拠） |
| サブエージェント | `.opencode/agents/*.md` — 形式は Claude Code / Cursor と同じ frontmatter + 本文だが、他ツールの配置を互換走査しない |
| hooks | **シェル hooks が無い**。相当機能はプラグイン（JS/TS モジュール） |

特に扱いを決める必要があったのは次の 2 点である。

- **グローバル指示をどこへ書くか。** `~/.claude/CLAUDE.md` へのフォールバックがあるため
  「Claude Code 用に置いたものが自動で効く」が、これはネイティブファイルが不在のときだけ
  成立する。ユーザーが自分で `~/.config/opencode/AGENTS.md` を作った瞬間に
  ハーネスの常駐指示が黙って消える
- **スキルを追加の場所へも配置するか。** Cursor では互換スキャンによる重複表示が問題に
  なった（ADR-0003）。OpenCode は同名を重複排除するため、同じ問題は起きない

## 決定

**OpenCode を 4 番目の対応ツールとして追加する。既存の設計原則（ADR-0003 の配置方針、
ADR-0004 の管理ブロック方式、ADR-0006 の非破壊方針）はそのまま適用し、例外を作らない。**

1. **スキルは `~/.agents/skills/` へ配置する（ADR-0003 の決定は不変）**
   OpenCode はここをネイティブにスキャンし、Claude Code 併用時に `~/.claude/skills` と
   両方から見えても同名は重複排除される。`~/.config/opencode/skills/` への
   二重配置はしない。Cursor 向けのような重複表示の案内も不要
2. **グローバル指示はネイティブの `~/.config/opencode/AGENTS.md` に書く**
   `~/.claude/CLAUDE.md` へのフォールバックには頼らない（ユーザーが自分で
   AGENTS.md を作った時点で無効化されるため）。書き込みは他ツールと同じ管理ブロック方式
   （ADR-0004）。生成物 `opencode/AGENTS.md` を build.sh が出力する
   （現状は Claude / Codex と同内容。差分が必要になった時点で分岐する）
3. **`opencode.json` は `copy_if_absent` で初期配置する。中身は `$schema` 行だけとし、
   コメントを書かない**
   既存ファイルは上書きせず、アンインストールでも削除しない（ADR-0006）。
   OpenCode がコメントを許すのは `opencode.jsonc` の方で、**`.jsonc` は `.json` より
   優先される**（実機確認: 両方あると `.jsonc` の値が勝つ）。雛形を `.jsonc` で配置すると、
   ユーザーの既存 `opencode.json` を消さないまま無効化してしまい、非破壊方針に反する。
   よって配置するのは `opencode.json`、書式は厳密な JSON に限る。
   `permission` / `mcp` の書き方の案内は README 側に置く
4. **設定ディレクトリは `${XDG_CONFIG_HOME:-$HOME/.config}/opencode` で解決する**
   `lib.sh` に `OPENCODE_CONFIG_DIR` として持たせ、テストでは `XDG_CONFIG_HOME` を
   unset して fake HOME 配下に固定する
5. **3 本の creator スキルへ OpenCode の参照資料を追加する**
   - imk-skill-creator: 互換規約を 4 ツールへ拡張（`disable-model-invocation` が
     効かないため、自動発火の抑止は利用者側の `permission.skill` に依存する旨を明記）
   - imk-subagent-creator: `references/opencode.md` とテンプレート、
     `validate-agent.sh` の `opencode` ターゲットを追加
   - imk-hooks-creator: `references/opencode.md` を**プラグイン方式として**追加する。
     他 3 ツールと同じ「イベント名の対応表」だけでは書けないため、
     参照資料を読まずに他ツールの書式を転用しないことを SKILL.md 本体にも書く
6. **harness-check の使用ツール選択肢に OpenCode を加える**
   プロジェクトスコープの配置規約（`AGENTS.md` を読む、スキルは `.agents/skills/`）は
   Codex / Cursor と同じ列に入るため、新しい分岐は増えない

## 検討した代替案

- **`~/.claude/CLAUDE.md` のフォールバックに任せ、OpenCode 向けには何も置かない** —
  ハーネスが管理していないファイル（ユーザーが後から作る AGENTS.md）の有無で
  常駐指示が効いたり消えたりする。「置いたものが効き続ける」保証がなくなるため却下
- **`~/.config/opencode/skills/` にも symlink する** — 重複排除があるため利益がなく、
  掃除対象の配置場所が 1 つ増えるだけ
- **OpenCode 用の常駐指示を別内容にする** — 現時点で分ける理由が無い。
  build.sh は分岐できる形にしてあるので、必要になってから分ける
- **hooks を他 3 ツールと同じ枠組みで扱う（イベント名の対応表だけ足す）** —
  シェルスクリプトを共有できないという最大の差異が伝わらず、
  「stdin の JSON を読む」前提のコードを生成させてしまう

## 結果

- ハーネスの対応ツールは 4 つになり、共有スキルの互換規約も 4 ツール前提になる
  （ADR-0009 の決定内容は不変。適用範囲が広がるだけ）
- 生成物は `claude/CLAUDE.md` / `codex/AGENTS.md` / `opencode/AGENTS.md` の 3 ファイル
- **OpenCode 向けに AGENTS.md を置くと `~/.claude/CLAUDE.md` はグローバル指示として
  読まれなくなる**。内容は同一の生成物なので実害はないが、ユーザーが `~/.claude/CLAUDE.md`
  の管理ブロック外へ書いた個人メモは OpenCode からは見えなくなる。install.sh の
  該当箇所にコメントで残した
- hooks だけは 4 ツールでスクリプトを共有できない。判定ロジックを共通シェルスクリプトに
  置き、OpenCode プラグインからそれを実行する形を推奨に据えた
- OpenCode は未知の frontmatter フィールドをエラーにせず `options` へ吸い込むため、
  他ツールのフィールドを混ぜた誤りが起動時に発覚しない。`validate-agent.sh` による
  機械検査の価値が他ツールより高い
