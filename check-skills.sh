#!/usr/bin/env bash
# shared/skills/ の各スキルが共有規約（ADR-0009: graceful degradation）を満たすか検査する。
# スキルの追加・変更時に実行する。エラーがあれば非 0 で終了する。
#
# スキル単体の検査ロジックは imk-skill-creator スキルに同梱の validate-skill.sh に
# 委譲する（展開先でも同じ検査ができるよう、原本をスキル側に置く）。
# ここではループと、リポジトリ専用の検査（内部参照の混入）だけを行う。
set -uo pipefail
cd "$(dirname "$0")"

validator="shared/skills/imk-skill-creator/scripts/validate-skill.sh"
if [ ! -x "$validator" ]; then
  echo "ERROR: ${validator} がありません（実行権限も確認）"
  exit 1
fi

errors=0
for dir in shared/skills/*/; do
  dir="${dir%/}"
  skill="$(basename "$dir")"

  "$validator" "$dir" || errors=$((errors + 1))

  # リポジトリ専用: 展開先で解決できないリポジトリ内部参照の混入を防ぐ（CLAUDE.md の方針）。
  # 禁止は「このリポジトリの ADR への参照」（ADR 番号、docs/adr へのリンク）。
  # 展開先プロジェクト自身の置き場を散文で案内する `docs/adr/` は正当なので対象外。
  if LC_ALL=C grep -rnE 'ADR-[0-9]{4}|\]\((\.\./)*docs/adr' "$dir"; then
    echo "ERROR: ${skill}: リポジトリ内部への参照（ADR 番号等）は展開先で解決できません"
    errors=$((errors + 1))
  fi
done

if [ "$errors" -gt 0 ]; then
  echo "NG: ${errors} 件のエラー"
  exit 1
fi
echo "OK: すべてのスキルが共有規約を満たしています"
