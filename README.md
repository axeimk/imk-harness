# imk-harness

Claude Code / Codex 用の汎用ハーネス（ユーザー層の設定・知識・規約の一式）。

方針:

- **汎用層（このリポジトリ）は最小限に保つ。** 個人的な好み、共通 permissions、そして「プロジェクト特化層の育て方」の規約だけを持つ。
- **特化層は各プロジェクトのリポジトリで育てる。** ビルド・テスト方法、アーキテクチャ知識、プロジェクト固有スキルはそちらに置く。
- **昇格ルール:** 2〜3 プロジェクトで同じものを書いたと気づいたら、そのときはじめて汎用層へ移す。

## 構成

```
imk-harness/
├── shared/instructions/   # 指示の原本（単一ソース）。編集するのはここ
│   ├── 00-style.md        #   応答・ドキュメントのスタイル
│   ├── 10-workflow.md     #   作業の進め方（verify 必須など）
│   └── 20-project-harness.md  # 特化層の育て方の規約
├── claude/
│   ├── CLAUDE.md          # 生成物（build.sh が作る）→ ~/.claude/CLAUDE.md
│   ├── settings.json      # 共通 permissions の雛形
│   └── skills/
│       └── harness-check/ # 特化層をブートストラップするスキル（テンプレート同梱）
├── codex/
│   ├── AGENTS.md          # 生成物（build.sh が作る）→ ~/.codex/AGENTS.md
│   └── config.toml        # Codex 設定の雛形
├── build.sh               # shared/instructions/ から CLAUDE.md / AGENTS.md を生成
└── install.sh             # ~/.claude / ~/.codex へ symlink（既存ファイルはバックアップ）
```

## 使い方

```sh
./build.sh     # 原本から CLAUDE.md / AGENTS.md を再生成
./install.sh   # ホームディレクトリへ展開（build.sh も内部で実行される）
```

- 指示を変えたいときは `shared/instructions/` を編集して `./build.sh`。symlink 運用なので再インストールは不要。
- `~/.claude/settings.json` と `~/.codex/config.toml` は既存ファイルがある場合は上書きしない（install.sh がその旨を表示する）。permissions は `claude/settings.json` の内容を手動でマージすること。

## 育て方の優先順位

1. permissions と verify の規約（承認疲れをなくし、自己検証させる）
2. 常駐指示（薄く保つ）
3. スキル（繰り返した作業から 1 つずつ）
4. hooks（「毎回言っても守らない」ことが出てきたら強制へ昇格）
5. MCP / サブエージェント（必要になってから）
