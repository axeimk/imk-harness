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
| [0008](0008-propose-record-respect.md) | 汎用層は強制しない — 提案 → 記録 → 尊重 | 承認済み |
| [0009](0009-skill-graceful-degradation.md) | 共有スキルのツール間差異はネイティブ吸収で扱う | 承認済み |
