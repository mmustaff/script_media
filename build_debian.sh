#!/bin/bash
set -e

# 1. Setup absolute paths
ROOT_DIR="$(pwd)"
OUTPUT_DIR="$ROOT_DIR/deb"
SOURCE_DIR="$ROOT_DIR/source"

# 2. Clean previous output folder
if [ -d "$OUTPUT_DIR" ]; then
    echo "Removing existing deb/ folder..."
    rm -rf "$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"

# 3. Prepare source repository
git submodule update --init
cd "$SOURCE_DIR"

# Remove debian folder if it already exists to avoid copy conflicts
if [ -d "debian" ]; then
    echo "Cleaning existing debian/ folder in source..."
    rm -rf debian
fi

git reset --hard HEAD
git clean -fd

# 4. Copy fresh debian configuration
cp -R ../debian ./

# 5. Install build dependencies
sudo mk-build-deps -i -s sudo ./debian/control

# 6. Build the package (outputs to parent directory)
debuild -b -uc -us

# 7. Move artifacts to the output directory
# Using a glob that matches common Debian build outputs
mv ../*.deb ../*.changes ../*.buildinfo ../*.ddeb ../*.build "$OUTPUT_DIR/" 2>/dev/null || true

# 8. Success Cleanup
echo "Build successful. Cleaning up source directory..."
git reset --hard HEAD
git clean -fd
# Also remove the copied debian folder specifically
rm -rf debian

echo "--------------------------------------------------"
echo "Success! Files are located in: $OUTPUT_DIR"
