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

install_build_deps_no_downgrades() {
    local control_file="$1"
    local apt_tool=(
        apt-get
        -o Debug::pkgProblemResolver=yes
        --no-install-recommends
        -o APT::Get::allow-downgrades=false
    )

    (
        set -euo pipefail
        local tmpdir deb_pkg sim_out
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "${tmpdir}"' EXIT

        # Build the *-build-deps*.deb in a temp dir (no root required).
        cd "${tmpdir}"
        mk-build-deps --tool "${apt_tool[*]}" "${control_file}"
        deb_pkg="$(ls -1 "${tmpdir}"/*build-deps*.deb 2>/dev/null | head -n 1)"
        if [[ -z "${deb_pkg}" ]]; then
            echo "ERROR: mk-build-deps did not produce a *build-deps*.deb in ${tmpdir}" >&2
            exit 1
        fi

        # Simulate the install first; refuse to proceed if APT would downgrade anything.
        sim_out="$(sudo "${apt_tool[@]}" -s install "${deb_pkg}" || true)"
        if echo "${sim_out}" | grep -Eqi '(^|\n)The following packages will be DOWNGRADED:|(^|\n)Downgraded:|DOWNGRADED'; then
            echo "ERROR: Refusing to install build-dependencies because APT plans to downgrade packages." >&2
            echo "---- APT simulation output (downgrade-related lines) ----" >&2
            echo "${sim_out}" | grep -Ei 'DOWNGRADED|Downgrad' >&2 || true
            echo "--------------------------------------------------------" >&2
            exit 1
        fi

        # Proceed with the real install.
        sudo "${apt_tool[@]}" install -y "${deb_pkg}"
    )
}

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
    read -r -p "Install build dependencies (refuse downgrades)? [Y/n] " _ans
    if [[ "${_ans:-}" =~ ^[Nn]([Oo])?$ ]]; then
        echo "Skipping: build-dependency installation"
    else
        install_build_deps_no_downgrades "${PWD}/debian/control"
    fi
else
    # Non-interactive mode: keep existing behavior
    install_build_deps_no_downgrades "${PWD}/debian/control"
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
