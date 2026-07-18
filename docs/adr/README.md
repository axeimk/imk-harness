# Architecture Decision Records

このリポジトリの設計判断の記録。新しい決定をしたら連番で追加し、過去の決定を覆す場合は
新しい ADR を起こして古い方のステータスを「廃止（ADR-XXXX により置換）」に変更する。

| ADR | タイトル | ステータス |
|---|---|---|
| [0001](0001-two-layer-harness.md) | 汎用層と特化層の 2 層構造 | 承認済み |
| [0002](0002-single-source-instructions.md) | 指示ファイルの単一ソース生成 | 承認済み |
| [0003](0003-skill-placement.md) | スキルは各ツールのネイティブディレクトリへ symlink 配置 | 承認済み |
| [0004](0004-managed-block.md) | CLAUDE.md / AGENTS.md は管理ブロック方式 | 承認済み |
| [0005](0005-plan-confirm-apply.md) | install / uninstall はプラン表示 → 確認 → 適用の 2 段階実行 | 承認済み |
| [0006](0006-non-destructive-policy.md) | ユーザーの持ち物に触れない非破壊方針 | 承認済み |
| [0007](0007-verify-skill-as-runtime-recipe.md) | プロジェクト verify スキルは動作確認レシピとする | 承認済み |
| [0008](0008-propose-record-respect.md) | 汎用層は強制しない — 提案 → 記録 → 尊重 | 廃止（ADR-0011 により置換） |
| [0009](0009-skill-graceful-degradation.md) | 共有スキルのツール間差異はネイティブ吸収で扱う | 承認済み |
| [0010](0010-domain-modeling-and-grilling.md) | ユビキタス言語と設計記録の規律を mattpocock/skills から輸入する | 廃止（ADR-0016 により置換） |
| [0011](0011-pull-based-harness-check.md) | 特化層整備を harness-check に一任し、採否を HARNESS.md に記録する | 承認済み |
| [0012](0012-automated-tests-with-bats.md) | 自動テストを bats で導入する（npm devDependency 管理） | 承認済み |
| [0013](0013-adr-path-in-project-layer.md) | ADR 記録の経路を特化層に常駐させる | 承認済み |
| [0014](0014-tdd-skill-in-project-layer.md) | TDD 手順を特化層の tdd スキルとして提供する | 承認済み |
| [0015](0015-workflow-rules-in-project-layer.md) | 作業の進め方はプロジェクトスコープが定める | 承認済み |
| [0016](0016-harness-growing-mission.md) | ミッションを「プロジェクトスコープのハーネス育成」に特化する | 承認済み |
