# With dual boot method, the "real" device partitions are considered as external by ChromeOS.
# They are therefore systematically scanned by the android media scanner which generates significant cpu usage.
# Try to replicate the official ChromeOS mechanism by considering only usb devices and sdcard as external storage.
# Nevertheless we leave the option "mount_internal_drives" for those who might want direct access to their "real" partitions.

disable_internal_drives=1
disable_sdcard_storage=0
disable_usb_storage=0
for i in $(echo "$1" | sed 's#,# #g')
do
	if [ "$i" == "mount_internal_drives" ]; then disable_internal_drives=0; fi
	if [ "$i" == "disable_sdcard_storage" ]; then disable_sdcard_storage=1; fi
	if [ "$i" == "disable_usb_storage" ]; then disable_usb_storage=1; fi
done

ret=0
cat >/roota/lib/udev/rules.d/99-hdd_fix.rules <<HDDFIX
ACTION=="add", SUBSYSTEMS=="block", ATTRS{removable}=="0", ENV{UDISKS_PRESENTATION_HIDE}="$disable_internal_drives"
ACTION=="add", SUBSYSTEMS=="mmc", ATTRS{type}!="MMC", ENV{UDISKS_PRESENTATION_HIDE}="$disable_sdcard_storage"
ACTION=="add", SUBSYSTEMS=="usb", ENV{UDISKS_PRESENTATION_HIDE}="$disable_usb_storage"
HDDFIX
if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 0))); fi
exit $ret
