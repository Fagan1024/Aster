#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Aster"
APP_BUNDLE="$APP_NAME.app"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$BUILD_DIR/dist"
STAGING_DIR="$BUILD_DIR/package-staging"
APP_PATH="$BUILD_DIR/$APP_BUNDLE"
SIGNED_APP_PATH="$DIST_DIR/$APP_BUNDLE"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
DMG_TEMP_PATH="$DIST_DIR/$APP_NAME.temp.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-AsterNotary}"
NOTARIZE=0

usage() {
  cat <<USAGE
Usage: ./package.sh [--notarize]

Builds Aster, signs it with a Developer ID Application certificate, and creates
a DMG at build/dist/Aster.dmg.

Options:
  --notarize   Submit the DMG with xcrun notarytool, wait for approval, then staple.

Environment:
  DEVELOPER_ID_APPLICATION   Exact signing identity. If omitted, the first
                             "Developer ID Application" identity in Keychain is used.
  NOTARY_PROFILE             notarytool keychain profile name. Default: AsterNotary.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notarize)
      NOTARIZE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

find_developer_id_identity() {
  security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application: .* \(([^)]*)\)\)".*/\1/p' \
    | head -n 1
}

SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-$(find_developer_id_identity)}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  cat >&2 <<ERROR
No Developer ID Application signing identity was found.

Install a "Developer ID Application" certificate in Keychain, then run this
script again. Current identities:
ERROR
  security find-identity -v -p codesigning >&2 || true
  exit 1
fi

echo "==> Building $APP_BUNDLE"
"$ROOT_DIR/build.sh"

echo "==> Preparing distribution folder"
rm -rf "$DIST_DIR" "$STAGING_DIR"
mkdir -p "$DIST_DIR" "$STAGING_DIR"
ditto "$APP_PATH" "$SIGNED_APP_PATH"

echo "==> Signing with: $SIGNING_IDENTITY"
codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "$SIGNING_IDENTITY" \
  "$SIGNED_APP_PATH"

echo "==> Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$SIGNED_APP_PATH"

echo "==> Creating DMG"
ditto "$SIGNED_APP_PATH" "$STAGING_DIR/$APP_BUNDLE"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH" "$DMG_TEMP_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  "$DMG_TEMP_PATH" >/dev/null
hdiutil convert "$DMG_TEMP_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$DMG_TEMP_PATH"

echo "==> Signing DMG"
codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

if [[ "$NOTARIZE" -eq 1 ]]; then
  echo "==> Submitting DMG for notarization with profile: $NOTARY_PROFILE"
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  echo "==> Stapling notarization ticket"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"

  echo "==> Assessing notarized DMG"
  spctl -a -vvv -t open --context context:primary-signature "$DMG_PATH"
fi

echo "Packaged: $DMG_PATH"
