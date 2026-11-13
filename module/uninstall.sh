#!/system/bin/sh
set -eu
umask 077
MODDIR=$(dirname "$0")
DATA_ADB=$(dirname "$(dirname "$MODDIR")")
QUEUE="$DATA_ADB/service.d/magic_lite-remove-apk.sh"
# PackageManager may not exist during early module removal; queue a standalone cleanup.
mkdir -p "$DATA_ADB/service.d"
cp "$MODDIR/cleanup-apk.sh" "$QUEUE"
chmod 0700 "$QUEUE"
if [ "$(getprop sys.boot_completed)" = 1 ]; then
  sh "$QUEUE" || true
fi
