# imk-harness

Claude Code / Codex / Cursor 用の汎用ハーネス（ユーザースコープの設定・知識・規約の一式）。
ホームディレクトリ（`~/.claude/` `~/.codex/` `~/.agents/`）へ展開して使う。

この README は**ハーネスを導入・運用する人**向け。読みたいこと別の入口:

| 読みたいこと | 場所 |
|---|---|
| 導入・更新・アンインストールの手順と挙動 | この README |
| このリポジトリを変更する（開発ガイド・アーキテクチャ・テスト） | [CLAUDE.md](CLAUDE.md)（`AGENTS.md` は同一内容） |
| 設計判断とその経緯 | [docs/adr/](docs/adr/README.md) |
| 3 ツールの Skills 仕様の調査資料 | [docs/skills-spec/](docs/skills-spec/README.md) |
| 用語集 | [CONTEXT.md](CONTEXT.md) |

## 考え方

**このリポジトリの本質は「各プロジェクトの特化層を育てるためのハーネス」である。**
一番大事な持ち物は個々の設定ではなく、特化層の育て方の規約・それを実行する
harness-check スキル・特化層で実証されたものを還流させる昇格ルールの 3 つ。

| 層 | スコープ | 実体 |
|---|---|---|
| **汎用層**（このリポジトリ） | **ユーザースコープ** | `~/.claude/` `~/.codex/` `~/.agents/` に展開される。全プロジェクト共通 |
| **特化層**（各プロジェクトで育てる） | **プロジェクトスコープ** | 各リポジトリ内の CLAUDE.md / AGENTS.md / `.claude/` / HARNESS.md 等。そのプロジェクト専用 |

- **汎用層（このリポジトリ）は最小限に保つ。** 個人的な好み、共通 permissions、そして「プロジェクト特化層の育て方」の規約だけを持つ。
- **特化層は各プロジェクトのリポジトリで育てる。** ビルド・テスト方法、アーキテクチャ知識、プロジェクト固有スキルはそちらに置く。
- **特化層の整備は pull 型。** エージェントが自発的に提案するのではなく、ユーザーが harness-check スキルを明示的に実行したときだけ整備が走る（→ 次節）。
- **昇格ルール:** 2〜3 プロジェクトで同じものを書いたと気づいたら、そのときはじめて汎用層へ移す。

育てる順番は、permissions と verify の規約（承認疲れをなくし、自己検証させる）→
常駐指示（薄く保つ）→ スキル（繰り返した作業から 1 つずつ）→
hooks（「毎回言っても守らない」ことの強制）→ MCP / サブエージェント（必要になってから）。

## インストール

```sh
./install.sh                              # 対話式で使うツールを選ぶ
./install.sh --tools claude,codex,cursor  # ツールを指定
./install.sh --tools claude --dry-run     # 変更予定の表示のみ
./install.sh --tools claude --yes         # 確認をスキップ（CI 等）
./uninstall.sh                            # アンインストール（--yes / --dry-run も可）
```

- install / uninstall は**実行前に変更予定の一覧を表示し、y/N の確認を取ってから適用する**。変更がなければ何もしない。
- 指示を変えたいときは `shared/instructions/` を編集して `./install.sh` を再実行（管理ブロックが更新される）。
- 手動対応が必要な項目（設定ファイルのマージ、バックアップの確認など）は、実行の最後にまとめて表示される。
- `~/.claude/settings.json` と `~/.codex/config.toml` は既存ファイルがある場合は上書きしない。permissions は `claude/settings.json` の内容を手動でマージすること。
- 既存の実ファイルを置き換える場合は `.bak.<timestamp>` に退避される。

## 各プロジェクトへの導入 — harness-check を明示実行する

インストールで置かれるのはユーザースコープの汎用層だけで、**各プロジェクトの特化層は自動では作られない**。
新しいプロジェクトでハーネスを使い始めるとき（および特化層を見直したいとき）は、
そのプロジェクトで **harness-check スキルを明示的に実行する**
（Claude Code, Cursor なら `/harness-check`、Codex なら `$harness-check` で起動できる）。

harness-check は次を行う:

1. 特化層の現状確認 — CLAUDE.md / AGENTS.md、verify スキル、CONTEXT.md（用語集）、
   lint / test hooks、`.claude/settings.json`（プロジェクト permissions）、`HARNESS.md` の有無
2. 欠けているものを項目ごとに提示し、**要る / 要らないをユーザーが選ぶ**（勝手に全部は作らない）
3. 採否をプロジェクトルートの **`HARNESS.md`** に記録する。「使わない」と記録した項目は、
   以後どのエージェントも再提案しない

エージェントの側から特化層の整備を持ちかけることはない（pull 型 —
経緯は [ADR-0011](docs/adr/0011-pull-based-harness-check.md)）。
旧規約で CLAUDE.md / AGENTS.md の「ハーネス」節に採否を記録していたプロジェクトでは、
harness-check が `HARNESS.md` への移行を提案する。

## ホーム側の CLAUDE.md / AGENTS.md は「管理ブロック」方式

`~/.claude/CLAUDE.md` と `~/.codex/AGENTS.md` は symlink ではなく実ファイルで、ハーネスはマーカーで囲まれたブロックだけを管理する。**ブロックの外は自由編集エリア**で、アップデートでもアンインストールでも保持される。

```markdown
ここは自由編集エリア。個人メモや端末固有の指示を書ける。

<!-- >>> imk-harness:begin >>> -->
（ハーネスが生成した共通指示。install.sh 再実行でこの中だけ更新される）
<!-- <<< imk-harness:end <<< -->

ここも自由編集エリア。
```

ブロックの中を直接編集しても次の `./install.sh` で上書きされるので、共通指示の変更は `shared/instructions/` で行うこと。

## アップデート / アンインストール

**アップデートは install.sh の再実行。** そのとき次を自動で行う（すべて事前のプラン表示・確認つき）:

- CLAUDE.md / AGENTS.md の管理ブロック更新（ブロック外は保持）
- スキル symlink の張り直し
- ツールの選択を変えた場合、外したツール向けの配置物を除去し、バックアップがあれば復元
- リポジトリから削除したスキルの宙吊りリンクを除去
- 旧バージョンの配置場所（`~/.codex/skills`、symlink 方式の CLAUDE.md 等）の移行・掃除

**uninstall.sh** は管理ブロックとハーネス由来の symlink を除去する。管理ブロックしかないファイルは削除し、退避してあった最新のバックアップを復元する。

エッジケースの扱い:

| ケース | 挙動 |
|---|---|
| CLAUDE.md / AGENTS.md にユーザーが追記した内容 | 管理ブロックの外にある限り、アップデート・アンインストールでも保持 |
| 旧バージョン（symlink 方式）からの移行 | install が symlink を実ファイル化し、バックアップがあれば内容を引き継いだうえでブロックを追記 |
| ハーネス由来かの判定（スキル） | symlink 先が「このリポジトリ配下」かで判定。ユーザーが自分で置いたスキル・ファイルには触れない |
| リポジトリを移動した | 旧パスを指すリンク切れは、パスに `imk-harness` を含む場合のみ掃除対象。基本は移動前に `./uninstall.sh` を実行すること |
| settings.json / config.toml | コピー配置のため、アップデートに追従しない・アンインストールでも削除しない（サマリで案内） |
| バックアップが複数ある | 復元されるのは最新の 1 つのみ。残りはサマリで案内 |
| 複数クローンからのインストール | 想定しない（1 クローンを正とする） |

## スキルの配置

実体は `shared/skills/` にあり、install.sh が選択したツールのネイティブなスキャン場所へ
symlink する（Claude Code: `~/.claude/skills/`、Codex / Cursor: `~/.agents/skills/`）。
どこに何が張られるかは install 時のプラン表示で確認できる。

ツールの組み合わせごとの配置・Cursor での重複表示の扱い・決定の経緯は
[ADR-0003](docs/adr/0003-skill-placement.md) を参照。Claude Code が `.agents/skills` に
対応した時点で `~/.agents/skills/` の 1 箇所に統合する予定。
