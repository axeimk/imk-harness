# OpenCode の Agent Skills 仕様

- 調査日: 2026-08-04
- 一次情報: <https://opencode.ai/docs/skills/>、<https://opencode.ai/docs/rules/>、
  ローカルの opencode 1.18.12（`opencode debug skill` で実機確認）
- 位置づけ: Agent Skills 標準に忠実（`name` / `description` の制約は標準どおり）。
  特徴はネイティブの `~/.config/opencode/skills/` に加え、**`~/.claude/skills/` と
  `~/.agents/skills/` もスキャンし、同名スキルを重複排除する**こと

## 配置場所

| 種別 | プロジェクト | ユーザー |
|---|---|---|
| ネイティブ | `.opencode/skills/<name>/SKILL.md` | `~/.config/opencode/skills/<name>/SKILL.md` |
| 互換 | `.claude/skills/`、`.agents/skills/` | `~/.claude/skills/`、`~/.agents/skills/` |

- プロジェクト側のパスは、カレントディレクトリから git worktree ルートまで
  祖先をたどりながら検出される
- **同名スキルは重複排除される**（実機確認: `~/.claude/skills/` と `~/.agents/skills/` の
  両方に同名を置くと 1 件のみ表示される）。Cursor のような重複表示・
  third-party 設定の問題は起きない。ただし**どちらのルートが採用されるかは実行ごとに
  変わる**（`opencode debug skill` を繰り返すと `location` が入れ替わる。スキャンが
  並行しており先着順のため）。同名で内容の違うスキルを複数ルートに置いてはいけない
- 無効化の環境変数: `OPENCODE_DISABLE_CLAUDE_CODE=1`（`.claude` 系すべて）、
  `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1`（`.claude/skills` のみ）、
  `OPENCODE_DISABLE_EXTERNAL_SKILLS=1`（`~/.claude/` と `~/.agents/` のスキャン）
- 追加登録: `opencode.json` の `skills.paths`（ディレクトリ配下を `**/SKILL.md` で
  再帰スキャン）と `skills.urls`

## SKILL.md フロントマター

| フィールド | 必須 | 制約・挙動 |
|---|---|---|
| `name` | ○ | 1〜64 文字。英小文字・数字・ハイフンのみ（先頭/末尾/連続ハイフン不可）。**ディレクトリ名と一致必須** |
| `description` | ○ | 1〜1024 文字。欠落したスキルはフィルタされ、モデルに提示されない |
| `license` | × | |
| `compatibility` | × | |
| `metadata` | × | string→string のマップ |

未知のフィールドは無視される（Claude Code の `allowed-tools` や Cursor の `paths` 等は
解釈されない）。

## 呼び出しと権限

- スラッシュコマンド記法はない。エージェントがネイティブの `skill` ツールで
  名前指定して読み込む（利用可能なスキルの一覧はツール説明に提示される）
- 読み込み権限は `opencode.json` の `permission.skill`（`allow` / `deny` / `ask`、
  ワイルドカード対応）。エージェント単位の上書き、`tools: { skill: false }` で
  スキル自体の無効化も可能

## グローバル指示（Rules）

- グローバル: `~/.config/opencode/AGENTS.md`
- 優先順位: プロジェクトの `AGENTS.md` / `CLAUDE.md` → `~/.config/opencode/AGENTS.md`
  → `~/.claude/CLAUDE.md`（フォールバック）
- **`~/.config/opencode/AGENTS.md` が存在すると `~/.claude/CLAUDE.md` はグローバル指示
  として読まれない**（各カテゴリで最初にマッチしたファイルのみが有効）
- `opencode.json` の `instructions` フィールドで追加の指示ファイル（glob・URL 可）を
  合流させられる

## ハーネスへの示唆

- スキルは `~/.agents/skills/` への配置で足りる（ネイティブスキャン + 重複排除）。
  `~/.config/opencode/skills/` への二重配置は不要
- グローバル指示はネイティブの `~/.config/opencode/AGENTS.md` に書く（フォールバックの
  `~/.claude/CLAUDE.md` 頼みだと、ユーザーが自分で AGENTS.md を作った瞬間に消える）。
  内容は同一の生成物なので実害はないが、配置の決定は [ADR-0003](../adr/0003-skill-placement.md) に記録
