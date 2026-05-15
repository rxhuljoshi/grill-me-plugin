#!/usr/bin/env bash
# grill-me skill installer
# Usage: curl -fsSL https://raw.githubusercontent.com/rxhuljoshi/grill-me-plugin/main/install.sh | bash

set -euo pipefail

REPO="rxhuljoshi/grill-me-plugin"
BRANCH="main"
SKILL_NAME="grill-me"
SKILLS_DIR="${HOME}/.claude/skills"
TARGET_DIR="${SKILLS_DIR}/${SKILL_NAME}"
TMP_DIR="$(mktemp -d)"

cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

echo "→ Installing ${SKILL_NAME} skill..."

mkdir -p "${SKILLS_DIR}"

echo "→ Downloading from github.com/${REPO}@${BRANCH}..."
curl -fsSL "https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz" \
  | tar -xz -C "${TMP_DIR}"

SRC_DIR="${TMP_DIR}/grill-me-plugin-${BRANCH}/skills/${SKILL_NAME}"

if [[ ! -d "${SRC_DIR}" ]]; then
  echo "✗ Expected skill directory not found in download: ${SRC_DIR}" >&2
  exit 1
fi

if [[ -d "${TARGET_DIR}" ]]; then
  echo "→ Existing install found, backing up to ${TARGET_DIR}.bak"
  rm -rf "${TARGET_DIR}.bak"
  mv "${TARGET_DIR}" "${TARGET_DIR}.bak"
fi

mv "${SRC_DIR}" "${TARGET_DIR}"

echo ""
echo "✓ Installed ${SKILL_NAME} to ${TARGET_DIR}"
echo ""
echo "Restart Claude Code, then trigger with:"
echo "  /${SKILL_NAME}"
echo ""
echo "Or just say: 'grill me on this plan'"
