
#!/usr/bin/env bash
set -euo pipefail

# -------- Configuration --------
PATCH_DIR="../debian/patches"
SERIES_FILE="${PATCH_DIR}/series"
RESULT_FILE="../patch_apply_results.txt"

# Extra options for git am (adjust as needed)
GIT_AM_OPTS=(--3way --keep-cr)
# To be lenient on whitespace problems, uncomment:
# GIT_AM_OPTS+=(--whitespace=nowarn)
# Or to auto-fix whitespace:
# GIT_AM_OPTS+=(--whitespace=fix)

# -------- Preamble --------
SOURCE_DIR="$(pwd)"
echo "Applying patches from '${SERIES_FILE}' onto repo: ${SOURCE_DIR}"
echo "Results will be saved to '${RESULT_FILE}'"
echo "---------------------------------------------------------------"

# Initialize result file
{
  echo "Patch Apply Results - $(date)"
  echo ""
  echo "✅ SUCCESSFUL PATCHES:"
} > "${RESULT_FILE}"

SUCCESS_LIST=()
FAILED_LIST=()

# -------- Sanity Checks --------
if [ ! -d "${PATCH_DIR}" ]; then
  echo "❌ Patch directory '${PATCH_DIR}' not found."
  exit 1
fi

if [ ! -f "${SERIES_FILE}" ]; then
  echo "❌ Series file '${SERIES_FILE}' not found."
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ Current directory is not a Git repository: ${SOURCE_DIR}"
  exit 1
fi

# If a previous 'git am' session is in progress, abort it first
if git am --show-current-patch >/dev/null 2>&1; then
  echo "⚠️  Found in-progress 'git am'. Aborting before starting..."
  git am --abort || true
fi

# Optional: warn if working tree is dirty
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️  Working tree has uncommitted changes. Consider committing/stashing before applying patches."
fi

# -------- Apply Patches --------
echo "Starting to apply patches using 'git am'..."
echo "---------------------------------------------------------------"

# Read the series file, ignore blank lines and comments
while IFS= read -r raw_line || [ -n "$raw_line" ]; do
  # Trim whitespace
  line="$(echo "$raw_line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  # Skip blank lines and comments
  if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
    continue
  fi

  patch_path="${PATCH_DIR}/${line}"

  if [ ! -e "$patch_path" ]; then
    echo "❌ Missing patch file: ${patch_path}"
    FAILED_LIST+=("$patch_path (not found)")
    echo "---------------------------------------------------------------"
    continue
  fi

  patch_name="$(basename "$patch_path")"
  echo "📦 Applying patch: ${patch_name}"

  if git am "${GIT_AM_OPTS[@]}" "$patch_path" >/dev/null 2>&1; then
    echo "✅ SUCCESS: ${patch_name}"
    echo "$patch_path" >> "${RESULT_FILE}"
    SUCCESS_LIST+=("$patch_path")
  else
    echo "❌ FAILED: ${patch_name}"
    FAILED_LIST+=("$patch_path")

    # Try to capture some context (optional)
    # Note: this may be empty if am aborted immediately
    git am --show-current-patch >/dev/null 2>&1 || true

    # Abort and continue to next patch
    git am --abort >/dev/null 2>&1 || true
  fi

  echo "---------------------------------------------------------------"
done < "${SERIES_FILE}"

# -------- Write Failures --------
{
  echo ""
  echo "❌ FAILED PATCHES:"
  if [ "${#FAILED_LIST[@]}" -eq 0 ]; then
    echo "(none)"
  else
    for failed in "${FAILED_LIST[@]}"; do
      echo "$failed"
    done
  fi
} >> "${RESULT_FILE}"

# -------- Summary --------
echo ""
if [ "${#FAILED_LIST[@]}" -eq 0 ]; then
  echo "✅ All patches applied successfully."
else
  echo "⚠️  Some patches failed to apply."
fi
echo "📄 See '${RESULT_FILE}' for details."
