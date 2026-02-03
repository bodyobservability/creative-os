#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOKS_DIR="${ROOT}/.git/hooks"

if [[ ! -d "${HOOKS_DIR}" ]]; then
  echo "ERROR: .git/hooks not found. Are you in a git repo?"
  exit 1
fi

install_hook() {
  local name="$1"
  local src="${ROOT}/tools/git-hooks/${name}"
  local dst="${HOOKS_DIR}/${name}"

  if [[ ! -f "${src}" ]]; then
    echo "ERROR: missing hook ${src}"
    exit 1
  fi

  cp "${src}" "${dst}"
  chmod +x "${dst}"
  echo "Installed ${name} hook."
}

install_hook pre-commit
