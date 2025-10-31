#!/usr/bin/env bash
set -euo pipefail

echo "🔄 pre-commit: サブモジュール整備＋gitlink反映を開始します..."

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

SUBMODULES=( ".claude" "docs" )

is_git_repo() {
  git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

detect_default_branch() {
  local path="$1" br
  br="$(git -C "$path" remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p' || true)"
  if [[ -z "${br:-}" ]]; then
    if   git -C "$path" show-ref --verify --quiet refs/heads/main;   then br=main
    elif git -C "$path" show-ref --verify --quiet refs/heads/master; then br=master
    else br=main; fi
  fi
  printf "%s" "$br"
}

ensure_on_branch() {
  # サブモジュールでは detached HEAD になりがちなので、追跡ブランチを用意してチェックアウト
  local path="$1" br="$2"
  if ! git -C "$path" symbolic-ref -q HEAD >/dev/null; then
    # detached: ローカルブランチが無ければ作って origin/<br> を追跡
    if ! git -C "$path" show-ref --verify --quiet "refs/heads/$br"; then
      git -C "$path" checkout -B "$br" "origin/$br" --quiet
    else
      git -C "$path" checkout "$br" --quiet
      git -C "$path" branch --set-upstream-to="origin/$br" "$br" >/dev/null 2>&1 || true
    fi
  fi
}

net_retry() { # 軽いリトライ（ネット一瞬落ちた等のとき）
  local tries=0 max=3
  until "$@"; do
    tries=$((tries+1))
    if (( tries >= max )); then return 1; fi
    sleep $((tries*1))
  done
}

update_inside_submodule() {
  local path="$1"
  if ! is_git_repo "$path"; then
    echo "ℹ️ スキップ（Git管理外 or 未初期化）: $path"
    return 0
  fi

  echo "➡️  サブモジュールに入ります: $path"
  pushd "$path" >/dev/null

  # 親のインデックス汚染を避ける（後で復元）
  local SAVE_GIT_INDEX_FILE="${GIT_INDEX_FILE-}"
  local SAVE_GIT_DIR="${GIT_DIR-}"
  unset GIT_INDEX_FILE GIT_DIR

  local br; br="$(detect_default_branch ".")"
  ensure_on_branch "." "$br"

  # 未コミット/未追跡があれば自動コミット（hooks 無効で安全）
  if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
    echo "📝 $path に未コミット/未追跡の変更 → 自動コミットします"
    git add -A
    git -c core.hooksPath=/dev/null commit -m "自動コミット: サブモジュール更新 ($(date '+%Y-%m-%d %H:%M:%S'))" || true
  fi

  # まずは最新を取得
  net_retry git fetch -q origin "$br" || true

  # 追いつき判定
  local ahead=0 behind=0
  if git rev-parse --verify -q "origin/$br" >/dev/null; then
    ahead=$(git rev-list --left-only  --count "HEAD...origin/$br" || echo 0)
    behind=$(git rev-list --right-only --count "HEAD...origin/$br" || echo 0)
  fi

  if (( behind > 0 && ahead == 0 )); then
    # 自分が遅れているだけ → FF
    echo "⬇️  $path: origin/$br へ fast-forward で追従します"
    git merge --ff-only "origin/$br"
  elif (( behind > 0 && ahead > 0 )); then
    # 互いに進んでる → rebase を試す
    echo "🔁 $path: origin/$br に rebase で追従します（衝突時は安全停止）"
    if ! git -c rebase.autoStash=true rebase "origin/$br"; then
      echo ""
      echo "🚨 $path で rebase コンフリクトが発生しました。pre-commit を中断します。"
      echo "   手順:"
      echo "     cd $path"
      echo "     # 衝突箇所を解決してから"
      echo "     git add <解決ファイル> ..."
      echo "     git rebase --continue    # もしくは git rebase --abort で取り消し"
      echo "     git push origin $br"
      echo "   その後、親で再度コミットしてください。"
      echo ""
      # 環境復元
      if [[ -n "${SAVE_GIT_INDEX_FILE}" ]]; then export GIT_INDEX_FILE="${SAVE_GIT_INDEX_FILE}"; else unset GIT_INDEX_FILE; fi
      if [[ -n "${SAVE_GIT_DIR}" ]]; then export GIT_DIR="${SAVE_GIT_DIR}"; else unset GIT_DIR; fi
      popd >/dev/null
      exit 1
    fi
  fi

  # ここまで来たら origin/$br に対して FF 可能 or rebase 済み
  # 先に自分が進んでいる分があれば push
  if git rev-parse --verify -q "origin/$br" >/dev/null; then
    ahead=$(git rev-list --left-only --count "HEAD...origin/$br" || echo 0)
  else
    ahead=1  # 初 push ケース
  fi

  if (( ahead > 0 )); then
    echo "⬆️  $path の変更を origin/$br へプッシュします"
    # 競合で拒否されたら（直前に誰かが push）、一度だけやり直す
    if ! git -c core.hooksPath=/dev/null push origin "$br"; then
      echo "⚠️  push が拒否されました。最新を取り込み直して再試行します..."
      net_retry git fetch -q origin "$br" || true
      if git merge --ff-only "origin/$br" 2>/dev/null; then
        git -c core.hooksPath=/dev/null push origin "$br"
      else
        # FF できなければ rebase 再試行
        if git -c rebase.autoStash=true rebase "origin/$br"; then
          git -c core.hooksPath=/dev/null push origin "$br"
        else
          echo ""
          echo "🚨 $path で push 再試行も失敗（rebase 衝突）。手動解決してください。"
          echo "   手順は上記と同様です。"
          echo ""
          if [[ -n "${SAVE_GIT_INDEX_FILE}" ]]; then export GIT_INDEX_FILE="${SAVE_GIT_INDEX_FILE}"; else unset GIT_INDEX_FILE; fi
          if [[ -n "${SAVE_GIT_DIR}" ]]; then export GIT_DIR="${SAVE_GIT_DIR}"; else unset GIT_DIR; fi
          popd >/dev/null
          exit 1
        fi
      fi
    fi
  else
    echo "🆗 $path はリモートと同期済みです"
  fi

  # 環境復元
  if [[ -n "${SAVE_GIT_INDEX_FILE}" ]]; then export GIT_INDEX_FILE="${SAVE_GIT_INDEX_FILE}"; else unset GIT_INDEX_FILE; fi
  if [[ -n "${SAVE_GIT_DIR}" ]]; then export GIT_DIR="${SAVE_GIT_DIR}"; else unset GIT_DIR; fi

  popd >/dev/null
}

stage_gitlink_in_parent() {
  local path="$1"
  if ! is_git_repo "$path"; then
    echo "ℹ️ スキップ（Git管理外 or 未初期化）: $path"
    return 0
  fi
  local sha
  sha="$(git -C "$path" rev-parse HEAD)"
  if [[ -z "$sha" ]]; then
    echo "❌ サブモジュールの SHA を取得できませんでした: $path"
    exit 1
  fi
  git update-index --add --cacheinfo 160000,"$sha","$path"
  echo "✅ 親インデックスに gitlink を反映: $path → $sha"

  if git diff --cached --quiet -- "$path"; then
    echo "📝 gitlink のステージ済み変更はありません: $path"
  else
    echo "📦 gitlink 変更がステージに載りました: $path"
  fi
}

# 1) サブモジュール内を整備（commit / fetch / FF or rebase / push）
for sm in "${SUBMODULES[@]}"; do
  update_inside_submodule "$sm"
done

# 2) 親のインデックスに gitlink を直接反映
for sm in "${SUBMODULES[@]}"; do
  stage_gitlink_in_parent "$sm"
done

echo "✅ pre-commit: サブモジュール整備＋gitlink反映が完了しました"

# 親が空ステージで開始していた場合のフォロー（あなたのラッパー仕様に合わせて）
if [[ "${GIT_STAGE_WAS_EMPTY:-0}" == "1" ]]; then
  if ! git diff --cached --quiet -- .claude docs; then
    echo "🛑 親は空の状態でしたが、サブモジュール更新をステージしました。"
    echo "   次の 'git commit' で確実にコミットされます。もう一度commitしてみてください。"
    exit 1
  fi
fi
