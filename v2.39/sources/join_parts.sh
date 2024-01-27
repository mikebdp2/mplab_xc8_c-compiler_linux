#!/bin/sh
printf "=== Removing an old archive if it exists\n"
                                      rm -f "./xc8_v2.39_AVR_sources.zip"
printf "=== Making a new archive from its parts\n"
                                      touch "./xc8_v2.39_AVR_sources.zip"
cat "./xc8_v2.39_AVR_sources.zip_part01" >> "./xc8_v2.39_AVR_sources.zip"
cat "./xc8_v2.39_AVR_sources.zip_part02" >> "./xc8_v2.39_AVR_sources.zip"
printf "=== Doing a sync command (just in case)\n"
sync
printf "=== Finding a sha256sum of this archive\n"
sha256sum_correct="08bd15a00b48c02251cb01aa56678e0c5d4a0aa8a4c1c70fffe65155e4a623b3  ./xc8_v2.39_AVR_sources.zip"
sha256sum_my=$(sha256sum "./xc8_v2.39_AVR_sources.zip")
printf "=== sha256sum should be\n$sha256sum_correct\n"
if [ "$sha256sum_my" = "$sha256sum_correct" ] ; then
    printf "^^^ this is correct, you can use a ./xc8_v2.39_AVR_sources.zip now...\n"
    exit 0
else
    printf "^^^ ! MISMATCH ! Check sha256sum manually: sha256sum ./xc8_v2.39_AVR_sources.zip\n"
    exit 1
fi
###
