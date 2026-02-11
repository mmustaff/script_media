
#!/usr/bin/env bash
set -euo pipefail

# Default paths
DEBIAN_CHANGELOG="debian/changelog"
SOURCE_DIR="source"
OUTPUT_DIR="$(pwd)"
PATCH_SCRIPT_DIR="${HOME}/script_media"
PATCH_SCRIPT_NAME="patch_apply.sh"

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      shift
      OUTPUT_DIR="${1:?Missing value for --output-dir}"
      ;;
    --patch-script-dir)
      shift
      PATCH_SCRIPT_DIR="${1:?Missing value for --patch-script-dir}"
      ;;
    *)
      echo "❌ Unknown arg: $1"
      exit 1
      ;;
  esac
  shift
done

# --- Validate repo layout ---
[[ -f "$DEBIAN_CHANGELOG" ]] || { echo "❌ Missing: $DEBIAN_CHANGELOG"; exit 1; }
[[ -d "$SOURCE_DIR" ]] || { echo "❌ Missing: $SOURCE_DIR"; exit 1; }
mkdir -p "$OUTPUT_DIR"

PATCH_SCRIPT_SRC="${PATCH_SCRIPT_DIR}/${PATCH_SCRIPT_NAME}"
[[ -f "$PATCH_SCRIPT_SRC" ]] || {
  echo "❌ Cannot find required pre-step script: $PATCH_SCRIPT_SRC"
  exit 1
}

# ---------------------------------------------------------
# STEP 1: Check for uncommitted changes in source/
# ---------------------------------------------------------
if ! git -C "$SOURCE_DIR" diff --quiet || ! git -C "$SOURCE_DIR" diff --cached --quiet; then
  echo "⚠️  Uncommitted or unstaged changes detected in '$SOURCE_DIR'."
  read -r -p "Reset changes and remove unstaged files? [y/N]: " answer

  if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "🔄 Resetting and cleaning '$SOURCE_DIR'..."
    git -C "$SOURCE_DIR" reset --hard
    git -C "$SOURCE_DIR" clean -fd
  else
    echo "❌ Aborting: source folder is dirty and user chose not to reset."
    exit 1
  fi
fi

# ---------------------------------------------------------
# STEP 2: Parse changelog line
# ---------------------------------------------------------
first_line="$(head -n 1 "$DEBIAN_CHANGELOG")"

pkg="$(echo "$first_line" | sed -n 's/^\s*\([^ ]\+\)\s*(.*).*$/\1/p')"
paren_ver="$(echo "$first_line" | sed -n 's/^[^(]*(\([^)]\+\)).*$/\1/p')"

[[ -n "$pkg" && -n "$paren_ver" ]] || {
  echo "❌ Cannot parse changelog first line: $first_line"
  exit 1
}

# Remove epoch (N:version → version)
ver_no_epoch="${paren_ver#*:}"

ver="$ver_no_epoch"
first_tilde=$(expr index "$ver" "~")
first_dash=$(expr index "$ver" "-")

# Pattern detection (A or B)
if (( first_tilde > 0 && (first_tilde < first_dash || first_dash == 0) )); then
  # Pattern B: upstream~rev-series
  upstream="${ver%%~*}"
  series="${ver##*-}"
else
  # Pattern A: upstream-rev~series
  upstream="${ver%%-*}"
  series="${ver##*~}"
fi

[[ -n "$upstream" && -n "$series" ]] || {
  echo "❌ Failed parsing version: $ver"
  exit 1
}

tarball="${OUTPUT_DIR}/${pkg}_${upstream}-${series}.tar.gz"

echo "📦 Package:     $pkg"
echo "🔢 Upstream:    $upstream"
echo "🧾 Series:      $series"
echo "🧩 Patch script: $PATCH_SCRIPT_SRC"
echo "📁 Source dir:  $SOURCE_DIR"
echo "🎯 Output file: $tarball"
echo "---------------------------------------------------------------"

# ---------------------------------------------------------
# STEP 3: Copy patch_apply.sh into source/ and run it
# ---------------------------------------------------------
cp -f "$PATCH_SCRIPT_SRC" "${SOURCE_DIR}/${PATCH_SCRIPT_NAME}"
chmod +x "${SOURCE_DIR}/${PATCH_SCRIPT_NAME}"

echo "▶ Running patch script inside source/: ${PATCH_SCRIPT_NAME}"
pushd "$SOURCE_DIR" >/dev/null
"./${PATCH_SCRIPT_NAME}"
popd >/dev/null

# ---------------------------------------------------------
# STEP 4: Create tarball from contents of source/
# ---------------------------------------------------------
[[ -f "$tarball" ]] && rm -f "$tarball"
tar -czvf "$tarball" -C "$SOURCE_DIR" .

echo "✅ Tarball created: $tarball"

# ---------------------------------------------------------
# STEP 5: Refresh git submodules
# ---------------------------------------------------------
echo "🔄 Refreshing submodules..."
git submodule update --init

echo "🎉 Done."
