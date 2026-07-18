# 3 ツール互換規約 — どのツールで読まれても本文が成立するように書く

同一の SKILL.md が Claude Code / Codex / Cursor から読まれる前提のスキルが従う規約。
各ツールは他ツール向けの拡張をエラーにせず無視するため、この「無視される」性質を
吸収機構として使う。要約は 1 行: **どのツールで読まれても本文が成立すること**。

機械検査: `scripts/validate-skill.sh <skill-dir>`

## 1. 必須の共通コア

- `name`: 親ディレクトリ名と一致。英小文字・数字・ハイフンのみ
  （先頭・末尾・連続ハイフン不可）、64 文字以内
- `description`: 必須・1024 文字以内。Codex では欠落がロードエラーになり、
  他ツールでも自動発火の生命線。「何をするか」と「いつ使うか」の両方を書く
  （書き方は description-guide.md）

## 2. 禁止 — 本文の意味を変えるツール固有プレースホルダ

Claude Code の動的コンテキスト注入と引数展開は、Codex / Cursor では展開されず
**生テキストのままモデルに渡り、指示文が壊れる**。共有スキルでは使わない:

- `` !`command` `` （インラインの動的コンテキスト注入）
- 行頭 ```` ```! ```` のフェンスブロック（ブロック形の動的注入）
- `$ARGUMENTS`、`$0` `$1` 等の位置引数、`${CLAUDE_*}` の環境変数置換

代替手段:

- コマンド実行が必要 → 「次のコマンドを実行し、出力を確認する」と本文で指示する
  （どのツールでもエージェント自身が実行できる）
- 引数が必要 → 「ユーザーの依頼から対象を読み取る」前提で本文を書く

## 3. 許可 — 加算的フロントマター

対応しないツールでは単に無視されるフィールドは書いてよい。
条件は **無視されても本文が成立すること**（本文がフィールドの効果に依存しない）。

| フィールド | 効くツール | 用途 |
|---|---|---|
| `disable-model-invocation` | Claude Code / Cursor | 自動発火の禁止（明示起動専用化） |
| `paths` | Claude Code / Cursor | 対象ファイルの glob 限定 |
| `allowed-tools` | Claude Code | 発火中のツール事前承認 |
| `license` / `compatibility` / `metadata` | 標準フィールド（解釈はツール差あり） | 補足情報 |

## 4. Codex 固有指定は agents/openai.yaml に分離

`agents/openai.yaml` は Codex だけが読む拡張ファイルで、他ツールは無視する。
UI 表示・依存・発火ポリシーの Codex 向け指定はここに書き、SKILL.md 本体を汚さない。

```yaml
interface:
  display_name: "人間向けの表示名"
  short_description: "UI 一覧用の短い説明（25〜64 文字）"
  default_prompt: "$skill-name を使って〜する"
policy:
  allow_implicit_invocation: true
```

- 文字列値はすべて引用符で囲む。キーは囲まない
- `default_prompt` は `$skill-name` 形式でスキル名を明示した 1 文にする
- `icon_small` / `icon_large` / `brand_color` は素材の提供があった場合のみ書く

## 5. 自動発火を禁止するスキル（唯一の二重管理点）

明示起動専用にするスキルは、**両方**に書く:

- フロントマター: `disable-model-invocation: true`（Claude Code / Cursor 向け）
- `agents/openai.yaml`: `policy.allow_implicit_invocation: false`（Codex 向け）

片方だけだと一部ツールで自動発火してしまう。validate-skill.sh が整合を検査する。

## 6. 配置場所の目安

| スコープ | Claude Code | Codex | Cursor |
|---|---|---|---|
| ユーザースコープ | `~/.claude/skills/` | `~/.codex/skills/`（`~/.agents/skills/` も可） | `~/.agents/skills/` |
| プロジェクトスコープ | `.claude/skills/` | `.agents/skills/` | `.agents/skills/` |

ツールのバージョンによって探索場所は変わりうるので、確信が持てない場合は
対象ツールのドキュメントで確認する。

複数ツールで同じスキルを使う場合、スキルディレクトリの実体は 1 箇所に置き、
他の探索場所からは symlink を張る（コピーを複数置くと乖離する）。実体の置き場所:

- **プロジェクトスコープ**: `.agents/skills/<name>/` に実体を置き、Claude Code 用には
  `.claude/skills/<name>` → `../../.agents/skills/<name>` の symlink を張る。
  `.agents` は Codex / Cursor がネイティブに読むツール非依存の場所で、
  Claude Code も対応が見込まれているため、対応後は symlink を消すだけで一本化できる
  （逆向きに置くと将来実体の引っ越しが要る）。単一ツールのプロジェクトでは
  そのツールのネイティブ位置に直接実体を置き、symlink は張らない
- **ユーザースコープ**: 原本リポジトリで管理しているならその原本ディレクトリが実体で、
  リポジトリの展開スクリプトが各ツールの探索場所へ symlink する。原本に新しい
  スキルを書いた後、展開手順を再実行しないと symlink が張られない点に注意する。
  リポジトリが無ければプロジェクトスコープと同じ理由で `~/.agents/skills/` を実体にする

## 7. 展開先で解決できない参照を書かない

スキルは作られた場所から別の環境へ配布されうる。スキル内の参照は
スキルディレクトリ内の相対パス（`references/xxx.md` 等）に限る。
作成元リポジトリの文書・設計記録・issue 番号への参照は、配布先では解決できず
読み手を混乱させるので書かない。
