#!/bin/bash

PATCH_DIR="../debian/patches"
SERIES_FILE="${PATCH_DIR}/series"
RESULT_FILE="patch_check_results.txt"

echo "Removing failed patches listed in '$RESULT_FILE'"
echo "Updating series file: '$SERIES_FILE'"
echo "---------------------------------------------------------------"

# Check if required files exist
if [ ! -f "$RESULT_FILE" ]; then
	echo "❌ Error: '$RESULT_FILE' not found."
	exit 1
fi

if [ ! -f "$SERIES_FILE" ]; then
	echo "❌ Error: '$SERIES_FILE' not found."
	exit 1
fi

# Extract failed patch paths
FAILED_PATCHES=$(awk '/^❌ FAILED PATCHES:/ {flag=1; next} flag' "$RESULT_FILE")

# Process each failed patch
while IFS= read -r patch_path; do
	[ -e "$patch_path" ] || continue

	PATCH_NAME=$(basename "$patch_path")

	# Remove patch file
	echo "🗑️ Removing patch file: $patch_path"
	rm -f "$patch_path"

	# Remove entry from series file
	echo "✂️ Removing '$PATCH_NAME' from series file"
	sed -i "/^${PATCH_NAME}$/d" "$SERIES_FILE"

done <<< "$FAILED_PATCHES"

echo ""
echo "✅ Cleanup complete. Failed patches removed from folder and series file."

