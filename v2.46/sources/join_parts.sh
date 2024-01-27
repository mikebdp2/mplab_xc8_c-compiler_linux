#!/bin/sh
printf "=== Removing an old archive if it exists\n"
                                      rm -f "./xc8-avr-sources-v2.46.zip"
printf "=== Making a new archive from its parts\n"
                                      touch "./xc8-avr-sources-v2.46.zip"
cat "./xc8-avr-sources-v2.46.zip_part01" >> "./xc8-avr-sources-v2.46.zip"
cat "./xc8-avr-sources-v2.46.zip_part02" >> "./xc8-avr-sources-v2.46.zip"
cat "./xc8-avr-sources-v2.46.zip_part03" >> "./xc8-avr-sources-v2.46.zip"
cat "./xc8-avr-sources-v2.46.zip_part04" >> "./xc8-avr-sources-v2.46.zip"
printf "=== Doing a sync command (just in case)\n"
sync
printf "=== Finding a sha256sum of this archive\n"
sha256sum_correct="2e7f490eeac8cc7e168c35cb30e339b1315fd68bee2392fe172a06fa304a315e  ./xc8-avr-sources-v2.46.zip"
sha256sum_my=$(sha256sum "./xc8-avr-sources-v2.46.zip")
printf "=== sha256sum should be\n$sha256sum_correct\n"
if [ "$sha256sum_my" = "$sha256sum_correct" ] ; then
    printf "^^^ this is correct, you can use a ./xc8-avr-sources-v2.46.zip now...\n"
    exit 0
else
    printf "^^^ ! MISMATCH ! Check sha256sum manually: sha256sum ./xc8-avr-sources-v2.46.zip\n"
    exit 1
fi
###
