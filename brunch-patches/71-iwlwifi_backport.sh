# Add the option "iwlwifi_backport" to make use of the newer iwlwifi module built-in brunch

iwlwifi_backport=0
for i in $(echo "$1" | sed 's#,# #g')
do
	if [ "$i" == "iwlwifi_backport" ]; then iwlwifi_backport=1; fi
done

ret=0
if [ "$iwlwifi_backport" -eq 1 ]; then
	cp -r /roota/lib/modules/$(cat /proc/version |  cut -d' ' -f3)/iwlwifi_backport/* /roota/lib/modules/$(cat /proc/version |  cut -d' ' -f3)/
	if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 0))); fi
fi
exit $ret
