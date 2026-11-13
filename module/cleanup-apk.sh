#!/system/bin/sh
set -u
umask 077
SCRIPT=$0
case "$SCRIPT" in
  /*/service.d/magic_lite-remove-apk.sh) ;;
  *) echo "LiteFix: cleanup must run from its queued service.d path" >&2; exit 1 ;;
esac
[ ! -L "$SCRIPT" ] || exit 1
DATA_ADB=$(dirname "$(dirname "$SCRIPT")")
LOG="$DATA_ADB/magic_lite-uninstall.log"
PACKAGE=com.hihonor.litefix
COUNT=0
while [ "$(getprop sys.boot_completed)" != 1 ]; do
  [ "$COUNT" -lt 90 ] || { echo "Boot wait timed out; retry next boot" >> "$LOG"; exit 1; }
  sleep 2
  COUNT=$((COUNT + 1))
done
# A reflash/update must not have its newly installed APK removed by an old cleanup.
for MODULE in "$DATA_ADB/modules/magic_lite" "$DATA_ADB/modules_update/magic_lite"; do
  if [ -f "$MODULE/module.prop" ] && [ ! -f "$MODULE/remove" ]; then
    echo "Cancelled stale cleanup: magic_lite was reinstalled" >> "$LOG"
    rm -f -- "$SCRIPT"
    exit 0
  fi
done
if PACKAGES=$(pm list packages --user 0 "$PACKAGE" 2>&1); then
  if ! printf '%s\n' "$PACKAGES" | grep -qx "package:$PACKAGE"; then
    echo "LiteFix is already absent for user 0" >> "$LOG"
    rm -f -- "$SCRIPT"
    exit 0
  fi
else
  printf '%s\n' "$PACKAGES" >> "$LOG"
  exit 1
fi
if RESULT=$(pm uninstall --user 0 "$PACKAGE" 2>&1); then
  if printf '%s\n' "$RESULT" | grep -qx Success; then
    printf '%s\n' "$RESULT" >> "$LOG"
    rm -f -- "$SCRIPT"
    exit 0
  fi
fi
printf '%s\n' "$RESULT" >> "$LOG"
exit 1
