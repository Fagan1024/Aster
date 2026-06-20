#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
PRODUCTS_DIR="$DERIVED_DATA/Build/Products/Release"
APP_NAME="Aster.app"

xcodebuild \
  -project "$ROOT_DIR/Aster.xcodeproj" \
  -scheme "Aster" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

rm -rf "$BUILD_DIR/$APP_NAME"
ditto "$PRODUCTS_DIR/$APP_NAME" "$BUILD_DIR/$APP_NAME"

echo "Built: $BUILD_DIR/$APP_NAME"
