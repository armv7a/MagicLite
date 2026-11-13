[ "$BOOTMODE" = true ] || abort "Install from Magisk/KernelSU manager, not recovery."
[ "$API" -ge 29 ] || abort "Android 10+ is required."
(cd "$MODPATH" && sha256sum -c payload/LiteFix.apk.sha256) >/dev/null 2>&1 || abort "LiteFix APK checksum failed."
set_perm_recursive "$MODPATH" 0 0 0755 0644
for script in post-fs-data.sh service.sh uninstall.sh app-install.sh cleanup-apk.sh; do
  set_perm "$MODPATH/$script" 0 0 0755
 done
ui_print "MagicLite: user 0 only."
ui_print "Enable MagicLite in LSPosed and select HONOR Launcher manually."
ui_print "Removing this module uninstalls MagicLite companion and deletes its user-0 data."
if [ "$(getprop sys.boot_completed)" = 1 ]; then
  if sh "$MODPATH/app-install.sh"; then
    ui_print "MagicLite companion installed. Reboot to apply MagicLite properties."
  else
    ui_print "APK install deferred/failed; service.sh will retry after reboot."
  fi
else
  ui_print "APK will be installed after Android finishes booting."
fi
