# Codex permissions 仕様

- 調査日: 2026-08-04
- 一次情報: [Agent approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security)、
  [Config basics](https://learn.chatgpt.com/docs/config-file/config-basic)、
  [Advanced configuration](https://learn.chatgpt.com/docs/config-file/config-advanced)、
  [Rules](https://learn.chatgpt.com/docs/agent-configuration/rules)、
  [Permission profiles](https://learn.chatgpt.com/docs/permissions)

## 全体像

Codexのローカル実行は、主に次の層からなる。

1. **sandbox**: commandが技術的に触れられるfilesystemとnetworkを制限する
2. **approval policy**: sandbox外実行、network、MCP等を人またはauto-reviewへ確認する条件
3. **execpolicy rules**: command prefixごとにsandbox外実行をallow / prompt / forbiddenにする
4. **permission profiles（Beta）**: 従来のsandbox設定を置き換え、filesystemとnetworkを
   named sandbox policyにまとめる新方式

Sandboxとapprovalは独立している。`approval_policy = "never"` でもsandboxは残せるし、
`sandbox_mode = "danger-full-access"` でもapprovalを残せる。両方を外す組み合わせが最も危険。

## 設定スコープと優先順位

| 優先度 | 設定元 |
|---:|---|
| 1 | CLI flags、`-c` / `--config` |
| 2 | trusted projectの `.codex/config.toml`（rootからcwdへ、近いものが勝つ） |
| 3 | `~/.codex/<profile>.config.toml` |
| 4 | `~/.codex/config.toml` |
| 5 | `/etc/codex/config.toml` |
| 6 | built-in default |

組織の `requirements.toml` は選択可能なapproval policy、sandbox mode、network、rules等をさらに
制約できる。projectをuntrustedにすると、project-localのconfig、hooks、rulesをすべて無視する。

CLIとIDE extensionは同じconfig layerを共有する。

## 従来方式: sandbox modeとapproval policy

### sandbox mode

| mode | 境界 |
|---|---|
| `read-only` | 読取のみ。編集やcommand実行等にはapprovalが必要 |
| `workspace-write` | workspaceとtemp内をwrite可、networkは既定off |
| `danger-full-access` | local sandbox制限なし |

`workspace-write` でも `.git`、`.agents`、`.codex` は再帰的にread-onlyで保護される。
`[sandbox_workspace_write].writable_roots` でworkspace外の追加write rootを指定できるが、権限を
広げる設定なので必要なpathだけに限定する。

```toml
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = false
writable_roots = []
exclude_tmpdir_env_var = false
exclude_slash_tmp = false
```

### approval policy

| policy | 動作 |
|---|---|
| `untrusted` | known-safeなread operation以外のcommandを承認対象にする |
| `on-request` | sandbox内は自動、境界外やnetwork等を必要時に承認対象にする |
| `never` | promptを出さず、sandbox内で可能な範囲だけbest effortで進める |
| granular table | prompt categoryごとにinteractive / auto-rejectを選ぶ |

`on-failure` は非推奨。interactive用途は `on-request`、non-interactiveは `never` を使う。

granular policyで制御できるcategory:

- `sandbox_approval`
- `rules`
- `mcp_elicitations`
- `request_permissions`
- `skill_approval`

値が `false` のcategoryは自動許可ではなく、promptを出さずfail-closedで拒否する。

```toml
approval_policy = { granular = {
  sandbox_approval = true,
  rules = true,
  mcp_elicitations = true,
  request_permissions = false,
  skill_approval = false
} }
```

### approval reviewer

既定の `approvals_reviewer = "user"` は人に確認する。`"auto_review"` は、もともとapprovalが
必要なrequestだけを別のreviewer agentに判定させる。reviewerを変えてもsandbox境界は広がらない。
Auto-reviewは追加のmodel callを使い、parse failureやpolicy build failureはfail-closedになる。

### 推奨される代表的な組み合わせ

| 意図 | 設定 |
|---|---|
| 通常の開発 | `workspace-write` + `on-request` |
| 安全な調査 | `read-only` + `on-request` |
| read-only CI | `read-only` + `never` |
| editは許可しcommandを厳しく確認 | `workspace-write` + `untrusted` |
| 危険なfull access | `danger-full-access` + `never` / `--yolo` |

networkは `workspace-write` で既定off。必要な場合のみ
`sandbox_workspace_write.network_access = true` とする。network proxy機能を併用すればdomain
allowlistを構成できるが、network access自体を有効にする設定とは別である。

`allow_login_shell = false` はshell-based toolのlogin shellを拒否し、startup file経由の
予期しない環境変更やsecret継承を減らすhardeningになる。

## execpolicy rules

Rulesは「どのcommandをsandbox外で実行できるか」を制御する。sandbox内の全commandを一般的に
allow / denyする仕組みではない。

配置場所はactive config layerの隣の `rules/`。代表例:

- User: `~/.codex/rules/default.rules`
- Project: `<repo>/.codex/rules/default.rules`（trusted projectだけ）

```python
prefix_rule(
    pattern = ["git", ["status", "diff", "log"]],
    decision = "allow",
    justification = "読み取り専用のGit調査だけを許可する",
    match = [
        "git status --short",
        "git diff --stat",
    ],
    not_match = [
        "git push origin main",
    ],
)
```

### decision

| decision | 動作 |
|---|---|
| `allow` | sandbox外でpromptなしに実行 |
| `prompt` | 一致するたびに確認 |
| `forbidden` | promptせず拒否 |

複数ruleに一致した場合は `forbidden` > `prompt` > `allow`。`pattern` はargvの完全なprefixで、
各要素はliteralまたはliteralの選択肢にできる。`match` / `not_match` はload時のinline testとして
誤ったruleを検出する。

単純なcompound shell commandはsubcommandへ分解してrule評価され、最も厳しいdecisionが勝つ。
redirection、変数、glob、control flow等を含むscriptは安全に分解できないため、shell wrapper全体を
1 invocationとして評価する。

検証コマンド:

```sh
codex execpolicy check --pretty \
  --rules .codex/rules/default.rules \
  -- git status --short
```

`allow` はsandbox外実行を事前承認する強い設定である。projectのlint / testがworkspace sandbox内で
完結するなら、rulesへallowを追加する必要はない。

## permission profiles（Beta）

Permission profilesはfilesystemとnetworkを1つのnamed policyへまとめる新方式である。

- built-in: `:read-only`、`:workspace`、`:danger-full-access`
- `default_permissions` で選択する
- custom profileは `[permissions.<name>]` に定義する
- `extends = ":workspace"` でbuilt-inの保護を引き継げる

```toml
default_permissions = "project-edit"

[permissions.project-edit]
description = "Workspace write without network"
extends = ":workspace"

[permissions.project-edit.filesystem.":workspace_roots"]
"<検証ループで使わないsecret file>" = "deny"

[permissions.project-edit.network]
enabled = false
```

重要な制約:

- Betaであり変更される可能性がある
- `default_permissions` / `[permissions]` と、従来の `sandbox_mode` /
  `[sandbox_workspace_write]` を併用しない
- loaded configのどこかに `sandbox_mode` があると従来方式が選ばれる
- `extends = ":workspace"` は `.git` / `.codex` 等のbaseline protectionを引き継ぐ
- filesystem denyはより広いread / writeより優先される
- filesystem denyはsandbox内の対象pathへの読取・書込を拒否する
- networkは明示的にenabledにし、allow domainがなければ外部宛先をblockする
- MCP、connector、browser、Computer Use、cloudはprofileとは別のcontrolを持つ
- approved escalationもprofile外のcontrolであり、profileのdenyを絶対的な禁止とはみなさない

harness-checkではユーザーのApprove for meを維持し、対応versionでactive configに旧
`sandbox_mode`が無ければPermission Profileをsandbox定義の既定案にする。path deny対象がなくても、
workspaceとnetwork境界をprofileで定義する。旧設定または `--sandbox` と競合する場合は、移行するか
従来方式を維持するかを確認し、project外の設定を無断で変更しない。

## 安全な既定値を設計するときの要点

- Approve for me / Auto-reviewはユーザー設定として維持し、projectから上書きしない
- Permission Profile採用時は `:workspace` を継承し、network offを出発点にする。検証で常用する
  localhost / domainだけをallowし、必要なpath denyは検証に使わないsecretへ限定する
- path denyはagentが起動するlint / test / buildが使わないsecretだけに設定する。検証用envは
  非本番・低権限にし、実行可能性を保つ
- 従来sandboxを維持する場合は `workspace-write` + network offを基準にする
- より慎重な選択肢として `untrusted` を提示する
- `danger-full-access`、`never`との危険な組み合わせ、`--yolo`を既定にしない
- `.rules` のallowはsandbox外実行の許可なので、必要なcommandだけargv単位で絞る
- `writable_roots`、network access、Unix socketを不用意に追加しない
- `allow_login_shell = false` の互換性を確認し、問題がなければhardening候補にする
- `/permissions` と `/status` で実効値を確認する
- projectをuntrustedにした場合にproject config / rulesが無視されることも検証する
