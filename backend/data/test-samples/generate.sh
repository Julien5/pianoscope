#!/usr/bin/env bash

set -e
# set -x

function init() {
	SCRIPTDIR=$(realpath $(dirname $0))
	. $HOME/.profile &> /dev/null
}

function get-list() {
	D=$1
	shift 
	find ${D} -name "*.m4a" -type f | sort | \
		\
		while read a; do
			echo ${a} | cut -f4 -d" " | cut -f1 -d.
		done | sort | uniq | \
			\
			while read t; do
				find ${D} -name "*${t}*.m4a" -type f | sort -r 
			done
}

function convert-to-wav() {
	O=$2
	n=1
	get-list $1 | while read a; do
		mkdir -p ${O}/C${n}
		cp "${a}" ${O}/C${n}/all.m4a
		echo "copy C${n}"
		ffmpeg -i ${O}/C${n}/all.m4a ${O}/C${n}/all.wav &> /tmp/convert.txt
		n=$((n+1))
	done 
}


function note-name() {
	octave=$1
	shift
	octaven=$(echo ${octave} | cut -b2- )
	
	f=$1
	shift
	bb=$(basename $f | cut -f2 -d_ | cut -f1 -d.)
	b=$(printf %s\\n "$bb" | awk '{ print($1 + 0) }')
	
	midi=$((4+(octaven-1)*12+b-1)) 
	if [ "$b" = "1" ]; then
		echo "${midi}-C"
	elif [ "$b" = "2" ]; then
		echo "${midi}-C#"
	elif [ "$b" = "3" ]; then
		echo "${midi}-D"
	elif [ "$b" = "4" ]; then
		echo "${midi}-D#"
	elif [ "$b" = "5" ]; then
		echo "${midi}-E"
	elif [ "$b" = "6" ]; then
		echo "${midi}-F"
	elif [ "$b" = "7" ]; then
		echo "${midi}-F#"
	elif [ "$b" = "8" ]; then
		echo "${midi}-G"
	elif [ "$b" = "9" ]; then
		echo "${midi}-G#"
	elif [ "$b" = "10" ]; then
		echo "${midi}-A"
	elif [ "$b" = "11" ]; then
		echo "${midi}-A#"
	elif [ "$b" = "12" ]; then
		echo "${midi}-B"
	else
		exit 1
	fi
}

function main() {
	OUTDIR=$HOME/delme/old-piano-recordings
	if [ -d ${OUTDIR} ]; then
		echo "${OUTDIR} already exists => delete to regenerate."
		return
	fi
	
	R=${SCRIPTDIR}
	TMPDIR=$(mktemp -d /tmp/old-piano-split-XXX)
	mkdir -p ${TMPDIR}/m4a
	echo untar
	tar xf ${R}/old-piano.tgz -C ${TMPDIR}
	for k in 1 2; do
		rm -Rf ${TMPDIR}/position-${k}
		if [ ! -d ${R}/position-${k} ]; then
			convert-to-wav ${TMPDIR}/m4a/piano-${k} ${TMPDIR}/position-${k}
		fi
	done


	for k in 1 2; do
		find ${TMPDIR}/position-${k}/ -maxdepth 1 -mindepth 1 -type d | sort | while read C; do
			if [ -f ${C}/note_001.wav ]; then
				continue;
			fi
			if [ ! -f ${C}/all.wav ]; then
				continue;
			fi
			end="$(echo "$(basename "$(dirname "${C}")")/$(basename "${C}")")"
			# special cases for splitting... (found manually)
			threshold=0.05
			if [ "${end}" = "position-1/C1" ]; then
				threshold=0.02
			elif [ "${end}" = "position-1/C5" ]; then
				threshold=0.06
			fi
			echo -n "split ${end} (threshold=${threshold}).. "
			python3 split_wav.py --threshold ${threshold} ${C}/all.wav &> /tmp/split.txt
			nn=$(find ${C} -name "note*" | wc -l)
			echo "${nn} notes"
		done
	done
	
	for k in 1 2; do
		if [ ! -f ${TMPDIR}/position-${k}/C1/note_001.wav ]; then
			continue;
		fi
		${R}/sort-with-freq.sh ${TMPDIR}/position-${k}
		mkdir -p ${TMPDIR}/position-${k}/unsorted 
		mv ${TMPDIR}/position-${k}/C* ${TMPDIR}/position-${k}/unsorted 
	done

	for k in 1 2; do
		echo "notes in position ${k}"
		for octave in C1 C2 C3 C4 C5 C6 C7; do
			printf "%s:" "position-${k}/$d"
			rm -f ${TMPDIR}/position-${k}/sorted/${octave}/mark*.wav
			find ${TMPDIR}/position-${k}/sorted/${octave} -name "note_*" | while read note; do
				noteb=$(basename ${note});
				freq=$(python3 freq.py ${note} | cut -f1 -d" ");
				printf "%5d |" "${freq}";
				notename=$(note-name ${octave} ${note})
				cp ${note} ${TMPDIR}/position-${k}/sorted/${octave}/mark-${notename}.wav
			done
			echo
		done
	done

	find ${TMPDIR} -not -name mark* -type f -delete
	mkdir ${OUTDIR}
	cp -Rf ${TMPDIR}/position-1/sorted/. ${OUTDIR}/position-1
	cp -Rf ${TMPDIR}/position-2/sorted/. ${OUTDIR}/position-2
	rm -Rf ${TMPDIR}
}

init
main "$@"
