#!/usr/bin/env bash

# Purpose : Watch changes, update paths and create PRs automatically
# Author  : Ky-Anh Huynh
# Date    : 2020-June-04

requirements_check() {
  log "(FIXME) Checking awk..."
  log "(FIXME) Checking rsync..."
  log "(FIXME) Checking bash4..."
  log "(FIXME) Checking git..."
  log "(FIXME) Checking grep..."
  log "(FIXME) Checking diff..."
}

github_cli_install() {
  echo "https://github.com/cli/cli/releases/download/v0.9.0/gh_0.9.0_linux_amd64.tar.gz"
}

git_sync_env() {
  F_GIT_SYNC_CONFIG="${F_GIT_SYNC_CONFIG:-git_sync.config}"
  D_GIT_SYNC="$HOME/.local/share/git_sync/"

  export D_GIT_SYNC
  export F_GIT_SYNC_CONFIG
  mkdir -pv "$D_GIT_SYNC"

  if [[ ! -f "$F_GIT_SYNC_CONFIG" ]]; then
    log "ERROR: Configuration file not found: $F_GIT_SYNC_CONFIG"
    return 1
  fi

  if [[ -d "$D_GIT_SYNC" ]]; then
    log "ERROR: Local share directory not found: $F_GIT_SYNC_CONFIG"
    return 1
  fi
}

config() {
  < "$F_GIT_SYNC_CONFIG" grep -v '#' \
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

repo_local_full_path() {
  echo "$D_GIT_SYNC/$(repo_uri_to_local_name "${1}")/"
}

git_pull() {
  repo="${1}"
  branch="${2:-}"

  local_full_path="$(repo_local_full_path "$repo")"

  log "Pulling $repo ==> $local_full_path"
  (
    if [[ ! -d "$local_full_path" ]]; then
      git clone "$repo" "$local_full_path" || return
    fi

    cd "$local_full_path"/ \
    && git reset --hard \
    && git checkout master \
    && git fetch --all --prune --prune-tags \
    && git reset --hard origin/master \
    || exit

    if [[ -n "$branch" ]]; then
      log "Switching over branch '$branch'..."
      git checkout "$branch"
      git reset --hard "origin/$branch"
    fi
  )
}

__hook_post_commit() {
  gh pr create
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

    git commit -a -m"git_sync from $src_repo $src_branch//$src_path

git_sync:
  version: 0.0.0
src:
  repo    : $src_repo
  branch  : $src_branch
  commit  : $src_commit_hash
  path    : $src_path
dst:
  repo    : $dst_repo
  branch  : $dst_branch
  commit  : $dst_commit_hash
  path    : $dst_path
"
      git branch
      git log -1
      __hook_post_commit
  )
}

log() {
  echo >&2 ":: ${FUNCNAME[1]:-}: $*"
}

git_sync() {
  n_config=0
  n_config_ok=0

  while read -r src_repo src_branch src_path dst_repo dst_branch dst_path _; do
    (( n_config++ ))

    transfer_request="$src_repo $src_branch $src_path ==> $dst_repo $dst_branch $dst_path"

    if [[ -z "$dst_branch" ]]; then
      log "ERROR: Configuration is not valid: $transfer_request"
      continue
    fi

    echo >&2 ":: Watching $transfer_request"

    src_path="${src_path}/"
    dst_path="${dst_path}/"

    src_local_full_path="$(repo_local_full_path "$src_repo")"
    dst_local_full_path="$(repo_local_full_path "$dst_repo")"

    if [[ "$src_local_full_path" == "$dst_local_full_path" ]]; then
      log "Skipping $transfer_request"
      log "ERROR: src_repo and dst_repo are expanded to the same local path"
      log "src $src_repo ==> $src_local_full_path"
      log "dst $dst_repo ==> $dst_local_full_path"
      continue
    fi

    git_pull "$src_repo" "$src_branch" || continue

    if [[ ! -d "$src_local_full_path/$src_path" ]]; then
      log "ERROR: Expected path not found: $src_local_full_path/$src_path"
      continue
    fi

    git_pull "$dst_repo" "$dst_branch" || continue

    src_commit_hash="$(cd "$src_local_full_path" && git rev-parse HEAD)"
    dst_commit_hash="$(cd "$dst_local_full_path" && git rev-parse HEAD)"

    if [[ -z "$src_commit_hash" || -z "$dst_commit_hash" ]]; then
      log "ERROR: Either src commit hash ($src_commit_hash) or dst commit hash ($dst_commit_hash) is empty."
      continue
    fi

    if [[ "$src_commit_hash" == "$dst_commit_hash" ]]; then
      log "ERROR: Src commit hash and dst commit hash are the same. Is that a loophole?"
      continue
    fi

    (
      mkdir -pv "$dst_local_full_path/$dst_path"
      cd "$dst_local_full_path/$dst_path" || exit

      dst_branch_sync="git_sync/${src_commit_hash}/${dst_commit_hash}"
      git branch -D "$dst_branch_sync" || true

      git checkout -b "$dst_branch_sync"
    ) \
    || continue

    rsync -rap -delete \
      "$src_local_full_path/$src_path" \
      "$dst_local_full_path/$dst_path" \
    || continue

    __dst_commit_changes_if_any \
    || continue

    log "INFO: Successfully updated, request: $transfer_request"
    (( n_config_ok++ ))
  done < <(config)
}

main() {
  requirements_check \
  && git_sync_env \
  && git_sync
}

"${@:-main}"
