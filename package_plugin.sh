#!/bin/bash
# Packages QField4OBM into a versioned ZIP for local deployment.
# Usage:
#   ./package_plugin.sh            — reads version from metadata.txt
#   ./package_plugin.sh 1.2.3      — overrides version

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

PLUGIN_NAME="QField4OBM"

# Determine version
if [ -n "$1" ]; then
  VERSION="$1"
else
  VERSION=$(grep -m1 '^version=' metadata.txt | cut -d'=' -f2 | tr -d '[:space:]')
fi

if [ -z "$VERSION" ]; then
  echo "ERROR: Could not read version from metadata.txt"
  exit 1
fi

ZIP_NAME="${PLUGIN_NAME}-${VERSION}.zip"

echo "Packaging $PLUGIN_NAME v${VERSION} → $ZIP_NAME"

# Remove old versioned zips
rm -f "${PLUGIN_NAME}-"*.zip

# Zip the relevant files
zip -r "$ZIP_NAME" \
  main.qml \
  scripts \
  components \
  metadata.txt \
  *.png \
  *.svg

# --- Local deployment (skip in CI) ---
if [ "${CI}" != "true" ]; then
  TARGET_DIR="/home/ferencattila/NextcloudDelHeves/attila/qfieldplugin"
  echo "Copying to $TARGET_DIR..."
  mkdir -p "$TARGET_DIR"
  cp "$ZIP_NAME" "$TARGET_DIR/"

  # Remove QML cache so QField picks up fresh files
  QML_CACHE="${HOME}/.cache/OPENGIS.ch/QField/qmlcache"
  if [ -d "$QML_CACHE" ]; then
    rm -rf "${QML_CACHE:?}/"*
    echo "QML cache cleared."
  fi

  LOCAL_FOLDER="${HOME}/Documents/QField Documents/QField/plugins/QField4OBM"
  if [ -d "$LOCAL_FOLDER" ]; then
    echo "Updating local plugin folder..."
    cp -r main.qml scripts components metadata.txt *.png *.svg "$LOCAL_FOLDER/"
  fi
fi

echo "Done! $ZIP_NAME is ready."