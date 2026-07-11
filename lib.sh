#!/usr/bin/env bash
# install.sh / uninstall.sh 共通のヘルパー。単体では実行しない。
# 呼び出し側で REPO / TS を定義し、apply_changes() を実装してから source すること。
#
# 実行モデル（2段階実行）:
#   DRYRUN=1 で apply_changes を呼ぶと、ファイルには一切触れず PLAN に予定を積む。
#   プランを表示してユーザーが承認したら、DRYRUN=0 で同じ apply_changes を本実行する。

DRYRUN=0
PLAN=()
NOTICES=()

plan()   { PLAN+=("$1"); }
notice() { NOTICES+=("$1"); }

# 管理ブロックのマーカー（ASCII のみ — bash 3.2 / macOS sed の多バイト問題を回避）
BLOCK_BEGIN='<!-- >>> imk-harness:begin >>> -->'
BLOCK_END='<!-- <<< imk-harness:end <<< -->'

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
  if [ "$DRYRUN" -eq 1 ]; then
    if [ -L "$dst" ]; then
      plan "relink: $dst -> $src"
    elif [ -e "$dst" ]; then
      plan "backup: $dst -> $dst.bak.$TS"
      plan "link:   $dst -> $src"
    else
      plan "link:   $dst -> $src"
    fi
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    mv "$dst" "$dst.bak.$TS"
    echo "backup: $dst -> $dst.bak.$TS"
    notice "既存ファイルを退避しました: $dst.bak.${TS}（内容を確認し、不要なら削除してください）"
  fi
  ln -s "$src" "$dst"
  echo "link:   $dst -> $src"
}

# 既存ファイルがある場合はコピーせず、手動マージを促す
copy_if_absent() {
  local src="$1" dst="$2"
  if [ -e "$dst" ]; then
    if [ "$DRYRUN" -eq 0 ]; then
      echo "skip:   ${dst}（既存のため変更なし）"
      notice "$dst は既存のため変更していません。取り込みたい設定があれば差分を確認してマージしてください: diff \"$dst\" \"$src\""
    fi
    return 0
  fi
  if [ "$DRYRUN" -eq 1 ]; then
    plan "copy:   $dst"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "copy:   $dst"
}

# shared/skills/ 配下の全スキルを指定ディレクトリへ symlink する
link_skills() {
  local root="$1" d
  for d in "$REPO"/shared/skills/*/; do
    d="${d%/}"
    link "$d" "$root/$(basename "$d")"
  done
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
  if [ "$DRYRUN" -eq 1 ]; then
    plan "restore: $dst <- $(basename "$newest")"
    return 0
  fi
  mv "$newest" "$dst"
  echo "restore: $dst <- $(basename "$newest")"
}

# 管理対象の symlink を取り除き、バックアップがあれば復元する
remove_managed_link() {
  local dst="$1"
  managed_target "$dst" || return 0
  if [ "$DRYRUN" -eq 1 ]; then
    plan "remove: ${dst}（symlink を除去）"
    restore_backup "$dst"
    return 0
  fi
  rm "$dst"
  echo "remove: $dst"
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
      if [ "$DRYRUN" -eq 1 ]; then
        plan "prune:  $l"
      else
        rm "$l"
        echo "prune:  $l"
      fi
    fi
  done
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
      plan "migrate: ${dst}（symlink を実ファイル化。バックアップがあれば内容を引き継ぐ）"
      plan "update:  ${dst}（管理ブロックを書き込み）"
      return 0
    fi
    rm "$dst"
    echo "remove: ${dst}（旧方式の symlink）"
    restore_backup "$dst"
  fi

  if has_block "$dst"; then
    if block_is_current "$src" "$dst"; then
      return 0  # 変更なし
    fi
    if [ "$DRYRUN" -eq 1 ]; then
      plan "update: ${dst}（管理ブロックを更新。ブロック外は保持）"
      return 0
    fi
    replace_block "$src" "$dst"
    echo "update: ${dst}（管理ブロックを更新）"
  elif [ -e "$dst" ]; then
    if [ "$DRYRUN" -eq 1 ]; then
      plan "append: ${dst}（末尾に管理ブロックを追記。既存の内容は保持）"
      return 0
    fi
    append_block "$src" "$dst"
    echo "append: ${dst}（管理ブロックを追記）"
  else
    if [ "$DRYRUN" -eq 1 ]; then
      plan "create: ${dst}（管理ブロックを書き込み）"
      return 0
    fi
    mkdir -p "$(dirname "$dst")"
    append_block "$src" "$dst"
    echo "create: $dst"
  fi
}

# dst から管理ブロックを除去する。残りが空白のみならファイルごと削除し、
# バックアップがあれば復元する
remove_block() {
  local dst="$1" tmp
  has_block "$dst" || return 0
  if [ "$DRYRUN" -eq 1 ]; then
    if remainder_is_empty "$dst"; then
      plan "delete: ${dst}（管理ブロックのみのファイルのため削除）"
      restore_backup "$dst"
    else
      plan "update: ${dst}（管理ブロックを除去。それ以外の内容は保持）"
    fi
    return 0
  fi
  if remainder_is_empty "$dst"; then
    rm "$dst"
    echo "delete: $dst"
    restore_backup "$dst"
    return 0
  fi
  tmp="$(mktemp)"
  LC_ALL=C awk -v begin="$BLOCK_BEGIN" -v end="$BLOCK_END" '
    $0 == begin { skip = 1; next }
    $0 == end   { skip = 0; next }
    skip        { next }
    { print }
  ' "$dst" > "$tmp"
  cat "$tmp" > "$dst"
  rm "$tmp"
  echo "update: ${dst}（管理ブロックを除去）"
}

# ---------------------------------------------------------------
# 実行フロー
# ---------------------------------------------------------------

# 蓄積した notice を最後にまとめて表示する
print_summary() {
  local title="$1" i n
  echo
  echo "================================================================"
  echo " $title"
  if [ "${#NOTICES[@]}" -gt 0 ]; then
    echo
    echo " ⚠ 手動での対応・確認が必要な項目:"
    i=1
    for n in "${NOTICES[@]}"; do
      printf '   %d. %s\n' "$i" "$n"
      i=$((i + 1))
    done
  else
    echo
    echo " 手動対応が必要な項目はありません。"
  fi
  echo "================================================================"
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
  echo "適用される変更:"
  for p in "${PLAN[@]}"; do
    echo "  - $p"
  done
  echo

  if [ "$dry_only" -eq 1 ]; then
    echo "(--dry-run のため適用しません)"
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
