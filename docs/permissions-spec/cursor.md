# Cursor permissions 仕様

- 調査日: 2026-08-04
- 一次情報: [Agent Security](https://cursor.com/docs/agent/security)、
  [Run Modes](https://cursor.com/docs/agent/security/run-modes)、
  [sandbox.json reference](https://cursor.com/docs/reference/sandbox)、
  [CLI Permissions](https://cursor.com/docs/cli/reference/permissions)、
  [CLI Configuration](https://cursor.com/docs/cli/reference/configuration)

## 全体像

Cursorは、Desktop / IDEのlocal Agentとstandalone CLIで設定面が分かれる。

### Desktop / IDE

1. **Run Mode**: tool callをいつ止めて承認するか
2. **Auto-review instructions**: classifierの許可・block判断を自然言語で誘導する
3. **terminal sandbox**: commandのfilesystem / network accessをOSで制限する
4. **built-in protections**: browser、file deletion、workspace外file操作を追加保護する

### CLI

1. **approvalMode / sandbox設定**: User-levelのCLI実行方針
2. **permission token**: Shell / Read / Write / WebFetch / MCPをallow / denyする

IDEのAuto-review instructionとCLIのpermission tokenは同じ構文ではない。

## Desktop / IDEの既定動作

公式Agent Securityによる既定:

- workspace内のfile readとcode searchは承認不要
- workspace内のfile editは、設定ファイルを除き承認不要で即時保存される
- terminal commandは既定で承認が必要
- MCP connectionと各tool callは承認が必要。特定toolはallowlist可能
- built-in network toolはGitHub、direct link retrieval、web search provider等に限定される
- VS Code由来のworkspace trustは対応するが、既定で無効

ファイル編集自体が既定で自動であるため、version controlによる復元可能性が重要である。
auto-reloadが有効なアプリでは、編集内容のreview前にcodeが実行される可能性もある。

## Run Modes

設定場所は **Settings > Agents > Approvals & Execution**。

| mode | 自動実行 | sandbox | classifier |
|---|---|---|---|
| Auto-review | allowlist済みcall、sandbox可能なshell、classifierが許可したcall | shellで使用 | 使用 |
| Allowlist | allowlist済みaction。sandbox有効時は対応shellをsandbox内実行 | 任意 | なし |
| Run Everything | 全tool call | なし | なし |

公式は大半の利用者にAuto-reviewを推奨している。ただしclassifierは誤判定し得るbest-effort
guardrailで、セキュリティ境界ではない。決定的な挙動が必要なら、小さいAllowlistとsandboxを使う。

Cursor 3.5以降、旧Ask Every Timeは非推奨。空のAllowlistが同等の動作になる。3.6では
Auto-reviewが推奨既定になった。Cloud Agentsは専用machineで動くためRun Modesを使わない。

## Auto-review instructions

| スコープ | ファイル |
|---|---|
| User | `~/.cursor/permissions.json` |
| Project | `<repo>/.cursor/permissions.json` |

両方があればmergeされる。Team dashboardのglobal設定がある場合はそちらが優先され、user / project
fileは無視される。

```json
{
  "autoRun": {
    "allow_instructions": [],
    "block_instructions": [
      "Every git push command should go through approval first.",
      "Every command that publishes a package should go through approval first.",
      "Every command that modifies cloud resources should go through approval first."
    ]
  }
}
```

- `allow_instructions`: Auto-reviewがallow寄りに判断する自然言語指示
- `block_instructions`: 別手段の選択またはuser approval寄りに判断する自然言語指示

これはclassifierへの指示であり、決定的なdeny ruleではない。機密性・破壊性が高い操作の強制には、
sandbox、CLI deny、team policy、外部のcredential / IAM制限等も必要である。

## terminal sandbox

Run Modeとは別層で、sandbox可能なshell commandの到達範囲を制限する。

### 既定境界

- workspaceはread / write可
- `.git/config`、`.git/hooks`、`.vscode`、`.cursorignore`、agent設定等は保護
- `/tmp` とplatform tempは既定でwrite可
- networkはsandboxのnetwork modeと `sandbox.json` に従う
- sandbox外実行が必要なcommandは、その旨を表示してapprovalを求める

macOSはSeatbelt、LinuxはLandlock + seccompを使う。Linuxで必要なkernel機能がなければ、
sandbox実行ではなくapprovalへfallbackする。

### sandbox.json

| スコープ | ファイル | 優先度 |
|---|---|---:|
| User | `~/.cursor/sandbox.json` | 低 |
| Project | `<repo>/.cursor/sandbox.json` | 高 |

Team policyとhardcoded security ruleがさらに上に重なり、local fileから弱めることはできない。

```json
{
  "type": "workspace_readwrite",
  "disableTmpWrite": false,
  "enableSharedBuildCache": false,
  "additionalReadwritePaths": [],
  "additionalReadonlyPaths": [],
  "networkPolicy": {
    "default": "deny",
    "allow": ["registry.npmjs.org"],
    "deny": []
  }
}
```

| field | default | 意味 |
|---|---|---|
| `type` | `workspace_readwrite` | `workspace_readonly`、`insecure_none`も選択可 |
| `additionalReadwritePaths` | `[]` | workspace外の追加read / write path |
| `additionalReadonlyPaths` | `[]` | workspace外の追加read-only path |
| `disableTmpWrite` | `false` | trueならtemp writeを外す |
| `enableSharedBuildCache` | `false` | build cacheを共有tempへredirect |
| `networkPolicy.default` | `deny` | unmatched destinationの扱い |
| `networkPolicy.allow` / `deny` | `[]` | domain、wildcard、CIDR rule |

network denyはallowより優先する。private address、loopback、cloud metadata endpointは既定でblock。
network modeの既定は「sandbox.json + Cursor defaults」で、package manager等の多数のdomainが
追加許可される。最小権限にするには「sandbox.json Only」を選び、必要domainだけallowする。

常にwrite-protectされる主なpath:

- `.cursor/*.json`、`.cursor/**/*.json`、`.cursor/.workspace-trusted`
- `.claude/*.json`、`.claude/**/*.json`
- `.vscode/**`、`.code-workspace`
- `.git/hooks/**`、`.git/config`、`.git/info/attributes`
- `.cursorignore`

一方、`.cursor/rules/`、`commands/`、`worktrees/`、`skills/`、`agents/` はwrite可能。

## CLI permission token

### 設定場所

| スコープ | ファイル | 内容 |
|---|---|---|
| User | `~/.cursor/cli-config.json` | 全CLI設定 |
| Project | `<repo>/.cursor/cli.json` | permissionsだけ |

`approvalMode` は `allowlist`、`auto-review`、`unrestricted`。project fileではpermissions以外を
設定できないため、harness-checkがprojectへ配置できるのはallow / deny tokenだけである。

```json
{
  "permissions": {
    "allow": [
      "Shell(ls)",
      "Shell(git:status *)",
      "Read(src/**)"
    ],
    "deny": [
      "Shell(rm)",
      "Read(.env*)",
      "Write(**/.env*)",
      "Write(**/*.key)"
    ]
  }
}
```

### token種別

| token | 対象 | 例 |
|---|---|---|
| `Shell(commandBase)` | shell commandの先頭token | `Shell(ls)`、`Shell(curl:*)` |
| `Read(pathOrGlob)` | file / directory read | `Read(src/**/*.ts)` |
| `Write(pathOrGlob)` | file / directory write | `Write(package.json)` |
| `WebFetch(domainOrPattern)` | web fetch destination | `WebFetch(docs.github.com)` |
| `Mcp(server:tool)` | MCP server / tool | `Mcp(datadog:search)` |

globは `**`、`*`、`?` を使う。relative pathはworkspace基準。denyがallowより優先する。
`Shell` の `command:args` 形式で引数を絞れるが、`Shell(git)` は全subcommandを許可するため広すぎる。
`Mcp(*:*)`、`WebFetch(*)`、`Write(**)` もproject既定には適さない。

## 安全な既定値を設計するときの要点

- IDEではAuto-reviewを選ぶ場合も、classifierがsecurity boundaryではないと明記する
- 決定性を優先する選択肢として、空または小さいAllowlist + sandboxを提示する
- `Run Everything`、CLI `unrestricted`、sandbox `insecure_none` を既定にしない
- project `sandbox.json` は `workspace_readwrite`、追加pathなし、network deny-by-defaultを基準にする
- network modeは「sandbox.json Only」を推奨候補にし、必要domainだけ追加する
- `.cursor/permissions.json` のblock instructionと `.cursor/cli.json` のdeny tokenを混同しない
- CLIではcommand全体でなく、安全なsubcommand / argsまで絞る
- `.env*`、秘密鍵をRead / Write deny候補にする。ただしIDEのbuilt-in file accessには
  `.cursorignore` も併用する。`.cursorignore`とCLIのRead denyはterminal sandboxのpath denyではなく、
  workspace内の `cat`、`sed`、Python等による読取は保証して防げない。この性質により検証commandは
  `.env`を読めるが、実行環境には本番credentialを置かない
- workspace trustが既定offであることを説明し、untrusted repoには別の隔離も検討する
