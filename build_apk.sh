#!/usr/bin/env bash
# Builds SmartScan for release with secrets injected from secrets.json
# (gitignored, so the Resend key never lands in the repo).
#
#   ./build_apk.sh         → shareable universal APK  (SmartScan.apk)
#   ./build_apk.sh aab     → Play Store bundle (AAB)  (SmartScan.aab)
#   ./build_apk.sh all     → both
set -e
cd "$(dirname "$0")"

if [ ! -f secrets.json ]; then
  echo "secrets.json missing. Copy secrets.example.json → secrets.json and add your Resend key."
  exit 1
fi
if [ ! -f android/key.properties ]; then
  echo "WARNING: android/key.properties missing — release build will fall back to DEBUG signing."
fi

TARGET="${1:-apk}"

build_apk() {
  flutter build apk --release --dart-define-from-file=secrets.json
  cp build/app/outputs/flutter-apk/app-release.apk SmartScan.apk
  echo "→ SmartScan.apk (share/sideload)"
}
build_aab() {
  flutter build appbundle --release --dart-define-from-file=secrets.json
  cp build/app/outputs/bundle/release/app-release.aab SmartScan.aab
  echo "→ SmartScan.aab (upload to Play Console)"
}

case "$TARGET" in
  apk) build_apk ;;
  aab) build_aab ;;
  all) build_apk; build_aab ;;
  *) echo "Usage: ./build_apk.sh [apk|aab|all]"; exit 1 ;;
esac
echo "Done."
