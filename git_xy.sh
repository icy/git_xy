#!/usr/bin/env bash

# Purpose : Watch changes, update paths and create PRs automatically
# Author  : Ky-Anh Huynh
# Date    : 2020-June-04

requirements_check() {
  _tools="
    awk
    rsync
    bash
    git
    grep
    sed
    gh
  "

  for tool in $_tools; do
    command -v "$tool" >/dev/null \
    || {
      log "ERROR: Failed to find system tool '$tool'"
      return 1
    }
    log "Found: $tool ($($tool --version 2>&1 | head -1))"
  done
}

git_xy_env() {
  GIT_XY_CONFIG="${GIT_XY_CONFIG:-git_xy.config}"
  D_GIT_SYNC="$HOME/.local/share/git_xy/"

  export D_GIT_SYNC
  export GIT_XY_CONFIG
  mkdir -pv "$D_GIT_SYNC"

  if [[ ! -f "$GIT_XY_CONFIG" ]]; then
    log "ERROR: Configuration file not found: $GIT_XY_CONFIG"
    return 1
  fi

  if [[ ! -d "$D_GIT_SYNC" ]]; then
    log "ERROR: Local share directory not found: $GIT_XY_CONFIG"
    return 1
  fi
}

config() {
  < "$GIT_XY_CONFIG" grep -v '#' \
  | awk 'NF >= 6'
}

git_dirty() {
  git describe --match="THIS IS NOT A TAG" --always --dirty="-dirty" \
  | grep -qs -- "-dirty"
}

# Example:
#   ssh://git@github.com:foo/bar.git --> ssh__git_github_com_foo_bar.git
repo_uri_to_local_name() {
  repo="${1}"
  repo="${repo//@/_}"
  repo="${repo//:/_}"
  repo="${repo//\//_}"
  echo "$repo"
}

# $1: repo
# $2: prefix
repo_local_full_path() {
  echo "${D_GIT_SYNC}/${2:-}$(repo_uri_to_local_name "${1}")/"
}

git_pull() {
  repo="${1}"
  local_full_path="${2}"
  branch="${3:-}"

  log "Pulling $repo ==> $local_full_path"
  (
    if [[ ! -d "$local_full_path" ]]; then
      git clone "$repo" "${local_full_path}" || return
    fi

    cd "$local_full_path"/ \
    && git reset --hard \
    && git checkout master \
    && git fetch --all --prune --prune-tags \
    || exit

    if [[ -n "$branch" ]]; then
      log "Checking out branch '$branch'..."
      git checkout "$branch"
      git reset --hard "origin/$branch"
    fi
  )
}

__hook_post_commit() {
  log "Executing" gh pr create

  if [[ -n "$pr_base" ]]; then
    _pr_base="--repo $pr_base"
  else
    _pr_base=""
  fi

  set -x
  gh pr create \
    --fill \
    --base "$dst_branch" \
    $_pr_base
  set +x
}

__dst_commit_changes_if_any() {
  (
    cd "$dst_local_full_path" || exit
    git add "$dst_local_full_path/$dst_path" || exit

    git_dirty \
    || {
      log "INFO: Nothing to commit. Src and Dst are up-to-date."
      exit 0
    }

    git commit -a -m"git_xy/$src_repo branch $src_branch path $src_path

\`\`\`
git_xy:
  version: 0.0.0
src:
  repo    : $src_repo
  branch  : $src_branch
  path    : $src_path
  commit  : $src_commit_hash
  subject : $src_commit_subject
dst:
  repo    : $dst_repo
  branch  : $dst_branch
  path    : $dst_path
  commit  : $dst_commit_hash
\`\`\`
"
      git branch
      git log -1
      __hook_post_commit
  )
}

log() {
  _method="${FUNCNAME[1]:-}"
  [[ "${_method}" != "__last_error" ]] || _method="${FUNCNAME[2]:-}"
  echo >&2 ":: $_method: $*"
}

__last_error() {
  [[ -z "$last_error" ]] \
  || {
    log "$last_error"
    log "ERROR: git_xy failed to process the request: $transfer_request"
  }
  last_error=""
}

git_xy() {
  n_config=0
  n_config_ok=0
  last_error=""

  while read -r src_repo src_branch src_path dst_repo dst_branch dst_path pr_base _; do
    (( n_config++ ))

    __last_error

    transfer_request="$src_repo $src_branch $src_path ==> $dst_repo $dst_branch $dst_path [pr_base: $pr_base]"

    if [[ -z "$dst_branch" ]]; then
      last_error="ERROR: Configuration is not valid: $transfer_request"
      continue
    fi

    log "=============================================================="
    log "Watching $transfer_request"
    log "=============================================================="

    src_path="${src_path}/"
    dst_path="${dst_path}/"
    src_path="$(sed -r -e "s#/+#/#g" <<<"$src_path")"
    dst_path="$(sed -r -e "s#/+#/#g" <<<"$dst_path")"

    src_local_full_path="$(repo_local_full_path "$src_repo" "src_")"
    dst_local_full_path="$(repo_local_full_path "$dst_repo" "dst_")"

    git_pull "$src_repo" "$src_local_full_path" "$src_branch" \
    || {
      last_error="ERROR: Failed to pull source repository $src_repo"
      continue
    }

    if [[ ! -d "$src_local_full_path/$src_path" ]]; then
      last_error="ERROR: Expected path not found: $src_local_full_path/$src_path"
      continue
    fi

    git_pull "$dst_repo" "$dst_local_full_path" "$dst_branch" || continue

    src_commit_hash="$(cd "$src_local_full_path" && git rev-parse HEAD)"
    src_commit_subject="$(cd "$src_local_full_path" && git log -1 --pretty="format:%s")"
    dst_commit_hash="$(cd "$dst_local_full_path" && git rev-parse HEAD)"

    if [[ -z "$src_commit_hash" || -z "$dst_commit_hash" ]]; then
      last_error="ERROR: Either src commit hash ($src_commit_hash) or dst commit hash ($dst_commit_hash) is empty."
      continue
    fi

    if [[ "$src_commit_hash" == "$dst_commit_hash" ]]; then
      last_error="ERROR: Src commit hash and dst commit hash are the same. Is that a loophole?"
      continue
    fi

    dst_branch_sync="git_xy__${src_branch}/${src_path}__${dst_branch}/${dst_path}"
    # dst_branch_sync="${dst_branch_sync//\//_root_}"
    dst_branch_sync="$(sed -r -e "s#/+#/#g" -e "s#/+\$##g" <<< "$dst_branch_sync")"

    (
      mkdir -pv "$dst_local_full_path/$dst_path"
      cd "$dst_local_full_path/$dst_path" || exit

      git branch -D "$dst_branch_sync" || true

      git checkout -b "$dst_branch_sync"
    ) \
    || {
      last_error="ERROR: Failed to created git_xy branch: $dst_branch_sync"
      continue
    }

    rsync -rap -delete \
      --exclude=".git/*" \
      "$src_local_full_path/$src_path" \
      "$dst_local_full_path/$dst_path" \
    || {
      last_error="ERROR: Failed to executed rsync command."
      continue
    }

    __dst_commit_changes_if_any \
    || {
      last_error="ERROR: Failed to commit changes after rsync."
      continue
    }

    log "INFO: git_xy successfully process the request: $transfer_request"

    (( n_config_ok++ ))
  done < <(config)

  __last_error

  log "INFO: git_xy received $n_config request(s) and successfully proccessed $n_config_ok request(s)."

  [[ "$n_config_ok" == "$n_config" ]]
}

main() {
  requirements_check \
  && git_xy_env \
  && git_xy
}

set -u
"${@:-main}"
