# imk-harness

Claude Code / Codex / Cursor 用の汎用ハーネス（ユーザー層の設定・知識・規約の一式）。

方針:

- **汎用層（このリポジトリ）は最小限に保つ。** 個人的な好み、共通 permissions、そして「プロジェクト特化層の育て方」の規約だけを持つ。
- **特化層は各プロジェクトのリポジトリで育てる。** ビルド・テスト方法、アーキテクチャ知識、プロジェクト固有スキルはそちらに置く。
- **昇格ルール:** 2〜3 プロジェクトで同じものを書いたと気づいたら、そのときはじめて汎用層へ移す。

## 構成

```
imk-harness/
├── shared/
│   ├── instructions/      # 指示の原本（単一ソース）。編集するのはここ
│   │   ├── 00-style.md            # 応答・ドキュメントのスタイル
│   │   ├── 10-workflow.md         # 作業の進め方（verify 必須など）
│   │   └── 20-project-harness.md  # 特化層の育て方の規約
│   └── skills/            # スキルの実体（ツール非依存の SKILL.md 形式）
│       └── harness-check/ #   特化層をブートストラップするスキル（テンプレート同梱）
├── claude/
│   ├── CLAUDE.md          # 生成物（build.sh が作る）→ ~/.claude/CLAUDE.md の管理ブロックへ
│   └── settings.json      # 共通 permissions の雛形
├── codex/
│   ├── AGENTS.md          # 生成物（build.sh が作る）→ ~/.codex/AGENTS.md の管理ブロックへ
│   └── config.toml        # Codex 設定の雛形
├── build.sh               # 原本から CLAUDE.md / AGENTS.md を生成
├── install.sh             # 使うツールを選んで最適配置で展開（再実行 = アップデート）
├── uninstall.sh           # ハーネス由来の symlink を除去し、バックアップを復元
└── lib.sh                 # install/uninstall 共通ヘルパー
```

## 使い方

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

## CLAUDE.md / AGENTS.md は「管理ブロック」方式

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

## スキルの配置ポリシー

各ツールがネイティブに読む場所へ symlink する。Codex の公式スキャン場所は `.agents/skills`（オープン標準）で、description による自動発火が効く。

| 選択 | スキルの物理配置 | 補足 |
|---|---|---|
| Claude のみ | `~/.claude/skills/` | |
| Codex のみ | `~/.agents/skills/` | Codex 公式のスキャン場所 |
| Cursor のみ | `~/.agents/skills/` | Cursor もネイティブに読む |
| Claude + Codex | `~/.claude/skills/` と `~/.agents/skills/` の両方 | |
| Claude + Cursor | `~/.claude/skills/` のみ | Cursor が互換読みで認識。重複なし |
| Codex + Cursor | `~/.agents/skills/` のみ | 両ツールともネイティブ。重複なし |
| 3 つすべて | `~/.claude/skills/` と `~/.agents/skills/` の両方 | Cursor に同名スキルが二重に見える可能性があるが許容（Codex の自動発火を優先） |

Claude Code が `.agents/skills` に対応したら（望み薄）、正本を `~/.agents/skills/` の 1 箇所に寄せて単純化する予定
（[anthropics/claude-code#31005](https://github.com/anthropics/claude-code/issues/31005) をウォッチ）。

## 育て方の優先順位

1. permissions と verify の規約（承認疲れをなくし、自己検証させる）
2. 常駐指示（薄く保つ）
3. スキル（繰り返した作業から 1 つずつ）
4. hooks（「毎回言っても守らない」ことが出てきたら強制へ昇格）
5. MCP / サブエージェント（必要になってから）
