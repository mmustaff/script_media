#!/usr/bin/env bash
set -euo pipefail

BUILDDIR="builddir"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-"${SCRIPT_DIR}/logs"}"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/build_meson_$(date +%Y%m%d_%H%M%S).log"

# Log both commands and their output.
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "Logging to: ${LOG_FILE}"
echo "Started: $(date -Is)"
echo "PWD: $(pwd)"
echo "Args: $*"

export PS4='+ $(date "+%F %T") ${BASH_SOURCE##*/}:${LINENO}: '
set -x

trap 'status=$?; set +x; echo "Finished: $(date -Is)"; echo "Exit status: ${status}"' EXIT

usage() {
	cat <<'EOF'
Usage:
  build_meson.sh [clean]

Options:
  clean   Remove the build directory before configuring/building.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

if [[ "${1:-}" == "clean" ]]; then
	echo "Cleaning ${BUILDDIR}/"
	rm -rf -- "${BUILDDIR}"
	shift
fi

if [[ "${1:-}" != "" ]]; then
	echo "Unknown argument: ${1}" >&2
	usage >&2
	exit 2
fi

if [[ -d "${BUILDDIR}" ]]; then
	meson setup --reconfigure "${BUILDDIR}"
else
	meson setup "${BUILDDIR}"
fi
meson compile -C "${BUILDDIR}"

read -r -p "Run 'meson install -C ${BUILDDIR}'? [y/N] " answer
case "${answer}" in
	[yY]|[yY][eE][sS])
		meson install -C "${BUILDDIR}"
		;;
	*)
		echo "Skipping install."
		;;
esac
