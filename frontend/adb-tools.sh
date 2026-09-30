#!/usr/bin/env bash

# source me

function package_name() {
	if [ ! -f android/app/build.gradle.kts ]; then
		echo cannot find android/app/build.gradle.kts
		return 1
	fi
	grep -E "applicationId|namespace" android/app/build.gradle.kts | cut -f2 -d"\"" | head -1
}

function adb.start() {
	PACKAGENAME=$(package_name)
	adb -s $(pixel) shell monkey -p ${PACKAGENAME} -c android.intent.category.LAUNCHER 1
}

function adb.log() {
	PACKAGENAME=$(package_name)
	PID=$(adb -s $(pixel) shell pidof -s ${PACKAGENAME})
	echo package: $PACKAGENAME pid: $PID 
	adb -s $(pixel) logcat --pid=$PID 
}

function adb.kill() {
	PACKAGENAME=$(package_name)
	adb -s $(pixel) shell am force-stop ${PACKAGENAME}
}
