#!/bin/bash
# Generate the Yacht release signing keystore. Run this ONCE.
#
# IMPORTANT:
#  - Write down the password you choose (1Password, etc.)
#  - Back up the resulting yacht-release.keystore file somewhere safe
#  - If you lose either, you can never update Yacht on Play again
#
# The keystore file is gitignored — it will NOT be pushed to GitHub.

set -e
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$SCRIPT_DIR/../android/app"
JDK_HOME="$HOME/.tools/jdk-21.0.11+10/Contents/Home"
KEYSTORE="$APP_DIR/yacht-release.keystore"

if [ -f "$KEYSTORE" ]; then
  echo "❌  Keystore already exists at: $KEYSTORE"
  echo "    Move it aside before regenerating."
  exit 1
fi

cd "$APP_DIR"
"$JDK_HOME/bin/keytool" -genkey -v \
  -keystore yacht-release.keystore \
  -alias yacht \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000

if [ ! -f "$KEYSTORE" ]; then
  echo ""
  echo "❌  Keytool did not produce a keystore. Re-run and answer the prompts."
  exit 1
fi

echo ""
echo "✅  Keystore created: $KEYSTORE"
echo "    Save the password in a password manager NOW."
echo ""
echo "Press return to close this window…"
read -r _
