#!/bin/bash

BASE_DIR="."  # Change this to your actual directory if needed
VERSIONS_FILE="$BASE_DIR/versions.txt"

# Find all repository folders
REPOS=($(find "$BASE_DIR" -maxdepth 1 -type d -name "os.linux.ubuntu.iot.debianpkgs.*"))

# Check if any repository folders exist
if [ ${#REPOS[@]} -eq 0 ]; then
    echo "❌ No repository folders found in $BASE_DIR"
    exit 1
fi

# If versions.txt doesn't exist, create a template
if [ ! -f "$VERSIONS_FILE" ]; then
    echo "📝 versions.txt not found. Creating template..."
    for repo in "${REPOS[@]}"; do
        name=$(basename "$repo" | awk -F. '{print $NF}')
        echo "$name:" >> "$VERSIONS_FILE"
    done
    echo "✅ Template created at $VERSIONS_FILE. Please fill in the versions and rerun the script."
    exit 1
fi

# Load versions into associative array
declare -A versions
while IFS=: read -r key value; do
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    if [ -n "$key" ] && [ -n "$value" ]; then
        versions["$key"]="$value"
    fi
done < "$VERSIONS_FILE"

# Process each repository
for repo in "${REPOS[@]}"; do
    name=$(basename "$repo" | awk -F. '{print $NF}')
    source_dir="$repo/source"

    # Check if source folder exists and is not empty
    if [ ! -d "$source_dir" ] || [ -z "$(ls -A "$source_dir")" ]; then
        echo "❌ Source folder missing or empty for $name"
        continue
    fi

    # Determine version tag
    if [ "$name" == "media-driver-non-free" ]; then
        tag="${versions["media-driver"]}"
    else
        tag="${versions["$name"]}"
    fi

    if [ -z "$tag" ]; then
        echo "⚠️ No version tag specified for $name in versions.txt"
        continue
    fi

    # Perform git checkout
    echo "🔄 Checking out $name to tag $tag..."
    (
        cd "$source_dir" && git checkout "$tag"
    )
    if [ $? -eq 0 ]; then
        echo "✅ $name checked out to $tag"
    else
        echo "❌ Failed to checkout $name to $tag"
    fi
    echo "----------------------------------------"
done
