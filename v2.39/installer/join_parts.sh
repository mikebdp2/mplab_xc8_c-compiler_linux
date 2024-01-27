#!/bin/sh
printf "=== Removing an old archive if it exists\n"
                                                           rm -f "./xc8-v2.39-full-install-linux-x64-installer.run"
printf "=== Making a new archive from its parts\n"
                                                           touch "./xc8-v2.39-full-install-linux-x64-installer.run"
cat "./xc8-v2.39-full-install-linux-x64-installer.run_part01" >> "./xc8-v2.39-full-install-linux-x64-installer.run"
cat "./xc8-v2.39-full-install-linux-x64-installer.run_part02" >> "./xc8-v2.39-full-install-linux-x64-installer.run"
printf "=== Doing a sync command (just in case)\n"
sync
printf "=== Finding a sha256sum of this archive\n"
sha256sum_correct="d7746b7bf55f9776c47b141678b10a7e3f1fc12f68028402946f2819a3a313b1  ./xc8-v2.39-full-install-linux-x64-installer.run"
sha256sum_my=$(sha256sum "./xc8-v2.39-full-install-linux-x64-installer.run")
printf "=== sha256sum should be\n$sha256sum_correct\n"
if [ "$sha256sum_my" = "$sha256sum_correct" ] ; then
    printf "^^^ this is correct, you can use a ./xc8-v2.39-full-install-linux-x64-installer.run now...\n"
                                     chmod +x "./xc8-v2.39-full-install-linux-x64-installer.run"
    exit 0
else
    printf "^^^ ! MISMATCH ! Check sha256sum manually: sha256sum ./xc8-v2.39-full-install-linux-x64-installer.run\n"
    exit 1
fi
###
