#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
APP="$ROOT/app/src/main"
API="${LIBXPOSED_API_JAR:-$ROOT/.deps/libxposed-api-101.0.1.jar}"
SDK="${ANDROID_JAR:?Set ANDROID_JAR to the Android 34 SDK android.jar}"
R8="${R8_JAR:?Set R8_JAR to the R8/D8 compiler JAR}"
KEY="${MAGICLITE_KEYSTORE:?Set MAGICLITE_KEYSTORE to your private signing keystore}"
KEY_ALIAS="${MAGICLITE_KEY_ALIAS:-litefix}"
export MAGICLITE_KEYPASS="${MAGICLITE_KEYPASS:?Set MAGICLITE_KEYPASS}"
OUT="${OUT_DIR:-$ROOT/dist}"
BUILD="${MAGICLITE_BUILD_DIR:-$ROOT/.build}"
if [ -z "${RELEASE_TAG:-}" ]; then
  RELEASE_TAG=$(git -C "$ROOT" describe --tags --exact-match HEAD) || {
    echo 'Set RELEASE_TAG or build a tagged commit.' >&2
    exit 1
  }
fi
COMMIT_SHA="${COMMIT_SHA:-$(git -C "$ROOT" rev-parse --verify 'HEAD^{commit}')}"
for tool in javac java jar aapt2 zipalign apksigner python3; do command -v "$tool" >/dev/null; done
for file in "$API" "$SDK" "$R8" "$KEY"; do
  [ -f "$file" ] || { printf 'Missing dependency: %s\n' "$file" >&2; exit 1; }
done
mkdir -p "$BUILD" "$OUT"
TMP="$(mktemp -d "$BUILD/release.XXXXXX")"
python3 "$ROOT/scripts/release_metadata.py" --tag "$RELEASE_TAG" --commit "$COMMIT_SHA" --output-dir "$TMP" > "$TMP/release.env"
. "$TMP/release.env"
APK="$OUT/$ARTIFACT_NAME.apk"
mkdir -p "$TMP/classes" "$TMP/dex" "$TMP/res/values"
javac --release 17 -cp "$API:$SDK" -d "$TMP/classes" "$APP/java/com/hihonor/litefix/LiteFix.java"
jar --create --file "$TMP/module.jar" -C "$TMP/classes" .
java -cp "$R8" com.android.tools.r8.D8 --release --min-api 29 --lib "$SDK" --classpath "$API" --output "$TMP/dex" "$TMP/module.jar"
cp "$APP/res/values/strings.xml" "$TMP/res/values/strings.xml"
aapt2 compile --dir "$TMP/res" -o "$TMP/res.zip"
aapt2 link -I "$SDK" --manifest "$TMP/AndroidManifest.xml" "$TMP/res.zip" -o "$TMP/unsigned.apk"
python3 - "$ROOT" "$TMP" <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import sys
root, temp = map(Path, sys.argv[1:])
with ZipFile(temp / 'unsigned.apk', 'a', compression=ZIP_DEFLATED) as z:
    z.write(temp / 'dex/classes.dex', 'classes.dex')
    for name in ('java_init.list', 'module.prop', 'scope.list'):
        z.write(root / 'app/src/main/resources/META-INF/xposed' / name, 'META-INF/xposed/' + name)
PY
zipalign -f 4 "$TMP/unsigned.apk" "$TMP/aligned.apk"
apksigner sign --ks "$KEY" --ks-key-alias "$KEY_ALIAS" --ks-pass env:MAGICLITE_KEYPASS --key-pass env:MAGICLITE_KEYPASS --min-sdk-version 29 --v1-signing-enabled false --v2-signing-enabled true --v3-signing-enabled true --v4-signing-enabled false --out "$APK" "$TMP/aligned.apk"
apksigner verify --verbose "$APK"
zipalign -c 4 "$APK"
python3 "$ROOT/scripts/package_module.py" --apk "$APK" --module-prop "$TMP/module.prop"
printf 'Version: %s (%s)\nAPK: %s\n' "$VERSION_NAME" "$VERSION_CODE" "$APK"
