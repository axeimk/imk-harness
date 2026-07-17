#!/usr/bin/env bash
# install.sh / uninstall.sh 共通のヘルパー。単体では実行しない。
# 呼び出し側で REPO / TS を定義し、apply_changes() を実装してから source すること。
#
# 実行モデル（2段階実行）:
#   DRYRUN=1 で apply_changes を呼ぶと、ファイルには一切触れず PLAN に予定を積む。
#   プランを表示してユーザーが承認したら、DRYRUN=0 で同じ apply_changes を本実行する。
#
# 変更系ヘルパーの書き方:
#   実 FS 操作は必ず [ "$DRYRUN" -eq 0 ] で囲み、表示は report 経由にする
#   （report が DRYRUN 中はプランに積み、本実行中はその場で表示する）。

DRYRUN=0
PLAN=()
NOTICES=()

notice() { NOTICES+=("$1"); }

# 同一内容の notice を重複して積まない（複数の skills ルートが同じ更新を検知したとき用）
notice_once() {
  local m="$1" n
  for n in ${NOTICES[@]+"${NOTICES[@]}"}; do
    if [ "$n" = "$m" ]; then return 0; fi
  done
  notice "$m"
}

# 管理ブロックのマーカー（ASCII のみ — bash 3.2 / macOS sed の多バイト問題を回避）
BLOCK_BEGIN='<!-- >>> imk-harness:begin >>> -->'
BLOCK_END='<!-- <<< imk-harness:end <<< -->'

# ---------------------------------------------------------------
# 出力
# ---------------------------------------------------------------
# 色は端末に直接出すときだけ有効化する（パイプ・CI・NO_COLOR ではプレーン）。
# テストは非 TTY で走るため、色の有無がアサーションに影響しない。

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
  C_RED=$'\033[31m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_CYAN=$'\033[36m'
else
  C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_CYAN=''
fi

TAB=$'\t'

ui_header() { printf '%s==>%s %s%s%s\n' "${C_CYAN}${C_BOLD}" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"; }
ui_ok()     { printf '%s✓ %s%s\n' "${C_GREEN}${C_BOLD}" "$1" "$C_RESET"; }
ui_warn()   { printf '%s⚠ %s%s\n' "$C_YELLOW" "$1" "$C_RESET"; }
ui_dim()    { printf '%s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }

# 動詞（link / remove 等）を色付き・幅揃えで 1 行表示する
ui_action() {
  local verb="$1" detail="$2" color
  case "$verb" in
    remove|prune|delete)           color="$C_RED" ;;
    backup|skip)                   color="$C_YELLOW" ;;
    update|migrate|restore|relink) color="$C_CYAN" ;;
    *)                             color="$C_GREEN" ;;  # link / copy / create / append
  esac
  printf '  %s%-8s%s %s\n' "$color" "$verb" "$C_RESET" "$detail"
}

# 変更の報告: DRYRUN 中はプランに積み、本実行中はその場で表示する
report() {
  if [ "$DRYRUN" -eq 1 ]; then
    PLAN+=("$1${TAB}$2")
  else
    ui_action "$1" "$2"
  fi
}

# ---------------------------------------------------------------
# 基本操作
# ---------------------------------------------------------------

# symlink を張る。既存の実ファイルは .bak.<timestamp> に退避する。
# 既に正しいリンクなら何もしない（プランにも出さない）
link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return 0
  fi
  if [ -L "$dst" ]; then
    if [ "$DRYRUN" -eq 0 ]; then
      rm "$dst"
      ln -s "$src" "$dst"
    fi
    report relink "$dst -> $src"
    return 0
  fi
  if [ -e "$dst" ]; then
    if [ "$DRYRUN" -eq 0 ]; then
      mv "$dst" "$dst.bak.$TS"
      notice "既存ファイルを退避しました: $dst.bak.${TS}（内容を確認し、不要なら削除してください）"
    fi
    report backup "$dst -> $dst.bak.$TS"
  fi
  if [ "$DRYRUN" -eq 0 ]; then
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
  fi
  report link "$dst -> $src"
}

# 既存ファイルがある場合はコピーせず、手動マージを促す
copy_if_absent() {
  local src="$1" dst="$2"
  if [ -e "$dst" ]; then
    if [ "$DRYRUN" -eq 0 ]; then
      report skip "${dst}（既存のため変更なし）"
      notice "$dst は既存のため変更していません。取り込みたい設定があれば差分を確認してマージしてください: diff \"$dst\" \"$src\""
    fi
    return 0
  fi
  if [ "$DRYRUN" -eq 0 ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  fi
  report copy "$dst"
}

# shared/skills/ 配下の全スキルを指定ディレクトリへ symlink する
link_skills() {
  local root="$1" d
  for d in "$REPO"/shared/skills/*/; do
    d="${d%/}"
    link "$d" "$root/$(basename "$d")"
  done
}

# shared/skills/ 全体の内容記録（スキルごとに 1 行 "名前 ハッシュ"）。
# パスはスキルディレクトリからの相対で刻み、リポジトリを移動しても値が変わらないようにする。
# 隠しファイル（.DS_Store 等）は対象外
skills_digest() {
  local d
  for d in "$REPO"/shared/skills/*/; do
    d="${d%/}"
    printf '%s %s\n' "$(basename "$d")" \
      "$(cd "$d" && find . -type f ! -name '.*' | LC_ALL=C sort | xargs shasum | shasum | cut -d' ' -f1)"
  done
}

# スキル内容の更新検知と記録:
#   前回展開時の記録（$root/.imk-harness-manifest）と現在の内容を比べ、内容が変わった
#   スキルを notice で知らせる（symlink 配布のため反映自体は済んでいる。これを知らせないと
#   スキルだけ更新したとき「変更はありません」で終わり、更新が届いたか分からない）。
#   link_skills の後に呼ぶこと（本実行時、書き込み先ディレクトリの存在を前提にする）
record_skills_manifest() {
  local root="$1" mf="$1/.imk-harness-manifest" current updated
  current="$(skills_digest)"
  if [ -f "$mf" ]; then
    if [ "$(cat "$mf")" = "$current" ]; then
      return 0
    fi
    updated="$(printf '%s\n' "$current" \
      | LC_ALL=C awk 'NR==FNR { old[$1] = $2; next } ($1 in old) && old[$1] != $2 { print $1 }' "$mf" - \
      | xargs)"
    if [ -n "$updated" ]; then
      notice_once "前回の展開以降に内容が更新されたスキル: ${updated}（symlink 配布のため、変更は既に反映されています）"
    fi
  fi
  if [ "$DRYRUN" -eq 0 ]; then
    printf '%s\n' "$current" > "$mf"
  fi
  report record "${mf}（スキル内容の記録を更新）"
}

# このハーネスが張った symlink かどうかの判定:
#   - リンク先が現在のリポジトリ配下 → 管理対象
#   - リンク切れで、リンク先パスに imk-harness を含む → 管理対象（リポジトリ移動後の残骸）
managed_target() {
  local dst="$1" target
  [ -L "$dst" ] || return 1
  target="$(readlink "$dst")"
  case "$target" in
    "$REPO"/*) return 0 ;;
    */imk-harness/*) if [ ! -e "$dst" ]; then return 0; fi ;;
  esac
  return 1
}

# 最新の .bak.<timestamp> があれば元の場所へ復元する
restore_backup() {
  local dst="$1" newest
  newest="$(ls -1d "$dst".bak.* 2>/dev/null | sort | tail -n 1 || true)"
  [ -n "$newest" ] || return 0
  if [ "$DRYRUN" -eq 0 ]; then
    mv "$newest" "$dst"
  fi
  report restore "$dst <- $(basename "$newest")"
}

# 管理対象の symlink を取り除き、バックアップがあれば復元する
remove_managed_link() {
  local dst="$1"
  managed_target "$dst" || return 0
  if [ "$DRYRUN" -eq 0 ]; then
    rm "$dst"
  fi
  report remove "${dst}（symlink を除去）"
  restore_backup "$dst"
}

# スキルディレクトリからハーネス由来のリンクを掃除する
#   mode=all   : ハーネス由来のリンクをすべて除去（ツールの選択解除・アンインストール時）
#   mode=stale : リンク切れ（リポジトリから削除されたスキル）だけ除去
# ユーザーが自分で置いたスキルには触れない
prune_skills_root() {
  local root="$1" mode="$2" l
  [ -d "$root" ] || return 0
  for l in "$root"/*; do
    { [ -e "$l" ] || [ -L "$l" ]; } || continue
    managed_target "$l" || continue
    if [ "$mode" = "all" ] || [ ! -e "$l" ]; then
      if [ "$DRYRUN" -eq 0 ]; then
        rm "$l"
      fi
      report prune "$l"
    fi
  done
  if [ "$mode" = "all" ] && [ -f "$root/.imk-harness-manifest" ]; then
    if [ "$DRYRUN" -eq 0 ]; then
      rm "$root/.imk-harness-manifest"
    fi
    report prune "$root/.imk-harness-manifest（スキル内容の記録）"
  fi
  if [ "$DRYRUN" -eq 0 ]; then
    rmdir "$root" 2>/dev/null || true  # 空になったら畳む
  fi
}

# ---------------------------------------------------------------
# 管理ブロック（CLAUDE.md / AGENTS.md）
# ---------------------------------------------------------------
# dst は実ファイルとして扱い、マーカーで囲まれたブロックだけを書き込み・更新する。
# ブロックの外はユーザーの自由編集エリアで、更新・アンインストールでも保持される。

has_block() { [ -f "$1" ] && LC_ALL=C grep -qF "$BLOCK_BEGIN" "$1"; }

# dst の管理ブロックの中身を取り出す
extract_block() {
  LC_ALL=C awk -v begin="$BLOCK_BEGIN" -v end="$BLOCK_END" '
    $0 == end   { inb = 0 }
    inb         { print }
    $0 == begin { inb = 1 }
  ' "$1"
}

# ブロックの中身が src と一致しているか
block_is_current() { [ "$(extract_block "$2")" = "$(cat "$1")" ]; }

# dst からブロックを除いた残りが空白のみか
remainder_is_empty() {
  local rest
  rest="$(LC_ALL=C awk -v begin="$BLOCK_BEGIN" -v end="$BLOCK_END" '
    $0 == begin { skip = 1; next }
    $0 == end   { skip = 0; next }
    skip        { next }
    { print }
  ' "$1" | LC_ALL=C tr -d '[:space:]')"
  [ -z "$rest" ]
}

# dst 末尾にブロックを追記する（dst がなければ作成）
append_block() {
  local src="$1" dst="$2"
  {
    if [ -s "$dst" ]; then echo; fi
    echo "$BLOCK_BEGIN"
    cat "$src"
    echo "$BLOCK_END"
  } >> "$dst"
}

# dst のブロックの中身を src で置き換える
replace_block() {
  local src="$1" dst="$2" tmp
  tmp="$(mktemp)"
  LC_ALL=C awk -v begin="$BLOCK_BEGIN" -v end="$BLOCK_END" -v srcfile="$src" '
    $0 == begin {
      print
      while ((getline l < srcfile) > 0) print l
      close(srcfile)
      skip = 1
      next
    }
    $0 == end { skip = 0; print; next }
    skip      { next }
    { print }
  ' "$dst" > "$tmp"
  cat "$tmp" > "$dst"
  rm "$tmp"
}

# src の内容を dst の管理ブロックとして書き込み・更新する
write_managed_block() {
  local src="$1" dst="$2"

  # 旧方式（symlink）からの移行: リンクを外し、バックアップがあれば土台として復元
  if managed_target "$dst"; then
    if [ "$DRYRUN" -eq 1 ]; then
      report migrate "${dst}（symlink を実ファイル化。バックアップがあれば内容を引き継ぐ）"
      report update "${dst}（管理ブロックを書き込み）"
      return 0
    fi
    rm "$dst"
    report remove "${dst}（旧方式の symlink）"
    restore_backup "$dst"
  fi

  if has_block "$dst"; then
    if block_is_current "$src" "$dst"; then
      return 0  # 変更なし
    fi
    if [ "$DRYRUN" -eq 0 ]; then
      replace_block "$src" "$dst"
    fi
    report update "${dst}（管理ブロックを更新。ブロック外は保持）"
  elif [ -e "$dst" ]; then
    if [ "$DRYRUN" -eq 0 ]; then
      append_block "$src" "$dst"
    fi
    report append "${dst}（末尾に管理ブロックを追記。既存の内容は保持）"
  else
    if [ "$DRYRUN" -eq 0 ]; then
      mkdir -p "$(dirname "$dst")"
      append_block "$src" "$dst"
    fi
    report create "${dst}（管理ブロックを書き込み）"
  fi
}

# dst から管理ブロックを除去する。残りが空白のみならファイルごと削除し、
# バックアップがあれば復元する
remove_block() {
  local dst="$1" tmp
  has_block "$dst" || return 0
  if remainder_is_empty "$dst"; then
    if [ "$DRYRUN" -eq 0 ]; then
      rm "$dst"
    fi
    report delete "${dst}（管理ブロックのみのファイルのため削除）"
    restore_backup "$dst"
    return 0
  fi
  if [ "$DRYRUN" -eq 0 ]; then
    tmp="$(mktemp)"
    LC_ALL=C awk -v begin="$BLOCK_BEGIN" -v end="$BLOCK_END" '
      $0 == begin { skip = 1; next }
      $0 == end   { skip = 0; next }
      skip        { next }
      { print }
    ' "$dst" > "$tmp"
    cat "$tmp" > "$dst"
    rm "$tmp"
  fi
  report update "${dst}（管理ブロックを除去。それ以外の内容は保持）"
}

# ---------------------------------------------------------------
# 実行フロー
# ---------------------------------------------------------------

# 蓄積した notice を最後にまとめて表示する
print_summary() {
  local title="$1" i n
  echo
  ui_ok "$title"
  if [ "${#NOTICES[@]}" -gt 0 ]; then
    echo
    ui_warn "手動での対応・確認が必要な項目:"
    i=1
    for n in "${NOTICES[@]}"; do
      printf '  %d. %s\n' "$i" "$n"
      i=$((i + 1))
    done
  fi
}

# 2段階実行: dry-run でプランを表示 → 確認 → 本実行
#   $1: 完了時のタイトル  $2: ASSUME_YES(0/1)  $3: DRY_ONLY(0/1)
run_with_confirmation() {
  local title="$1" assume_yes="$2" dry_only="$3" p a

  DRYRUN=1
  PLAN=(); NOTICES=()
  apply_changes

  if [ "${#PLAN[@]}" -eq 0 ]; then
    echo "変更はありません。"
    return 0
  fi

  echo
  ui_header "適用される変更"
  for p in "${PLAN[@]}"; do
    ui_action "${p%%"$TAB"*}" "${p#*"$TAB"}"
  done
  echo

  if [ "$dry_only" -eq 1 ]; then
    ui_dim "(--dry-run のため適用しません)"
    return 0
  fi

  if [ "$assume_yes" -ne 1 ]; then
    read -r -p "続行しますか? [y/N]: " a
    if [ "$a" != "y" ] && [ "$a" != "Y" ]; then
      echo "中止しました。ファイルには触れていません。"
      exit 0
    fi
  fi

  echo
  DRYRUN=0
  PLAN=(); NOTICES=()
  apply_changes
  print_summary "$title"
}
