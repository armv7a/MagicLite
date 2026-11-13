#!/system/bin/sh
set -u
umask 077
MODDIR=$(dirname "$0")
PACKAGE=com.hihonor.litefix
(cd "$MODDIR" && sha256sum -c payload/LiteFix.apk.sha256) >/dev/null 2>&1 || {
  echo "LiteFix: APK checksum failed" >&2
  exit 1
}
if [ -f "$MODDIR/.apk-installed" ]; then
  case "$(pm path --user 0 "$PACKAGE" 2>/dev/null)" in
    package:*) exit 0 ;;
  esac
fi
DATA_ADB=$(dirname "$(dirname "$MODDIR")")
STAGE_ROOT="$(dirname "$DATA_ADB")/local/tmp"
mkdir -p "$STAGE_ROOT" || exit 1
STAGEDIR=$(mktemp -d "$STAGE_ROOT/magic_lite.XXXXXX") || exit 1
case "$STAGEDIR" in "$STAGE_ROOT"/magic_lite.*) ;; *) exit 1 ;; esac
trap 'rm -f -- "$STAGEDIR/LiteFix.apk"; rmdir -- "$STAGEDIR"' 0
cp "$MODDIR/payload/LiteFix.apk" "$STAGEDIR/LiteFix.apk" || exit 1
chmod 0755 "$STAGEDIR" || exit 1
chmod 0644 "$STAGEDIR/LiteFix.apk" || exit 1
restorecon "$STAGEDIR" "$STAGEDIR/LiteFix.apk" || exit 1
if RESULT=$(pm install -r --user 0 "$STAGEDIR/LiteFix.apk" 2>&1); then
  if printf '%s\n' "$RESULT" | grep -qx Success; then
    printf '%s\n' "$RESULT" > "$MODDIR/apk-install.log"
    touch "$MODDIR/.apk-installed"
    exit 0
  fi
fi
printf '%s\n' "$RESULT" > "$MODDIR/apk-install.log"
echo "LiteFix: APK installation failed; check apk-install.log" >&2
exit 1
