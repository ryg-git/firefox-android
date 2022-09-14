#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

REPO_NAME_TO_SYNC='android-components'
REPO_PATH="/tmp/git/$REPO_NAME_TO_SYNC"
REPO_BRANCH_NAME='firefox-android'
TAG_PREFIX='components-'
MONOREPO_URL='git@github.com:mozilla-mobile/firefox-android.git'

EXPRESSIONS_FILE_PATH="$SCRIPT_DIR/data/message-expressions.txt"


function _is_github_authenticated() {
    set +e
    ssh -T git@github.com
    exit_code=$?
    set -e
    if [[ $exit_code == 1 ]]; then
        # user is authenticated, but fails to open a shell with GitHub
        return 0
    fi
    exit "$exit_code"
}

function _test_prerequisites() {
    _is_github_authenticated
    git filter-repo --version > /dev/null || (echo 'ERROR: Please install git-filter-repo: https://github.com/newren/git-filter-repo/blob/main/INSTALL.md'; exit 1)
}

function _setup_temporary_repo() {
    rm -rf "$REPO_PATH"
    mkdir -p "$REPO_PATH"

    git clone "git@github.com:mozilla-mobile/$REPO_NAME_TO_SYNC.git" "$REPO_PATH"
    cd "$REPO_PATH"
    git fetch origin "$REPO_BRANCH_NAME"
}

function _update_repo_branch() {
    git checkout "$REPO_BRANCH_NAME"
    git rebase main
    git push origin "$REPO_BRANCH_NAME" --force
}

function _update_repo_numbers() {
    "$SCRIPT_DIR/generate-repo-numbers.py"
    "$SCRIPT_DIR/generate-replace-message-expressions.py"
}

function _rewrite_git_history() {
    git filter-repo \
        --to-subdirectory-filter 'android-components/' \
        --replace-message "$EXPRESSIONS_FILE_PATH" \
        --tag-rename '':"$TAG_PREFIX" \
        --force
}

function _remove_old_tags() {
    cd "$SCRIPT_DIR"
    set +e
    git tag | grep "$TAG_PREFIX" | xargs -L 1 | xargs git push "$MONOREPO_URL" --delete
    set -e
}

function _merge_histories() {
    cd "$SCRIPT_DIR"
    git pull --tags --allow-unrelated-histories --no-rebase --force "$REPO_PATH"
}

function _clean_up_temporary_repo() {
    rm -rf "$REPO_PATH"
}


_test_prerequisites
_setup_temporary_repo
_update_repo_branch
_update_repo_numbers
_rewrite_git_history
_remove_old_tags
_merge_histories
_clean_up_temporary_repo


cat <<EOF
$REPO_NAME_TO_SYNC has been sync'd and merged to the current branch.
You can now inspect the changes and push them once ready:

git push
git push --tags
EOF