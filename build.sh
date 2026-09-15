#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
MODE="${1:-install}"
if [[ "$MODE" != install && "$MODE" != --no-install ]]; then
  echo 'Usage: ./build.sh [--no-install]' >&2
  exit 2
fi
if ! xcrun --find swift >/dev/null 2>&1; then
  echo 'Install Command Line Tools with: xcode-select --install, then run ./build.sh again.' >&2
  exit 1
fi
swift build -c release
APP="$PWD/dist/Blocks.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
BIN_DIR="$(swift build -c release --show-bin-path)"
cp "$BIN_DIR/Blocks" "$APP/Contents/MacOS/Blocks"
# Compile the icon renderer with the exact geometry used by the running app.
cat Sources/Blocks/Brand.swift scripts/icon.swift > "$PWD/.build/render-brand.swift"
swift "$PWD/.build/render-brand.swift" "$PWD/.build/Blocks.iconset"
cp "$PWD/.build/Blocks.iconset/icon_512x512@2x.png" Resources/Blocks.png
iconutil -c icns "$PWD/.build/Blocks.iconset" -o "$APP/Contents/Resources/Blocks.icns"

IDENTITY="${BLOCKS_SIGNING_IDENTITY:-Blocks Local Code Signing}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
if ! security find-identity -v -p codesigning "$KEYCHAIN" | grep -Fq "\"$IDENTITY\""; then
  echo 'Preparing the stable local signing identity in your login keychain…'
  SIGN_DIR="$(mktemp -d)"
  trap 'rm -rf "$SIGN_DIR"' EXIT
  umask 077
  OPENSSL="$(command -v openssl)"
  if [[ -x /opt/homebrew/opt/openssl@3/bin/openssl ]]; then OPENSSL=/opt/homebrew/opt/openssl@3/bin/openssl; fi
  if [[ -x /usr/local/opt/openssl@3/bin/openssl ]]; then OPENSSL=/usr/local/opt/openssl@3/bin/openssl; fi
  if security find-identity -p codesigning "$KEYCHAIN" | grep -Fq "\"$IDENTITY\""; then
    # Resume a previous import whose one-time trust dialog was cancelled.
    security find-certificate -c "$IDENTITY" -p "$KEYCHAIN" > "$SIGN_DIR/cert.pem"
  else
  cat > "$SIGN_DIR/cert.conf" <<'CERT'
[req]
distinguished_name = name
x509_extensions = extensions
prompt = no
[name]
CN = Blocks Local Code Signing
[extensions]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
CERT
  "$OPENSSL" req -new -newkey rsa:2048 -x509 -sha256 -nodes -days 3650 -config "$SIGN_DIR/cert.conf" -keyout "$SIGN_DIR/key.pem" -out "$SIGN_DIR/cert.pem" 2>/dev/null
  IMPORT_PASSWORD="$("$OPENSSL" rand -hex 24)"
  printf '%s' "$IMPORT_PASSWORD" > "$SIGN_DIR/password"
  # OpenSSL 3 defaults produce PKCS#12 files Apple's keychain cannot import.
  # LibreSSL already defaults to the compatible legacy format.
  if "$OPENSSL" version | grep -q '^OpenSSL 3'; then
    "$OPENSSL" pkcs12 -export -legacy -inkey "$SIGN_DIR/key.pem" -in "$SIGN_DIR/cert.pem" -out "$SIGN_DIR/identity.p12" -passout "file:$SIGN_DIR/password"
  else
    "$OPENSSL" pkcs12 -export -inkey "$SIGN_DIR/key.pem" -in "$SIGN_DIR/cert.pem" -out "$SIGN_DIR/identity.p12" -passout "file:$SIGN_DIR/password"
  fi
  security import "$SIGN_DIR/identity.p12" -k "$KEYCHAIN" -P "$IMPORT_PASSWORD" -T /usr/bin/codesign
  fi
  echo 'macOS may ask you to authenticate to trust this local certificate. Complete that dialog on your Mac.'
  security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$SIGN_DIR/cert.pem"
fi
codesign --force --sign "$IDENTITY" --keychain "$KEYCHAIN" --identifier local.blocks.focus --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
if [[ "$MODE" == --no-install ]]; then
  echo "Built and signed: $APP"
  exit 0
fi
if pgrep -x Blocks >/dev/null || pgrep -x Park >/dev/null; then
  echo 'Quit Blocks (and any previous Park instance) from its menu (your block will be saved), then run ./build.sh again.' >&2
  exit 1
fi
if [[ -d /Applications/Blocks.app ]]; then
  EXISTING_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' /Applications/Blocks.app/Contents/Info.plist)
  if [[ "$EXISTING_ID" != local.blocks.focus ]]; then
    echo '/Applications/Blocks.app belongs to a different app; move it before installing Blocks.' >&2
    exit 1
  fi
fi
ditto "$APP" /Applications/Blocks.app
codesign --verify --strict /Applications/Blocks.app
# Retain the previous branded install for rollback, outside Applications.
if [[ -d /Applications/Park.app ]] && [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' /Applications/Park.app/Contents/Info.plist)" == local.park.focus ]]; then
  BACKUP_DIR="$PWD/.build/previous-install-$(date +%Y%m%d%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  mv /Applications/Park.app "$BACKUP_DIR/Park.app"
fi
open /Applications/Blocks.app
echo 'Blocks is installed and running. Look for Blocks in the menu bar. Capture a thought with ⌘/.'
