#!/bin/bash

RESULT_FILE="../patch_check_results.txt"
SOURCE_DIR="$(pwd)"
BUILD_SCRIPT="$1"
BUILDABLE_LOG="../buildable_patches.txt"
FAILED_LOG="../failed_buildable_patches.txt"


if [ -z "$BUILD_SCRIPT" ]; then
	echo "❌ Error: Please provide the build script as an argument."
	echo "Usage: $0 ./path/to/build_script.sh"
	exit 1
fi

if [ ! -x "$BUILD_SCRIPT" ]; then
	echo "❌ Error: Build script '$BUILD_SCRIPT' is not executable."
	exit 1
fi

echo "Verifying buildable patches from '$RESULT_FILE'"
echo "Using build script: $BUILD_SCRIPT"
echo "---------------------------------------------------------------"

# Initialize log
echo "Buildable Patches - $(date)" > "$BUILDABLE_LOG"
echo "" >> "$BUILDABLE_LOG"

# Initialize failed log
echo "Failed Buildable Patches - $(date)" > "$FAILED_LOG"
echo "" >> "$FAILED_LOG"

# Extract successful patch paths
SUCCESS_PATCHES=$(awk '/^✅ SUCCESSFUL PATCHES:/ {flag=1; next} /^❌ FAILED PATCHES:/ {flag=0} flag' "$RESULT_FILE")

# Apply and test each patch
while IFS= read -r patch; do
	[ -e "$patch" ] || continue

	PATCH_NAME=$(basename "$patch")
	echo "🔧 Applying patch: $PATCH_NAME"

	if git am "$patch" > /dev/null 2>&1; then
		echo "✅ Patch applied: $PATCH_NAME"
		echo "🔨 Running build..."

		if "$BUILD_SCRIPT"; then
			echo "✅ BUILD SUCCESS: $PATCH_NAME"
			echo "$patch" >> "$BUILDABLE_LOG"
		else
			echo "❌ BUILD FAILED: $PATCH_NAME"
			COMMITTER=$(grep -m1 "^From: " "$patch" | sed 's/^From: //')
			echo "$patch - Committer: $COMMITTER" >> "$FAILED_LOG"
			git reset --hard HEAD~1  # Revert the patch
		fi
	else
		echo "❌ Failed to apply patch: $PATCH_NAME"
		git am --abort
	fi

	echo "---------------------------------------------------------------"
done <<< "$SUCCESS_PATCHES"

echo ""
echo "✅ Build verification complete."
echo "✔ Successful patches: $BUILDABLE_LOG"
echo "✘ Failed patches: $FAILED_LOG"
