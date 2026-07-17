#!/usr/bin/env bash
# リポジトリ内の全シェルスクリプトを機械検査する（構文 + bash 3.2 互換の落とし穴）。
# シェルスクリプトの追加・変更時に実行する。エラーがあれば非 0 で終了する。
set -uo pipefail
cd "$(dirname "$0")"

errors=0
while IFS= read -r f; do
  # 構文チェック
  bash -n "$f" || errors=$((errors + 1))

  # bash 3.2 の落とし穴: 変数の直後に全角文字が続くと変数名を誤認する。
  # ${VAR} 形式なら安全。macOS 標準 grep は -P 非対応のため python3 で検査する
  # （バイト単位で処理するので多バイトの "illegal byte sequence" も起きない）。
  hits="$(python3 -c '
import re, sys
pat = re.compile(rb"\$\{?[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]")
for path in sys.argv[1:]:
    with open(path, "rb") as f:
        for i, line in enumerate(f, 1):
            if pat.search(line):
                sys.stdout.buffer.write(b"%s:%d: %s" % (path.encode(), i, line))
' "$f")"
  if [ -n "$hits" ]; then
    echo "$hits"
    echo "ERROR: ${f}: 変数の直後に全角文字があります（\${VAR} 形式にする）"
    errors=$((errors + 1))
  fi
done < <(find . -name '*.sh' -not -path './.git/*' -not -path './node_modules/*' | sort)

if [ "$errors" -gt 0 ]; then
  echo "NG: ${errors} 件のエラー"
  exit 1
fi
echo "OK: すべてのシェルスクリプトが制約を満たしています"
