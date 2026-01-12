#!/usr/bin/env bash
set -euo pipefail

# --- Defaults (relative to repo root where you run this script) ---
DEBIAN_CHANGELOG="debian/changelog"
SOURCE_DIR="source"
OUTPUT_DIR="$(pwd)"   # default: current parent folder

# --- Minimal arg parsing ---
# Usage: ./make_source_tarball.sh [--output-dir <path>]
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      shift
      OUTPUT_DIR="${1:-}"
      if [[ -z "${OUTPUT_DIR}" ]]; then
        echo "❌ --output-dir requires a value"
        exit 1
      fi
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--output-dir <path>]

- Reads version info from: debian/changelog (first line)
- Archives CONTENTS of:   source/
- Tarball name pattern:   <pkg>_<upstream>-<series>.tar.gz
                          e.g., intel-gmmlib_22.8.2-noble2.tar.gz

Examples:
  $0
  $0 --output-dir ./artifacts
EOF
      exit 0
      ;;
    *)
      echo "❌ Unknown argument: $1"
      echo "   Use --help for usage."
      exit 1
      ;;
  esac
  shift
done

# --- Validate paths ---
[[ -d "${SOURCE_DIR}" ]] || { echo "❌ Source dir not found: ${SOURCE_DIR}"; exit 1; }
[[ -f "${DEBIAN_CHANGELOG}" ]] || { echo "❌ Changelog not found: ${DEBIAN_CHANGELOG}"; exit 1; }
mkdir -p "${OUTPUT_DIR}" || { echo "❌ Cannot create/access output dir: ${OUTPUT_DIR}"; exit 1; }

# --- Read first line of changelog ---
# Expected example:
# intel-gmmlib (22.8.2-1ppa1~noble2) noble; urgency=medium
first_line="$(head -n 1 "${DEBIAN_CHANGELOG}")"

# --- Parse package and version in parentheses ---
pkg="$(echo "${first_line}" | sed -n 's/^\s*\([^ ]\+\)\s*(.*).*$/\1/p')"
paren_ver="$(echo "${first_line}" | sed -n 's/^[^(]*(\([^)]\+\)).*$/\1/p')"

if [[ -z "${pkg}" || -z "${paren_ver}" ]]; then
  echo "❌ Cannot parse package/version from changelog line:"
  echo "   ${first_line}"
  exit 1
fi

# Split: <upstream>-<debianrev>~<series>
upstream_with_rev="${paren_ver%%~*}"   # before ~
series="${paren_ver#*~}"               # after ~
upstream="${upstream_with_rev%%-*}"    # before first '-'

if [[ -z "${upstream}" || -z "${series}" || "${upstream}" == "${upstream_with_rev}" ]]; then
  echo "❌ Version format unexpected: '${paren_ver}'"
  echo "   Expect: '<upstream>-<debianrev>~<series>' e.g. 22.8.2-1ppa1~noble2"
  exit 1
fi

tarball="${OUTPUT_DIR}/${pkg}_${upstream}-${series}.tar.gz"

echo "📦 Package:      ${pkg}"
echo "🔢 Upstream:     ${upstream}"
echo "🧾 Series:       ${series}"
echo "📁 Source dir:   ${SOURCE_DIR}"
echo "🎯 Output file:  ${tarball}"
echo "---------------------------------------------------------------"

# --- Create tarball from CONTENTS of source/ only ---
# -C source . puts files at archive root (no extra 'source/' directory inside)
[[ -f "${tarball}" ]] && rm -f "${tarball}"
tar -czvf "${tarball}" -C "${SOURCE_DIR}" .

echo "✅ Tarball created: ${tarball}"
``
