#!/bin/bash
set -euo pipefail

# Default locations assume you run this script from a repo's source directory.
PATCH_DIR="${PATCH_DIR:-"../debian/patches"}"
SERIES_FILE="${SERIES_FILE:-"${PATCH_DIR}/series"}"
SOURCE_DIR="$(pwd)"
RESULT_FILE="${RESULT_FILE:-"../patch_check_results.txt"}"
MAX_ERROR_LINES="${MAX_ERROR_LINES:-200}"

echo "Checking patches listed in '${SERIES_FILE}' against source in '${SOURCE_DIR}'"
echo "Results will be saved to '${RESULT_FILE}'"
echo "---------------------------------------------------------------"

# Basic validations
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo "❌ Current directory is not a git repository: ${SOURCE_DIR}"
	exit 1
fi

if [ ! -d "${PATCH_DIR}" ]; then
	echo "❌ Patch directory '${PATCH_DIR}' not found."
	exit 1
fi

if [ ! -f "${SERIES_FILE}" ]; then
	echo "❌ Series file '${SERIES_FILE}' not found."
	exit 1
fi

# Refuse to run on a dirty working tree because we apply patches sequentially.
if [ -n "$(git status --porcelain)" ]; then
	echo "❌ Working tree is not clean. Please stash/commit changes before patch checking."
	git status --porcelain
	exit 2
fi

ORIG_HEAD="$(git rev-parse HEAD)"
cleanup() {
	# Always restore the repo to a clean state even if patch application fails mid-way.
	git reset --hard "${ORIG_HEAD}" >/dev/null 2>&1 || true
	git clean -fd >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Initialize result file
{
	echo "Patch Check Results - $(date)"
	echo ""
	echo "✅ SUCCESSFUL PATCHES:"
} > "${RESULT_FILE}"

SUCCESS_LIST=()
SKIPPED_LIST=()
FAILED_LIST=()
FAILED_REASONS=()

patch_index=0

# Loop through each patch listed in the series file.
# NOTE: This checks patches *cumulatively* in series order.
while IFS= read -r raw_line; do
	# Strip Windows CR if present
	line="${raw_line%$'\r'}"

	# Skip blank lines and comments
	[[ -z "${line}" ]] && continue
	[[ "${line}" =~ ^[[:space:]]*# ]] && continue

	# Debian series lines can include options; first token is patch filename
	patch_rel="${line%%[[:space:]]*}"
	patch_path="${PATCH_DIR}/${patch_rel}"

	patch_index=$((patch_index + 1))
	PATCH_NAME="$(basename "${patch_path}")"
	echo "🔍 [${patch_index}] Checking patch: ${PATCH_NAME}"

	if [ ! -f "${patch_path}" ]; then
		echo "❌ FAILED: missing patch file: ${patch_path}"
		FAILED_LIST+=("${patch_path}")
		FAILED_REASONS+=("missing patch file")
		echo "---------------------------------------------------------------"
		continue
	fi

	# If reverse-check succeeds, patch is already applied to this source.
	if git apply --reverse --check "${patch_path}" >/dev/null 2>&1; then
		echo "⏭️  SKIP: ${PATCH_NAME} is already applied"
		SKIPPED_LIST+=("${patch_path}")
		echo "---------------------------------------------------------------"
		continue
	fi

	# Apply patch (cumulatively) so later patches can depend on earlier ones.
	set +e
	apply_out="$(git apply --index "${patch_path}" 2>&1)"
	apply_status=$?
	set -e

	if [ ${apply_status} -eq 0 ]; then
		echo "✅ SUCCESS: ${PATCH_NAME} applied cleanly"
		SUCCESS_LIST+=("${patch_path}")
		echo "---------------------------------------------------------------"
		continue
	fi

	echo "❌ FAILED: ${PATCH_NAME} cannot be applied (exit=${apply_status})"
	FAILED_LIST+=("${patch_path}")
	FAILED_REASONS+=("${apply_out}")
	echo "---------------------------------------------------------------"
done < "${SERIES_FILE}"

# Write results
for success in "${SUCCESS_LIST[@]}"; do
	echo "${success}" >> "${RESULT_FILE}"
done

{
	echo ""
	echo "⏭️  SKIPPED PATCHES (already applied):"
} >> "${RESULT_FILE}"
for skipped in "${SKIPPED_LIST[@]}"; do
	echo "${skipped}" >> "${RESULT_FILE}"
done

{
	echo ""
	echo "❌ FAILED PATCHES:"
} >> "${RESULT_FILE}"

for i in "${!FAILED_LIST[@]}"; do
	echo "${FAILED_LIST[$i]}" >> "${RESULT_FILE}"
done

if [ ${#FAILED_LIST[@]} -gt 0 ]; then
	{
		echo ""
		echo "--- FAILURE DETAILS (git apply output) ---"
	} >> "${RESULT_FILE}"

	for i in "${!FAILED_LIST[@]}"; do
		{
			echo ""
			echo "### ${FAILED_LIST[$i]}"
			echo "${FAILED_REASONS[$i]}" | sed -n "1,${MAX_ERROR_LINES}p"
		} >> "${RESULT_FILE}"
	done
fi

echo ""
echo "✅ Patch check complete. See '${RESULT_FILE}' for details."

