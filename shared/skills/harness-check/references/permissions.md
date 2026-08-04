# プロジェクト permissions の設計

Claude Code / Codex / Cursor のプロジェクト設定を、承認疲れを増やさず比較的安全にするための
手順。permissions を提案・作成・見直すときだけ読む。

## 目次

- [目標](#目標)
- [作成手順](#作成手順)
- [Claude Code](#claude-code)
- [Codex](#codex)
- [Cursor](#cursor)
- [検証と記録](#検証と記録)

## 目標

ユーザーが選んだ Auto-review 系のモードを維持し、その判断が働く範囲を sandbox で限定する。

- Claude Code: Auto mode
- Codex: Approve for me / Auto-review
- Cursor: Auto-review

これらはユーザーが選ぶ実行モードであり、プロジェクト設定から有効化・上書きしない。
プロジェクトには次の4種類だけを置く。

1. 安全性を確認したプロジェクト固有コマンドの事前許可
2. workspace 外書き込みと network を狭める sandbox 境界
3. Auto-review / classifierで審査する少数の高リスク操作、または実行させない操作
4. 検証ループを壊さない、プロジェクトで使用しない秘密情報へのアクセス拒否

## 作成手順

### 1. 実在するコマンドを収集する

CLAUDE.md / AGENTS.md、package.json、Makefile、pyproject.toml、CI設定等から、lint、test、
typecheck、build、dry-run の実コマンドを確認する。コマンド名や引数を推測しない。

次の基準で分類する。

| 分類 | 例 | 扱い |
|---|---|---|
| 安全 | lint、test、typecheck、workspace内のbuild、dry-run | 正確な形だけallow候補 |
| 自動レビュー | 未知のcommand、依存取得、通常のworkspace編集 | Auto-reviewへ任せる |
| 高リスク | push、force、reset、clean、release、deploy、publish、cloud更新 | ask、block、forbidden候補 |
| 拒否 | プロジェクトで禁止された公開・本番操作 | deny / forbidden候補 |

`git`、`npm`、`docker`、`gh`、`aws` のようなcommand全体を許可しない。wrapperやpackage
scriptの後ろで任意コードを実行できるため、subcommandと引数を含む具体的な形に絞る。

### 2. `.env` 系の保護と検証ループを両立する

`.env*`、秘密鍵、credential file等の存在と用途をファイル名、設定、検証commandから確認し、
中身は読まない。まずlint、test、build、dev server等をagentが起動するときに、どの環境fileを
読むかを特定する。次のpathはsecret候補として必ず調査するが、無条件のdeny対象にはしない。

- project rootの `.env`
- project rootの `.env.local`
- project rootの `.env.*.local`

subdirectoryにあるものと、`.env.production` 等の上記に含まれない既存ファイルは、走査で見つけた
正確なrelative pathを追加して分類する。次の公開用テンプレートはdeny候補から除外する。

- `.env.example`
- `.env.sample`
- `.env.template`
- `.env.dist`

denyはallowより強く例外を作れないツールがあるため、`.env*` のような広いruleを使わない。

| 分類 | 既定の扱い |
|---|---|
| agentの検証ループが読む、非本番・低権限の環境 | denyしない。検証commandが動くことを優先する |
| 検証ループが使わないsecret | 正確なpathを強いdeny候補にする |
| 検証ループが読む本物のsecret | denyと検証を両立できない。低権限・短命なcredentialや隔離環境への移行を提案する |

検証ループ用には `.env.test`、`.env.agent` 等の専用fileまたは同等の仕組みを優先する。名前は
projectのloaderが実際に対応するものを調査し、推測で新設しない。既存appが `.env` 固定なら、
その `.env` を開発専用・低権限にする案を示す。production credentialを入れたfileをagentへ渡さない。

| ツール | built-in Read | `cat`等のシェル読取 | 書込 |
|---|---|---|---|
| Claude Code | `Read(...)` deny | sandbox起動中は同じdenyがfilesystem境界へ統合される | `Edit` / `Write`は別途判断 |
| Codex | Permission Profileのfilesystem deny | sandbox内では同じpath denyが効く | 同じdenyで書込も拒否 |
| Cursor | `.cursorignore` / CLI `Read(...)` deny | workspace内の任意path denyを保証できない | CLI `Write(...)`等を別途判断 |

Codexのfilesystem denyはRead専用ではない。dotenvを読むtestやappも失敗するため、適用前に
実行時の利用有無と影響を示す。Claude CodeもRead denyがsandboxへ統合されるため、同じ影響を受ける。
agentが起動するappやtestが対象fileを必要とする場合はpath denyを既定で省く。強い保護を求める場合は、
低権限・短命なcredential、専用container / VM、またはagentが直接扱わないbroker等へ移行できるかを
1問で確認する。agentがcommandとapp codeを制御できる以上、単に環境変数として同じprocess treeへ
注入するだけでは、表示・ログ出力・送信を防ぐsecret boundaryにならない。
Claude CodeとCursorでEdit / Writeも保護する案は1問で別途確認するが、環境設定をエージェントに
更新させるプロジェクトでは強制しない。Cursorでシェルからも隠す必要がある秘密はworkspace外または
secret managerへ移し、`.cursorignore`だけをsecurity boundaryと説明しない。その他の秘密鍵・
credential fileは、用途を確認して使わないものだけdeny候補にする。

### 3. `.env`を読める状態にする前に承諾を得る

検証ループのために `.env` 系をdenyしない場合は、対象pathを中身なしで列挙し、agentが次の経路で
内容へ到達する可能性を説明する。

- built-in Readやcontext収集で直接読む
- `cat`、`grep`、`sed`、Python等のshell commandで読む
- lint、test、build、dev serverがdotenv等で読み、child processへ渡す
- error、debug log、snapshot、test report、trace、crash outputへ値が出る
- dependency、package install script、build plugin等がfileまたはprocess environmentを読む
- agentが編集したcodeやtestが、値を表示・保存・network送信できる
- direnv等でprocess environmentへ先に読み込んでも、同じprocess treeから参照できる

この説明は「agentが意図的に読む」という予告ではなく、検証commandを制御できる以上、技術的に
秘匿境界を作れないことの説明である。承諾後も、必要性なく内容を読ませたり、値をchat、diff、log、
`HARNESS.md`へ記録したりしない。

次の意味を含む1問で承諾を得る。対象pathは実際に検出したものへ置き換える。

> `<対象path>` は検証ループで使用するため、agentとそのsubprocessから読める状態を維持します。
> ここには開発・test専用の低権限な値だけを置き、本番credential、長期OAuth refresh token、
> service account key、秘密鍵、個人用token、無制限なcloud credential等の本当に大切なsecretを
> 設定しない前提で、この扱いを承諾しますか？

ユーザーがすでに開発・test専用の低権限envとして使う意図を示している場合は、mock、CI分離、
container等の選択を承諾前に増やさず、この1問へ直接進む。承諾されない場合、または本番・長期・
広権限credentialを使う必要が判明した場合だけ、代替案を提示する。

承諾された場合だけpath denyを省く。承諾されない場合は強いdenyを維持し、検証専用env、短命な
credential、専用container / VM等へ検証方法を変更する案を示す。承諾はsecret内容の読取許可ではなく、
技術的に読み得る境界への同意である。`HARNESS.md`には対象path、前提、判断日だけを記録し、値や
credential識別子は書かない。

### 4. 変更案を適用前に示す

次を分けて提示し、1回に1問の確認方法に従って採否を聞く。

- 新しくpromptなしで実行可能になる操作
- Auto-reviewへ残る操作
- Auto-review / classifierで審査される、または拒否される操作
- 読めなくなる / 書けなくなるpath
- workspace外writeとnetworkの範囲

モード自体は変更しないことも明示する。既存設定がある場合は上書きせず、差分をmergeする。

### 5. シェル通信と組み込みWeb機能を分ける

`npm install`、`curl`、test中のHTTP通信はシェルsandboxのnetwork境界を受ける。一方、各ツールの
組み込みWeb検索、Fetch、MCPは別の権限経路を持つ。networkを閉じる案では次も説明する。

- Claude Codeで `allowUnsandboxedCommands: false` にする場合、必要なregistry等は
  `sandbox.network.allowedDomains`へ追加しない限りシェル通信できない
- Codexでsandbox networkを無効にしたcommandはapproval / Auto-reviewへ昇格を申請できるが、
  組み込みWeb検索はcommandのnetwork設定とは別である
- Cursorの「sandbox.json + Defaults」はpackage manager向け組み込みdomainを追加する。
  厳密に閉じる場合は「sandbox.json Only」をユーザーが選ぶ必要がある

依存取得先を許可しても、install scriptや取得物の実行リスクまでは防げない。domainは実際に必要な
registryと公式配布元へ絞り、組み込みWeb機能の許可と混同しない。testやdev serverがlocalhost、
database、mock server、外部APIへ接続する場合もあるため、exactな検証commandの依存先を調査し、
必要なhost / domainだけを追加する。network offを理由に検証ループを壊さない。

## Claude Code

配置は `.claude/settings.json`。ユーザーのAuto modeを維持するため、プロジェクト設定に
`permissions.defaultMode` を書かない。プロジェクトの `defaultMode: "auto"` は無視され、
`defaultMode: "default"` 等はユーザー設定を上書きしてAuto modeを解除し得る。

推奨する処理経路:

| 操作 | 処理 |
|---|---|
| 確認済みのlint / test / build | `permissions.allow`で即実行 |
| その他 | Auto modeのclassifierへ任せる |
| 明示した高リスク操作 | `permissions.ask`で人へ戻す |
| 禁止操作・秘密情報 | `permissions.deny` |
| Bashの実被害範囲 | sandboxで制限 |

土台。配列の内容は調査結果とユーザーの選択で増減する。

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(<確認済みの検証コマンド>)"
    ],
    "ask": [
      "Bash(git push *)",
      "Bash(git reset --hard *)",
      "Bash(git clean *)"
    ],
    "deny": [
      "Read(./<検証ループで使わないsecret file>)"
    ]
  },
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": false,
    "allowUnsandboxedCommands": false
  }
}
```

`autoAllowBashIfSandboxed: false` により、sandbox内のBashもAuto modeのclassifierを通す。
これを省略すると既定値trueによりsandbox内のBashがclassifierを経ず自動承認される。
`allowUnsandboxedCommands: false` はsandbox失敗後のunsandboxed再試行を止める。
`Read(...)` denyはsandboxのfilesystem境界へ統合されるため、sandbox起動中は `cat`、`sed`、
Python等のchild processによる対象pathの読取も拒否する。

`failIfUnavailable: true` はsandbox非対応・依存不足でClaude Code自体を起動不可にするため、
組織管理環境やStrict設定としてユーザーが選んだ場合だけ加える。native Windowsではsandboxが
非対応なので、WSL2等を使わないプロジェクトにはsandboxを既定適用しない。これを設定しない場合、
sandbox起動失敗時は警告後にunsandboxedで動き、シェル経由のpath保護は保証されないことを伝える。

`ask` はAuto modeの利点を消さないよう、外部副作用や復旧困難な操作だけに絞る。denyはallowより
優先され、狭いallowで例外を作れないため、広いdenyを安易に追加しない。

確認には `/permissions`、`/sandbox`、`/status` を使う。

## Codex

配置は `.codex/config.toml` と、必要な場合だけ `.codex/rules/*.rules`。CLIとIDEは同じ
config layerを使う。project configはtrusted projectでだけ読み込まれ、user configより優先する。

Approve for meを維持するため、プロジェクト設定に `approval_policy` と
`approvals_reviewer` を書かない。これらはユーザー設定または実行時のモード選択に任せる。

Betaのpermission profilesは、従来のsandbox設定を置き換えてfilesystemとnetworkをまとめる。
Codexのversionを確認し、対応version（0.138.0以降）かつ旧設定との競合がなければ、未使用secretの
有無にかかわらずPermission Profileをsandbox定義の既定案にする。検証に不要なsecretがある場合だけ、
そのprofileへpath denyを追加する。

Permission profileを選ぶ前に、すべてのactive config layerと起動引数を確認する。次のいずれかに
`sandbox_mode`または `[sandbox_workspace_write]` があれば従来sandboxが選ばれ、projectの
`default_permissions`は効かない。

- projectの `.codex/config.toml`
- userの `~/.codex/config.toml`
- 選択中の `~/.codex/<profile>.config.toml`
- system config
- `--sandbox` 起動引数

project外の設定を勝手に編集しない。競合があれば、移行対象と影響を示してユーザーに確認する。
競合時は **Permission Profileへ移行** または **従来sandboxを維持** の2案を1問で選んでもらう。
permission profilesはBetaなので、非対応versionや移行を選ばなかった場合は従来sandbox案を使い、
Codexではpath単位のdenyが効かないことを適用前と `HARNESS.md` に記録する。

Permission Profileの土台。既存の追加workspace rootは持ち込まず、`approval_policy`と
`approvals_reviewer`は別層なので書かない。

```toml
default_permissions = "project-safe"
allow_login_shell = false

[permissions.project-safe]
extends = ":workspace"

[permissions.project-safe.network]
enabled = false
```

検証ループで使わないsecretがある場合だけ、次を同じprofileへ追加する。

```toml
[permissions.project-safe.filesystem.":workspace_roots"]
"<検証ループで使わないsecret file>" = "deny"
```

- `extends = ":workspace"` でworkspace writeと`.git` / `.codex`等の保護を引き継ぐ
- filesystemの`deny`はsandbox内の読取と書込を拒否する。Read専用denyとして説明しない
- networkはoffを出発点にし、検証ループが常用するlocalhost / domainは正確にallowする。
  単発の依存取得等はapproval / Auto-reviewへ任せる
- `allow_login_shell = false` でshell startup経由の予期しない環境・secret継承を減らす。
  プロジェクトのtoolchainがlogin shellを必要とする場合は省く
- project-specificなprofile名が既存layerのprofile名と衝突しないことを確認する

Permission Profileはlocal sandboxed commandの境界であり、sandboxを無効にする設定ではない。
従来の `sandbox_mode` を置き換える新しいsandbox policyとして扱う。approved escalation、MCP、
connector、built-in browser、Computer Use、cloudは別controlなので、`.env` denyを絶対的な禁止と
説明しない。Approve for meは昇格要求を審査するが、classifierはsecurity boundaryではない。

従来sandboxを選んだ場合の土台。project configはuserのread-only等を上書きするため、影響を説明して
同意された場合だけ置く。

```toml
sandbox_mode = "workspace-write"
allow_login_shell = false

[sandbox_workspace_write]
network_access = false
writable_roots = []
```

Execpolicy rulesの `allow` はsandbox外実行の事前承認であり、通常のlint / testを許可する
仕組みではない。既定では生成しない。Approve for me使用時の `prompt` はauto-reviewerへ
送られ、必ず人へ戻る指定ではないため、重複するprompt ruleも増やさない。

プロジェクトとして絶対に実行させない操作が明文化されている場合だけ `forbidden` を使う。

```python
prefix_rule(
    pattern = ["npm", "publish"],
    decision = "forbidden",
    justification = "公開操作はユーザーが明示的に実行する",
)
```

確認には `/permissions`、`/status` を使う。trusted projectでなければ `.codex/` のconfigと
rulesは読み込まれないことも確認する。

## Cursor

IDEのRun Modeはユーザー設定なので、プロジェクトから変更しない。Auto-reviewを使う場合は、
`.cursor/permissions.json` に少数のblock instruction、`.cursor/sandbox.json` に実行境界を置く。

```json
{
  "autoRun": {
    "allow_instructions": [],
    "block_instructions": [
      "Force pushes, package publishing, deployments, and destructive cloud operations should require user approval."
    ]
  }
}
```

block instructionはclassifierへの助言であり、強制的なsecurity boundaryではない。
`allow_instructions` は既定で空にし、安全と確認した操作でもclassifierに任せる。

```json
{
  "type": "workspace_readwrite",
  "additionalReadwritePaths": [],
  "additionalReadonlyPaths": [],
  "networkPolicy": {
    "default": "deny",
    "allow": [],
    "deny": []
  }
}
```

Cursorのnetwork modeが「sandbox.json + Defaults」だと組み込みdomainが追加される。
厳密なallowlistが必要なら、ユーザーに「sandbox.json Only」の選択を案内する。

Cursor IDEでは `.cursorignore` に `.env` 系の正確なpathを追加し、built-in file accessとcontext
収集から隠す。公開用テンプレートを隠さないため `.env*` のような広いpatternは使わない。
これはterminal sandboxのpath denyではなく、workspace内の `cat`、`sed`、Python等による読取を
保証して防げない。そのためCursorでは`.cursorignore`に入れてもagentが起動した検証commandは
`.env`を読める。`Shell(cat)`だけを拒否しても別commandで迂回できるため、secret boundaryの
代替にしない。

```gitignore
.env
.env.local
.env.*.local
```

Cursor CLIを使う場合は `.cursor/cli.json` にpermissionsだけを置ける。`approvalMode` は
user-levelなのでprojectから変更しない。`Shell(git)` や `Shell(npm)` のような広い許可は避け、
確認済みのcommandと `.env` 系の正確なRead denyを置く。

```json
{
  "permissions": {
    "allow": [],
    "deny": [
      "Read(.env)",
      "Read(.env.local)",
      "Read(.env.*.local)"
    ]
  }
}
```

## 検証と記録

設定後は各ツールでresolved settingsを確認し、次の代表経路を観察する。破壊的・外部副作用の
ある操作を検証目的で実行しない。dry-run、存在しないremote、無害なfixture等を使う。

1. allowした検証コマンドがuser promptなしで動く
2. allowしていない通常操作がAuto-reviewへ残る
3. Claude Codeのaskまたは各ツールの拒否設定が意図どおり働く
4. sandbox外writeとnetworkが自動で素通りしない
5. exactなlint / test / build commandが必要な検証用envを読める状態で成功する
6. Claude CodeとCodexは、検証に不要としてdenyしたsecret fixtureだけをsandbox内shellで読めない
7. Cursorはbuilt-in/context読取を拒否できる一方、workspace内shellからは読めるという境界を確認する
8. Edit / Write保護も選んだ場合は、secret fixtureを書き換えられない

`HARNESS.md` には、採用したファイル、Auto-review系モードをユーザー設定として維持したこと、
sandboxとnetworkの境界、個別に許可・拒否した操作を記録する。Codexはpermission profileを
採用したか、従来sandboxのためpath denyが効かないかも記録する。Cursorは`.cursorignore`が
terminal読取を防がないこと、Claude Codeは `failIfUnavailable` の採否も記録する。検証ループが
読むenv file、agentが読み得る経路を説明して承諾を得た日、そこには本当に大切なsecretを置かない
前提、denyした未使用secretも記録する。secret値やcredential識別子は記録しない。
