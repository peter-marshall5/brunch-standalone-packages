# Allow users to create bootscripts (ending with .sh) in /mnt/stateful_partition/brunch_data/bootscripts/ which will be run on startup after modules are loaded

ret=0

cat >/roota/etc/init/bootscripts.conf <<BOOTSCRIPTS
start on stopped udev-trigger

script
	if [ \$(ls -1q /mnt/stateful_partition/brunch/bootscripts/*.sh 2>/dev/null | wc -l) -gt 0 ]; then
		for patch in /mnt/stateful_partition/brunch/bootscripts/*.sh
		do
			/bin/bash "\$patch"
		done
	fi
end script
BOOTSCRIPTS
if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 0))); fi

exit $ret
