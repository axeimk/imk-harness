# Claude Code permissions 仕様

- 調査日: 2026-08-04
- 一次情報: [Permissions](https://code.claude.com/docs/en/permissions)、
  [Permission modes](https://code.claude.com/docs/en/permission-modes)、
  [Sandboxing](https://code.claude.com/docs/en/sandboxing)、
  [Settings](https://code.claude.com/docs/en/settings)

## 全体像

Claude Code は、次の3層を組み合わせる。

1. **permission rules**: tool call を `allow` / `ask` / `deny` に振り分ける
2. **permission mode**: 未許可の tool call を人に聞くか、自動承認・自動拒否するかを決める
3. **Bash sandbox**: Bash と子プロセスの filesystem / network access をOSで制限する

permission rules は全ツール、sandbox は Bash とその子プロセスだけに作用する。Read / Edit /
Write のbuilt-in tool、MCP、Computer UseはBash sandboxの外で、それぞれpermission systemに従う。

## 設定スコープと優先順位

| スコープ | ファイル | 用途 |
|---|---|---|
| Managed | OS管理領域またはserver-managed settings | 組織が強制する設定 |
| User | `~/.claude/settings.json` | 全プロジェクトに対する個人設定 |
| Project | `<repo>/.claude/settings.json` | Gitで共有するプロジェクト設定 |
| Local | `<repo>/.claude/settings.local.json` | 共有しない個人・プロジェクト設定 |

通常のscalar設定は Managed > CLI > Local > Project > User の順で優先される。permission ruleは
単純上書きではなく各scopeからマージされ、どこか1か所のdenyでもallowを打ち消す。

Projectの `permissions.allow` と `permissions.additionalDirectories` は能力を広げるため、workspace
trustを受け入れるまで適用されない。`deny` と `ask` は制限を強めるだけなのでtrust前から適用される。

## permission rules

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(./check-shell.sh)",
      "Bash(git status *)"
    ],
    "ask": [
      "Bash(git push *)"
    ],
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)"
    ],
    "defaultMode": "default"
  }
}
```

### 評価順

`deny` > `ask` > `allow` の順で評価され、最初に一致した種類が勝つ。具体性は優先順位を
逆転させない。たとえば `deny: Bash(aws *)` と `allow: Bash(aws s3 ls)` を併記しても、
後者は例外にならない。

- bare tool deny（例: `Bash`）はツール自体をモデルのcontextから除去する
- scoped deny（例: `Bash(rm *)`）はBashを残し、一致したcallだけ拒否する
- `ask` はallowより強く、特定操作を常に確認させる用途に使える

### 構文

基本形は `Tool` または `Tool(specifier)`。

| 例 | 意味 |
|---|---|
| `Bash` / `Bash(*)` | Bash全体 |
| `Bash(npm run test)` | 完全一致するcommand |
| `Bash(npm run test *)` | prefix + word boundary |
| `Read(./.env)` | project-relativeのファイル読取 |
| `Edit(./src/**)` | 対象pathへの編集 |
| `WebFetch(domain:example.com)` | 指定domainへのfetch |
| `mcp__github__get_*` | 特定serverのMCP tool名glob |
| `Agent(model:opus)` | top-level input parameterが一致するcall |

`*` は空白を含む任意文字列に一致する。`Bash(ls *)` は `ls` と `ls -la` に一致するが
`lsof` には一致しない。`Bash(ls*)` は `lsof` にも一致する。末尾の `:*` は末尾 ` *` と同義。

compound commandは `&&`、`||`、`;`、pipe、newlineなどで分解され、各subcommandが独立に
許可される必要がある。安全なprefixの後ろに別commandを連結してallowを迂回する設計には
なっていない。

一方、実行wrapperの許可には注意が必要である。`npx`、`docker exec`、`devbox run` などは
後続引数を任意commandとして実行できるため、wrapper全体を広く許可せずinner commandまで
固定する。

### Read / Edit と秘密情報

working directory内の通常のread-only toolは既定で承認不要である。秘密情報を守るには、
CLAUDE.mdで「読まない」と指示するのではなく、`Read` denyまたはsandbox filesystem denyを使う。

編集の許可とBash subprocessの書込許可は関連する。公式仕様では `Edit` allow ruleがsandboxの
外部pathへのwrite accessにも寄与し、Read / Edit denyもsandboxの最終設定へマージされる。

## permission modes

`permissions.defaultMode` または実行中のmode選択で決まる。

| mode | 動作 | 既定値への適性 |
|---|---|---|
| `default` / `manual` | 初回利用時に通常の確認を行う | 安全な共通既定として適する |
| `acceptEdits` | workspace内の編集と一部filesystem commandを自動承認 | 書込範囲を理解した個人向け |
| `plan` | 基本的に調査のみでsourceを編集しない | read-only調査向け |
| `auto` | safety classifierがrequestとの整合性を確認して自動承認 | 分類器によるbest-effort |
| `dontAsk` | allow済み以外を自動拒否 | 非対話・fail-closed用途 |
| `bypassPermissions` | 明示ask等を除きpromptをskip | 隔離済みcontainer / VM以外では使わない |

`permissions.disableBypassPermissionsMode: "disable"` と
`permissions.disableAutoMode: "disable"` で、それぞれのmodeを利用不可にできる。組織強制には
Managed scopeが適する。

## Bash sandbox

### 性質と既定境界

SandboxはmacOSのSeatbelt、Linux / WSL2のbubblewrap等を使う。native Windowsは非対応。
有効化は `/sandbox` または `sandbox.enabled: true` で行う。

有効時の基本境界:

- working directoryとsession temp directoryは書込可
- 新しいnetwork domainは初回承認が必要
- settings.jsonは自動的にwrite-protectされる
- Bashのchild processにも同じ境界が適用される

Sandboxが起動できない場合は、既定では警告してunsandboxedで実行する。このfallbackを安全な
失敗に変えるのが `failIfUnavailable: true` である。また `allowUnsandboxedCommands: false` は、
sandbox内で失敗したcommandを `dangerouslyDisableSandbox` で再試行するescape hatchを無効にする。

```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "allowUnsandboxedCommands": false,
    "filesystem": {
      "denyRead": ["~/.ssh", "~/.aws"]
    },
    "network": {
      "allowedDomains": ["registry.npmjs.org"]
    }
  }
}
```

### sandboxのapproval mode

- **auto-allow**: sandbox内で実行可能なBash commandを自動承認する
- **regular permissions**: sandbox内でも通常のpermission flowを通す

どちらもOSの隔離境界は同じ。違いはpromptを省くかだけである。明示deny、内容を絞ったask、
critical pathを消す `rm` 等はauto-allowでも別途制御される。

### filesystem / network設定

| 設定 | 用途 |
|---|---|
| `sandbox.filesystem.allowWrite` | workspace外の限定pathをwrite可能にする |
| `denyWrite` / `denyRead` | subprocessの書込・読取を拒否する |
| `allowRead` | deny領域内の限定pathを再許可する |
| `filesystem.disabled` | filesystem隔離だけを無効化する。Project scopeからは設定不可 |
| `network.allowedDomains` | Bash subprocessの到達domainを許可する |
| `network.deniedDomains` | domainを明示拒否する |
| `excludedCommands` | 特定commandをsandbox外で実行する |

write許可をshell startup、`PATH`上の実行ファイル、Git hooks、IDE / agent設定へ広げると、後続の
unsandboxed実行を乗っ取れる。Docker socket等のUnix socket許可もhost全体への権限に等しい場合が
ある。`excludedCommands` はsandboxの保護を失うため最後の手段にする。

## 安全な既定値を設計するときの要点

- harness-checkではユーザーが選んだAuto modeをproject設定から上書きせず、
  外部副作用のないproject commandだけをallowする
- `Bash(git *)`、`Bash(npm *)`、`WebFetch(*)` のような広い許可を避ける
- `.env*`、秘密鍵、credential directoryは、agentが起動する検証commandで使わないものだけ
  Read deny / sandbox denyを検討する。Read denyがsandbox filesystemへ統合されると `cat` 等の
  child processにも効き、dotenvを使うtestやappも読めなくなる。検証用envは非本番・低権限にする
- sandboxを有効化するなら、可能な環境では `failIfUnavailable: true` と
  `allowUnsandboxedCommands: false` を組み合わせる
- network domainは必要なregistry / docs hostだけを許可する
- `bypassPermissions` と `filesystem.disabled` をprojectの既定値にしない
- `/permissions`、`/sandbox`、`/status` でresolved settingsを確認する
