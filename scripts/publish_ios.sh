#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEYS_DIR="$ROOT_DIR/.keys"

: "${ASC_KEY_ID:?'ASC_KEY_ID not set — check .keys/env.sh'}"
: "${ASC_ISSUER_ID:?'ASC_ISSUER_ID not set — check .keys/env.sh'}"

KEY_PATH="$KEYS_DIR/asc_api_key.p8"
ALTOOL_KEYS_DIR="$HOME/.private_keys"

if [ ! -f "$KEY_PATH" ]; then
  echo "Missing $KEY_PATH — see .keys/README.md for setup instructions"
  exit 1
fi

# altool looks for AuthKey_{KEY_ID}.p8 in standard locations; stage it there.
mkdir -p "$ALTOOL_KEYS_DIR"
cp "$KEY_PATH" "$ALTOOL_KEYS_DIR/AuthKey_${ASC_KEY_ID}.p8"

cd "$ROOT_DIR"

echo "==> Building iOS release IPA..."
# Surface the build's commit in the app's Settings footer (read by
# String.fromEnvironment('GIT_COMMIT')) so TestFlight bug reports are traceable.
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo nogit)
flutter build ipa --release \
    --dart-define=GIT_COMMIT="$GIT_COMMIT" \
    --export-options-plist="scripts/ExportOptions-AppStore-iOS.plist"

IPA_PATH=$(find build/ios/ipa -name '*.ipa' | head -1)
if [ -z "$IPA_PATH" ]; then
  echo "No .ipa found in build/ios/ipa — build may have failed"
  exit 1
fi
echo "==> Found IPA: $IPA_PATH"

echo "==> Uploading to App Store Connect..."
xcrun altool --upload-app \
    -f "$IPA_PATH" \
    --type ios \
    --apiKey    "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"

echo "==> Done. Visit App Store Connect to monitor processing."
