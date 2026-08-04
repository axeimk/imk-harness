# Permissions 仕様調査 — Claude Code / Codex / Cursor

- 調査日: 2026-08-04
- 目的: harness-check がプロジェクト固有の permissions を提案するときに、3 ツールの
  現行仕様と安全上の差異を踏まえた既定値を設計できるようにする
- 対象: ローカルで動く Claude Code、Codex CLI / IDE、Cursor Agent / CLI
- 対象外: クラウドエージェント固有の隔離環境、認証・課金・組織ロール

## ドキュメント構成

| ファイル | 内容 |
|---|---|
| [claude-code.md](claude-code.md) | permission rules、permission mode、Bash sandbox、設定スコープ |
| [codex.md](codex.md) | approval policy、sandbox、execpolicy rules、permission profiles |
| [cursor.md](cursor.md) | IDE の Run Modes / sandbox と CLI の permission token |

## 結論

3 ツールに「同じ permissions ファイル」を配ることはできない。似た名前の機能でも、
承認判断とOSレベルの隔離を担う層が異なる。

| 観点 | Claude Code | Codex | Cursor |
|---|---|---|---|
| プロジェクト設定 | `.claude/settings.json` | `.codex/config.toml`、`.codex/rules/*.rules` | IDE: `.cursor/permissions.json` / `.cursor/sandbox.json`、CLI: `.cursor/cli.json` |
| 承認の基本単位 | tool call と tool-specific specifier | sandbox 外実行、ネットワーク、rules、MCP 等 | IDE: Run Mode と分類器、CLI: permission token |
| 決定的な許可・拒否 | `allow` / `ask` / `deny` | `.rules` の `allow` / `prompt` / `forbidden`（sandbox 外実行） | CLI の `allow` / `deny`。IDE Auto-review の自然言語指示は非決定的 |
| OSレベル隔離 | Bash sandbox（別設定、任意で有効化） | sandbox が基本。workspace-write は workspace 内のみ書込可 | terminal sandbox。Run Mode とは別層 |
| harness-checkの基準 | ユーザーのAuto mode + sandbox + 小さいallowlist | Approve for me + Permission Profile（競合時は従来sandbox） | Auto-review + terminal sandbox |
| 最危険な設定 | `bypassPermissions` / `--dangerously-skip-permissions` | `danger-full-access` + `never` / `--yolo` | Run Everything / `unrestricted` / `insecure_none` |

## 共通して守るべき設計原則

### 承認と隔離を別物として扱う

「確認なしで実行できる」ことと「実行されても被害範囲が限定される」ことは別である。

- 承認ルールは、どの操作を自動実行するかを決める
- sandbox は、実行されたプロセスが読める・書ける場所と到達できるネットワークを制限する
- allowlist だけでは、許可したプログラムの脆弱性、引数、設定ファイル、子プロセスまで隔離できない
- sandbox だけでは、workspace 内のソースやビルドスクリプトを破壊する操作を防げない

安全な既定値は両方を組み合わせる。

### 許可は具体的に、拒否は防御の補助にする

- `git`、`npm`、`docker`、`gh`、`aws` のようなコマンド全体を許可しない
- lint / test / build のように、リポジトリが定義した具体的なコマンドを許可する
- 外部状態を変更する `push`、公開、デプロイ、クラウド操作は既定で許可しない
- 秘密情報は「読まないよう指示する」だけでなく、Read deny や sandbox の deny で保護する
- deny と allow の優先順位や例外可否はツールごとに異なるため、共通文字列を生成しない

### プロジェクト設定を信頼境界として扱う

clone したリポジトリには攻撃者が用意した設定も含まれ得る。Claude Code と Codex は、
プロジェクトが権限を広げる設定を workspace trust の対象にする。Cursor はIDEのworkspace
trustが既定で無効なため、リポジトリ設定だけを信頼境界にしてはいけない。

### ネットワークを既定で広く開けない

ソース、環境変数、credential file を読めるプロセスに無制限の外向き通信を与えると、
prompt injection や依存パッケージ経由の情報流出経路になる。依存取得が必要な場合も、
registry や公式配布元のドメインに限定する。

### 設定ファイル自身を保護する

エージェントが自分の permissions、hooks、IDE設定、Git hooks を書き換えられると、次回実行で
権限を拡大できる。3ツールとも一部の設定パスを保護するが、sandbox 無効化や外部実行では
保護が外れる場合がある。

## harness-check の安全な既定値に向けた判断材料

ここでは設計方向を記録する。実際の提案手順とテンプレートはharness-checkスキル側で管理する。

1. **まずプロジェクトの検証コマンドを特定する**: lint、typecheck、unit test、build のうち、
   ローカル完結し、外部状態を変更せず、対象リポジトリ内に書くものだけを候補にする
2. **読み取り系を必要以上に列挙しない**: ツールが既定で安全扱いする読み取り操作は重複して
   allowlist に入れない。特に `git` コマンド全体を許可しない
3. **workspace 内書き込み + network off を基準にする**: OS sandbox を持つツールでは、
   workspace 外書き込みとネットワークを既定で閉じる
4. **検証ループと秘密保護を両立する**: `.env*`、秘密鍵、credential directory は、プロジェクトで
   実際に使うファイルを確認したうえで、検証に不要なものだけRead / filesystem denyの候補にする。
   agentが起動するtestやappが読むenvは開発専用・低権限にし、denyして検証を壊さない。Claude Codeは
   sandbox内shellにもdenyを統合でき、Codex profileのdenyはsandbox内の読取・書込を拒否する。
   Cursorの`.cursorignore`はterminalからの読取を防がないため、同等の保証と説明しない
   agentがcommandやapp codeを制御できるため、同じprocess treeへの環境変数注入だけでは
   secret boundaryにならない。本物のsecretが必要なら低権限・短命credentialや隔離環境を使う
5. **読めるenvは承諾制にする**: 検証用envをdenyしない場合は、built-in Read、shell、dotenvを使う
   test / app、log、dependency等からagentが値へ到達し得ることを先に示す。本番credential、長期token、
   service account key、秘密鍵等を置かない前提についてユーザーの承諾を得てから適用する
6. **外部副作用は常に承認対象にする**: push、release、deploy、package publish、クラウド更新、
   MCP / connector の書き込み操作を既定の自動許可へ入れない
7. **危険モードを提案しない**: bypass / full access / unrestricted は、既にコンテナやVMなどの
   外側の隔離があり、ユーザーが明示した場合だけ検討する
8. **実効設定を確認する**: 設定ファイルを書くだけで終わらず、各ツールの status / permissions
   表示と、許可・拒否される代表コマンドで確認する

## 調査上の注意

- Codex の permission profiles は調査時点で Beta。従来の `sandbox_mode` 系を置き換える
  sandbox policyであり、同一sessionでは同時利用できない。approval policyとは併用できる
- Cursor の Auto-review は分類器による best-effort guardrail であり、セキュリティ境界ではない
- Cursor 3.5 以降は旧 Ask Every Time が非推奨、3.6 では Auto-review が推奨既定となった
- Claude Code の permission / sandbox は短期間で機能追加が続いている。既定値実装時には再確認する
- プロジェクト設定より組織管理ポリシーが強く、ローカル設定で弱められない場合がある

## 一次情報

### Claude Code

- <https://code.claude.com/docs/en/permissions>
- <https://code.claude.com/docs/en/permission-modes>
- <https://code.claude.com/docs/en/sandboxing>
- <https://code.claude.com/docs/en/settings>

### Codex

- <https://learn.chatgpt.com/docs/agent-approvals-security>
- <https://learn.chatgpt.com/docs/config-file/config-basic>
- <https://learn.chatgpt.com/docs/config-file/config-advanced>
- <https://learn.chatgpt.com/docs/agent-configuration/rules>
- <https://learn.chatgpt.com/docs/permissions>

### Cursor

- <https://cursor.com/docs/agent/security>
- <https://cursor.com/docs/agent/security/run-modes>
- <https://cursor.com/docs/reference/sandbox>
- <https://cursor.com/docs/cli/reference/permissions>
- <https://cursor.com/docs/cli/reference/configuration>
