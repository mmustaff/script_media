#!/bin/bash

PATCH_DIR="../debian/patches/"
SERIES_FILE="${PATCH_DIR}/series"
SOURCE_DIR="$(pwd)"
RESULT_FILE="../patch_check_results.txt"

echo "Checking patches listed in '$SERIES_FILE' against source in '$SOURCE_DIR'"
echo "Results will be saved to '$RESULT_FILE'"
echo "---------------------------------------------------------------"

# Initialize result file
echo "Patch Check Results - $(date)" > "$RESULT_FILE"
echo "" >> "$RESULT_FILE"
echo "✅ SUCCESSFUL PATCHES:" >> "$RESULT_FILE"

SUCCESS_LIST=()
FAILED_LIST=()

# Check if patch directory exists
if [ ! -d "$PATCH_DIR" ]; then
	echo "❌ Patch directory '$PATCH_DIR' not found."
	exit 1
fi

if [ ! -f "$SERIES_FILE" ]; then
	echo "❌ Series file '$SERIES_FILE' not found."
	exit 1
fi


# Loop through each patch listed in the series file
while IFS= read -r patch_name; do
	patch_path="${PATCH_DIR}/${patch_name}"
	[ -e "$patch_path" ] || continue

	PATCH_NAME=$(basename "$patch_path")
	echo "🔍 Checking patch: $PATCH_NAME"

	if git apply --check --index "$patch_path" > /dev/null 2>&1; then
		echo "✅ SUCCESS: $PATCH_NAME can be applied."
		echo "$patch_path" >> "$RESULT_FILE"
		SUCCESS_LIST+=("$patch_path")
	else
		echo "❌ FAILED: $PATCH_NAME cannot be applied."
		FAILED_LIST+=("$patch_path")
	fi

echo "---------------------------------------------------------------"
done < "$SERIES_FILE"

# Log failed patches
echo "" >> "$RESULT_FILE"
echo "❌ FAILED PATCHES:" >> "$RESULT_FILE"
for failed in "${FAILED_LIST[@]}"; do
	echo "$failed" >> "$RESULT_FILE"
done

echo ""
echo "✅ Patch check complete. See '$RESULT_FILE' for details."

