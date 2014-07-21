function memusage_fbsd() {
    if [ ${#1} -eq 0 ]; then
        echo "Please specify the PID"
        return 1
    fi

    pid=${1}

    totalsize=0
    tmpfile=$(mktemp)
    procstat -v ${pid} | sed -e 1d -e '$d' > ${tmpfile}
    if [ ! ${?} -eq 0 ]; then
        rm ${tmpfile}
        return 1
    fi

    while read line; do
        begin=$(echo ${line} | awk '{print $2;}')
        end=$(echo ${line} | awk '{print $3;}')
        size=$((${end} - ${begin}))

        totalsize=$((${totalsize} + ${size}))
    done < ${tmpfile}
    rm ${tmpfile}

    echo ${totalsize}
}

function memusage_linux() {
    pid=${1}
    tmpfile=$(mktemp)

    (cat /proc/${pid}/maps | awk '{print $1;}') > ${tmpfile}
    if [ ! ${?} -eq 0 ]; then
        rm ${tmpfile}
        return 1
    fi

    totalsize=0
    while read line; do
        a=("${(s/-/)line}")
        begin=$(echo -n "0x" && echo ${a[1]})
        end=$(echo -n "0x" && echo ${a[2]})
        size=$(octave -q --eval "uint64(${end}) - uint64(${begin})" 2> /dev/null | awk '{print $3;}')

        totalsize=$((${totalsize} + ${size}))
    done < ${tmpfile}
    rm ${tmpfile}

    echo ${totalsize}
    echo "In memusage_linux, totalsize is: ${totalsize}" > /tmp/maps.txt
}

function memusage() {
    pid=${1}
    totalsize=0

    if [ ${#pid} -eq 0 ]; then
        echo "[-] Please specify the PID"
        return 1
    fi

    case "$(uname)" in
        FreeBSD)
            totalsize=$(memusage_fbsd ${pid})
            ;;
        Linux)
            echo "Warning: You need octave installed for Linux. This is slow." >&2
            totalsize=$(memusage_linux ${pid})
            ;;
        *)
            echo '[-] Your OS is not supported'
            return 1
            ;;
    esac

    echo "$(date '+%F %T') ${i}: ${totalsize} / $((${totalsize}/1024))KB / $((${totalsize}/1024/1024))MB"

    return 0
}
