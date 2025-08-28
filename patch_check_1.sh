#!/bin/bash

PATCH_DIR="../debian/patches/"
SOURCE_DIR="$(pwd)"

echo "Checking patches in '$PATCH_DIR' against source in '$SOURCE_DIR'"
echo "---------------------------------------------------------------"

# Check if patch directory exists
if [ ! -d "$PATCH_DIR" ]; then
	    echo "❌ Patch directory '$PATCH_DIR' not found."
	        exit 1
fi

# Loop through all .patch files
for patch in "$PATCH_DIR"/*.patch; do
	[ -e "$patch" ] || continue  # Skip if no patch files found

	        PATCH_NAME=$(basename "$patch")
		    echo "🔍 Checking patch: $PATCH_NAME"

		        if git apply --check "$patch" > /dev/null 2>&1; then
				        echo "✅ SUCCESS: $PATCH_NAME can be applied."
					    else
						            echo "❌ FAILED: $PATCH_NAME cannot be applied."
							        fi

								    echo "---------------------------------------------------------------"
							    done
