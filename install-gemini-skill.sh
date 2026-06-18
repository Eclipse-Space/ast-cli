#!/bin/sh
# Install the ast CLI binary and the ast Gemini CLI skill.
# One-liner usage:
#   curl -fsSL https://raw.githubusercontent.com/Eclipse-Space/ast-cli/main/install-gemini-skill.sh | bash

set -e

REPO="Eclipse-Space/ast-cli"
SKILL_DIR="${HOME}/.gemini/skills/ast"
BIN_DIR="${SKILL_DIR}/bin"
SKILL_URL="https://raw.githubusercontent.com/${REPO}/main/skills/ast/SKILL.md"

# ── 1. Install the CLI binary into the skill directory ───────────────────────
echo "Installing ast CLI..."
export AST_INSTALL_DIR="$BIN_DIR"
export AST_SKIP_DOCS=1
export AST_SKIP_PATH_HINT=1
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/install.sh" | sh

# ── 2. Install the Gemini CLI skill ─────────────────────────────────────────
echo ""
echo "Installing ast skill for Gemini CLI..."
mkdir -p "$SKILL_DIR"

if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$SKILL_URL" -o "${SKILL_DIR}/SKILL.md"
elif command -v wget >/dev/null 2>&1; then
    wget -qO "${SKILL_DIR}/SKILL.md" "$SKILL_URL"
else
    echo "ERROR: curl or wget is required to download the skill." >&2
    exit 1
fi

# ── 3. Best-effort symlink to ~/.local/bin ───────────────────────────────────
SYMLINK_TARGET="${HOME}/.local/bin/ast"
SYMLINK_DIR="$(dirname "$SYMLINK_TARGET")"
SYMLINK_MSG=""
if [ -d "$SYMLINK_DIR" ] && [ -w "$SYMLINK_DIR" ]; then
    ln -sf "${BIN_DIR}/ast" "$SYMLINK_TARGET" 2>/dev/null && \
        SYMLINK_MSG="  Symlink    : ${SYMLINK_TARGET} -> ${BIN_DIR}/ast"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "Done!"
echo ""
echo "  Binary     : ${BIN_DIR}/ast"
echo "  Skill      : ${SKILL_DIR}/SKILL.md"
if [ -n "$SYMLINK_MSG" ]; then
    echo "$SYMLINK_MSG"
fi
echo ""
echo "Restart Gemini CLI to activate the ast skill."
echo ""
echo "Tip: install as a full extension instead (includes context file):"
echo "  gemini extensions install https://github.com/Eclipse-Space/ast-cli"
