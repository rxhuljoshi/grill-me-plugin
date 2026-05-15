#!/usr/bin/env bash
# grill-me skill uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/rxhuljoshi/grill-me-plugin/main/uninstall.sh | bash

set -euo pipefail

SKILL_NAME="grill-me"
TARGET_DIR="${HOME}/.claude/skills/${SKILL_NAME}"

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "✓ Nothing to do — ${SKILL_NAME} not installed."
  exit 0
fi

rm -rf "${TARGET_DIR}" "${TARGET_DIR}.bak"
echo "✓ Removed ${SKILL_NAME} from ${TARGET_DIR}"
