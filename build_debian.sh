#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-"${SCRIPT_DIR}/logs"}"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/build_debian_$(date +%Y%m%d_%H%M%S).log"

# Log both commands and their output.
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "Logging to: ${LOG_FILE}"
echo "Started: $(date -Is)"
echo "PWD: $(pwd)"
echo "Args: $*"

export PS4='+ $(date "+%F %T") ${BASH_SOURCE##*/}:${LINENO}: '
set -x

trap 'status=$?; set +x; echo "Finished: $(date -Is)"; echo "Exit status: ${status}"' EXIT

# 1. Setup absolute paths
ROOT_DIR="$(pwd)"
OUTPUT_DIR="$ROOT_DIR/deb"
SOURCE_DIR="$ROOT_DIR/source"

# 2. Clean previous output folder
if [ -d "$OUTPUT_DIR" ]; then
    echo "Removing existing deb/ folder..."
    rm -rf "$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"

# 3. Prepare source repository
if [[ -t 0 ]]; then
    read -r -p "Run 'git submodule update --init'? [Y/n] " _ans
    if [[ "${_ans:-}" =~ ^[Nn]([Oo])?$ ]]; then
        echo "Skipping: git submodule update --init"
    else
        git submodule update --init
    fi
else
    # Non-interactive mode: keep existing behavior
    git submodule update --init
fi
cd "$SOURCE_DIR"

# Remove debian folder if it already exists to avoid copy conflicts
if [ -d "debian" ]; then
    echo "Cleaning existing debian/ folder in source..."
    rm -rf debian
fi

git reset --hard HEAD
git clean -fd

# 4. Copy fresh debian configuration
cp -R ../debian ./

# 5. Install build dependencies
if [[ -t 0 ]]; then
    read -r -p "Run 'sudo mk-build-deps -i -s sudo ./debian/control'? [Y/n] " _ans
    if [[ "${_ans:-}" =~ ^[Nn]([Oo])?$ ]]; then
        echo "Skipping: sudo mk-build-deps -i -s sudo ./debian/control"
    else
        sudo mk-build-deps -i -s sudo ./debian/control
    fi
else
    # Non-interactive mode: keep existing behavior
    sudo mk-build-deps -i -s sudo ./debian/control
fi

# 6. Build the package (outputs to parent directory)
debuild -b -uc -us

# 7. Move artifacts to the output directory
# Using a glob that matches common Debian build outputs
mv ../*.deb ../*.changes ../*.buildinfo ../*.ddeb ../*.build "$OUTPUT_DIR/" 2>/dev/null || true

# 8. Success Cleanup
echo "Build successful. Cleaning up source directory..."
git reset --hard HEAD
git clean -fd
# Also remove the copied debian folder specifically
rm -rf debian

echo "--------------------------------------------------"
echo "Success! Files are located in: $OUTPUT_DIR"
