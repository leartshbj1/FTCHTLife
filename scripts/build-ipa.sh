#!/bin/bash
# Fabrique FTCHTLife.ipa non signé (à signer ensuite avec Sideloadly ou équivalent).
set -euo pipefail

echo "== Vérification des fichiers JSON"
find FTCHTLife/Resources/Data -name '*.json' -print0 | while IFS= read -r -d '' f; do
  python3 -m json.tool "$f" > /dev/null || { echo "JSON invalide : $f"; exit 1; }
done

echo "== XcodeGen"
if ! command -v xcodegen >/dev/null; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
fi
xcodegen generate

echo "== Compilation"
xcodebuild \
  -project FTCHTLife.xcodeproj \
  -scheme FTCHTLife \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build 2>&1 | tee build.log | grep -E "error:|warning: unre|BUILD (SUCCEEDED|FAILED)" || true
grep -q "BUILD SUCCEEDED" build.log || { echo "La compilation a échoué :"; grep -E "error:" build.log | head -50; exit 1; }

echo "== Emballage"
rm -rf Payload output && mkdir -p Payload output
cp -R build/Build/Products/Release-iphoneos/FTCHTLife.app Payload/
zip -qry output/FTCHTLife.ipa Payload
ls -lh output/FTCHTLife.ipa
