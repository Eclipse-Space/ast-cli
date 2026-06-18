#!/bin/sh
set -e

REPO="Eclipse-Space/ast-cli"
BINARY="ast"
INSTALL_DIR="${AST_INSTALL_DIR:-$HOME/.local/bin}"

# Detect OS
case "$(uname -s)" in
    Darwin) os="darwin" ;;
    Linux)  os="linux" ;;
    *)
        echo "Unsupported OS: $(uname -s)" >&2
        exit 1
        ;;
esac

# Detect architecture
case "$(uname -m)" in
    x86_64|amd64)   arch="x64" ;;
    arm64|aarch64)  arch="arm64" ;;
    *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

# Detect musl on Linux
platform="${os}-${arch}"
if [ "$os" = "linux" ]; then
    if ldd /bin/ls 2>&1 | grep -q musl; then
        platform="${os}-${arch}-musl"
    fi
fi

# Resolve download URL from latest release
BASE_URL="https://github.com/${REPO}/releases/latest/download"
BINARY_URL="${BASE_URL}/${BINARY}-${platform}"
CHECKSUM_URL="${BASE_URL}/checksums.sha256"

# Pick downloader
if command -v curl >/dev/null 2>&1; then
    dl() { curl -fsSL "$1"; }
    dl_to() { curl -fsSL -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
    dl() { wget -qO- "$1"; }
    dl_to() { wget -qO "$2" "$1"; }
else
    echo "curl or wget is required" >&2
    exit 1
fi

echo "Downloading ast for ${platform}..."

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

dl_to "$BINARY_URL" "$TMP"

# Verify checksum
echo "Verifying checksum..."
CHECKSUMS=$(dl "$CHECKSUM_URL")
EXPECTED=$(echo "$CHECKSUMS" | grep "  ${BINARY}-${platform}$" | cut -d' ' -f1)

if [ -z "$EXPECTED" ]; then
    echo "Could not find checksum for ${platform}" >&2
    exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL=$(sha256sum "$TMP" | cut -d' ' -f1)
elif command -v shasum >/dev/null 2>&1; then
    ACTUAL=$(shasum -a 256 "$TMP" | cut -d' ' -f1)
else
    echo "No sha256 tool found, skipping checksum verification" >&2
    ACTUAL="$EXPECTED"
fi

if [ "$ACTUAL" != "$EXPECTED" ]; then
    echo "Checksum mismatch (expected $EXPECTED, got $ACTUAL)" >&2
    exit 1
fi

# Install binary
mkdir -p "$INSTALL_DIR"
chmod +x "$TMP"
mv "$TMP" "${INSTALL_DIR}/${BINARY}"

DOCS_DIR="$HOME/.ast/docs"

# Install reference docs
if [ "${AST_SKIP_DOCS:-}" != "1" ]; then
    DOCS_URL="https://raw.githubusercontent.com/${REPO}/main/skills/ast/SKILL.md"
    mkdir -p "$DOCS_DIR"
    echo "Downloading reference docs..."
    dl_to "$DOCS_URL" "${DOCS_DIR}/ast.md"
fi

if [ "${AST_SKIP_PATH_HINT:-}" != "1" ]; then
    echo ""
    echo "Installed to ${INSTALL_DIR}/${BINARY}"
    echo "Reference docs: ${DOCS_DIR}/ast.md"

    # PATH hint
    case ":${PATH}:" in
        *":${INSTALL_DIR}:"*) ;;
        *)
            echo ""
            echo "Add the following to your shell profile to use the CLI:"
            echo "  export PATH=\"\$PATH:${INSTALL_DIR}\""
            ;;
    esac

    echo ""
    "${INSTALL_DIR}/${BINARY}" --version
else
    echo ""
    echo "Installed to ${INSTALL_DIR}/${BINARY}"
    "${INSTALL_DIR}/${BINARY}" --version
fi
