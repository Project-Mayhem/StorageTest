#!/bin/sh
#
# Keep the container alive using an endless loop
#
# Filename: keep-alive.sh
#

STAY_ALIVE_SLEEP_TIME="5m"
MESSAGE="Looping to stay alive, press [CTRL+c] to stop"

printf "${MESSAGE} "
while true
do
	printf "."
	sleep ${STAY_ALIVE_SLEEP_TIME}
done

printf "\n"
