#!/usr/local/bin/zsh

if [ ${#secadm_dir} -eq 0 ]; then
	secadm_dir="${HOME}/projects/secadm"
	secadm_libdir="${secadm_dir}/libsecadm/obj"
	secadm_conf="/usr/local/etc/secadm.rules"
fi

function vg_secadm() {
	LD_LIBRARY_PATH="${secadm_libdir}" \
		sudo valgrind \
			--leak-check=full \
			${secadm_dir}/secadm/obj/secadm \
			-c ${secadm_conf} \
			"validate"
}

function secadm_dups() {
	config=${1}
	res=0
	tmpfile=$(mktemp)

	if [ ${#config} -eq 0 ]; then
		echo "USAGE: ${0} /path/to/config" >&2
		return 1
	fi

	# Assume the Integriforce section is the last section.
	# Trim what we look at to only the Integriforce section.
	
	line=$(grep -niF 'integriforce' ${config} | awk '{print $1;}' \
	    | sed 's/://')
	if [ ${#line} -eq 0 ]; then
		rm -f ${tmpfile}
		return 0
	fi

	foreach file in $(sed -e 1,${line}d ${config} | grep -i path \
	    | awk '{print $2;}' | sed 's/[",]//g'); do
		printout=1

		while read tfile; do
			if [ ${tfile} = ${file} ]; then
				printout=0
			fi
		done < ${tmpfile}

		if [ ${printout} -eq 1 ]; then
			count=$(sed -e 1,${line}d ${config} \
			    | grep -iw ${file} | uniq -c \
			    | awk '{print $1;}')

			if [ $((${count} + 0)) -gt 1 ]; then
				echo ${file} >> ${tmpfile}
				echo "${file} has ${count} entries"
				res=$((${res} + 1))
			fi
		fi
	done

	rm -f ${tmpfile}

	return ${res}
}
