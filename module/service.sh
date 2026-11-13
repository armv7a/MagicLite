#!/system/bin/sh
set -u
MODDIR=$(dirname "$0")
COUNT=0
while [ "$(getprop sys.boot_completed)" != 1 ]; do
  [ -d "$MODDIR" ] && [ ! -f "$MODDIR/disable" ] && [ ! -f "$MODDIR/remove" ] || exit 0
  [ "$COUNT" -lt 90 ] || { echo "LiteFix: boot wait timed out; retry next boot" >&2; exit 1; }
  sleep 2
  COUNT=$((COUNT + 1))
done
[ -d "$MODDIR" ] && [ ! -f "$MODDIR/disable" ] && [ ! -f "$MODDIR/remove" ] || exit 0
sh "$MODDIR/app-install.sh"
