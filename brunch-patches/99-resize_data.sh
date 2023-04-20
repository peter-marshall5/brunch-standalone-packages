# This patch generates a script which is used to fix the size of the data partition after creating a ChromeOS usb disk from Windows

ret=0
cat >/roota/usr/sbin/resize-data <<RESIZEDATA
#!/bin/bash
cd /
if ( ! test -z {,} ); then echo "Must be ran with \"bash\""; exit 1; fi
if [ \$(whoami) != "root" ]; then echo "Please run with this script with sudo"; exit 1; fi
source=\$(rootdev -d)
if (expr match "\$source" ".*[0-9]\$" >/dev/null); then
	partsource="\$source"p
else
	partsource="\$source"
fi
disk_size=\$(blockdev --getsz "\$source")
cgpt add -i 1 -b \$(cgpt show -i 1 -b "\$source") -s \$(( disk_size - \$(cgpt show -i 1 -b "\$source") - 48 )) -t \$(cgpt show -i 1 -t "\$source") -l \$(cgpt show -i 1 -l "\$source") "\$source"
cgpt repair "\$source"
cgpt show "\$source"
sync
partx -u "\$source"
resize2fs -f "\$partsource"1
read -p "System needs to reboot now, press [Enter] key to do so."
reboot
RESIZEDATA
if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 0))); fi
chmod 0755 /roota/usr/sbin/resize-data
if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 1))); fi
exit $ret
