#!/bin/bash

RESULT_FILE="../patch_check_results.txt"
SOURCE_DIR="$(pwd)"
APPLY_LOG="../patch_apply_log.txt"

echo "Applying successful patches from '$RESULT_FILE'"
echo "Source directory: $SOURCE_DIR"
echo "---------------------------------------------------------------"

# Initialize log file
echo "Patch Apply Log - $(date)" > "$APPLY_LOG"
echo "" >> "$APPLY_LOG"

# Extract successful patch paths
SUCCESS_PATCHES=$(awk '/^✅ SUCCESSFUL PATCHES:/ {flag=1; next} /^❌ FAILED PATCHES:/ {flag=0} flag' "$RESULT_FILE")

# Apply each patch using git am
while IFS= read -r patch; do
	[ -e "$patch" ] || continue

	PATCH_NAME=$(basename "$patch")
	echo "🔧 Applying patch: $PATCH_NAME"

	if git am "$patch" > /dev/null 2>&1; then
		echo "✅ APPLIED: $PATCH_NAME" | tee -a "$APPLY_LOG"
	else
		echo "❌ FAILED TO APPLY: $PATCH_NAME" | tee -a "$APPLY_LOG"
		git am --abort  # Abort in case of failure to keep repo clean
	fi

	echo "---------------------------------------------------------------" >> "$APPLY_LOG"
done <<< "$SUCCESS_PATCHES"

echo ""
echo "✅ Patch application complete. See '$APPLY_LOG' for details."
