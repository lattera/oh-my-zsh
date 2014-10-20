if [ "${clam}" = "" ]; then
    clam="${HOME}/clamav/clamav-devel"
    clamcc="clang"
    clamcxx="clang++"
    clambase="/data/clamav"
    conf_freshclam="freshclam.conf"
    conf_clamd="clamd.conf"
    dbdir="0.98"
    clamjson="yes"
    clamllvm="yes"
    clamyara="yes"
    clamcurl="yes"
    clamprefix=""

    clamtemps="no"
fi

lasttmpdir=""

# These aliases are now deprecated by the clamrun function below
alias sigtool='$(echo ${clam}/sigtool/sigtool)'
alias clamscan='$(echo ${clam}/clamscan/clamscan)'
alias clamdtop='$(echo ${clam}/clamdtop/clamdtop) --config-file=${clambase}/conf/${conf_clamd}'
alias dbtool='$(echo ${clam}/dbtool/dbtool)'
alias clamconf='$(echo ${clam}/clamconf/clamconf)'

function getclam() {
    app=${1}

    if [ ! -f ${clam}/${app}/.libs/${app} ]; then
        if [ ! -f ${clam}/${app}/${app} ]; then
            return 1
        fi

        echo ${clam}/${app}/${app}
    else
        echo ${clam}/${app}/.libs/${app}
    fi
}

function clamtemp() {
    date=$(date '+%F_%T')

    if [ ! -d /tmp/clamtemp ]; then
        mkdir /tmp/clamtemp || return 1
    fi

    dir=$(mktemp -d /tmp/clamtemp/${date}.XXXX)
    echo ${dir}
}

function clamrun() {
    origapp=${1}
    shift

    app=$(getclam ${origapp})
    if [ ${#app} -eq 0 ]; then
        echo "[-] Command not found."
        return 1
    fi

    tempdirarg=""
    case "${origapp}" in
        clamdscan)
            ;;
        clamd)
            ;;
        freshclam)
            ;;
        clamconf)
            ;;
        *)
            tempdir=$(clamtemp)
            if [ ${#tempdir} -eq 0 ]; then
                echo "[-] Could not create temporary directory"
                return 1
            fi
            tempdirarg="--tempdir=${tempdir}"
            ;;
    esac

    leavetemps=""
    if [ ${clamtemps} = "yes" ]; then
        if [ ${origapp} = "clamscan" ]; then
            leavetemps="--leave-temps"
        fi
    fi

    LD_LIBRARY_PATH=${clam}/libclamav/.libs ${app} ${tempdirarg} ${leavetemps} $*

    if [ ${clamtemps} = "yes" ]; then
        echo "[+] Leaving temporary files in ${tempdir}"
        lasttmpdir=${tempdir}
    else
        rm -rf ${tempdir}
    fi

    return ${?}
}

function prunejson() {
    tempdir=${1}

    if [ ${#tempdir} -eq 0 ]; then
        echo "[-] Please specify the directory"
        return 1
    fi

    find ${tempdir} -type d -name \*.tmp | xargs rm -rf

    for file in $(find ${tempdir} -type f); do
        grep -q JSON ${file} || rm -f ${file}
    done
}

function buildclam() {
    make="gmake"
    cflags="${CFLAGS} -g -O0 -Wall -fstack-protector -W -Wmissing-prototypes -Wmissing-declarations"
    ldflags="${LDFLAGS}"

    case $(uname) in
        Linux)
            make="make"
            ;;
    esac

    (
        set -e
        cd $clam

        json=""
        if [ ${clamjson} = "yes" ]; then
            if [ -d .git ]; then
                if [ $(git branch | grep \* | awk '{print $2;}') = "master" ]; then
                    json="--with-libjson"
                fi
            else
                case $(basename ${clam}) in
                    clamav-0.98.5*)
                        json="--with-libjson"
                        ;;
                esac
            fi
        fi

        llvm=""
        if [ ${clamllvm} = "no" ]; then
            llvm="--disable-llvm"
        fi

        curl=""
        if [ ${clamcurl} = "no" ]; then
            curl="--with-libcurl=/tmp/nonexistentdir"
        fi

        prefix=""
        if [ ${#clamprefix} -gt 0 ]; then
            prefix="--prefix=${clamprefix}"
        fi

        yara="--enable-yara=${clamyara}"

        if [ -f config.status ]; then
            ${make} clean distclean
        fi

        CC=${clamcc} \
        CXX=${clamcxx} \
        LDFLAGS=${ldflags} \
        CFLAGS=${cflags} \
        ./configure \
            --disable-silent-rules \
            --with-dbdir=/data/clamav/db/${dbdir} \
            --disable-clamav \
            --enable-milter \
            --prefix=${clam}/../install \
            --enable-debug \
            ${json} \
            ${yara} \
            ${curl} \
            ${prefix} \
            ${llvm}
        ${make} -j7
        ${make} check
    ) 2>&1 | tee /tmp/build.log
}

function vg() {
    app=${1}
    shift

    app=$(getclam ${app})
    if [ ${#app} = 0 ]; then
        echo "${app} not found."
        return 1
    fi

    logfile=$(mktemp)

    echo "[*] Logging to ${logfile}"

    LD_LIBRARY_PATH=$clam/libclamav/.libs /usr/bin/time -h valgrind \
        --verbose \
        --track-fds=yes \
        --log-file=${logfile} \
        --read-var-info=yes \
        --leak-check=full \
        --track-origins=yes \
        ${app} $*
}

function debugclam() {
    app=${1}
    shift

    app=$(getclam ${app})
    if [ ${#app} = 0 ]; then
        echo "${app} not found."
        return 1
    fi

    LD_LIBRARY_PATH=${clam}/libclamav/.libs \
        gdb ${app} \
        $*

    return ${?}
}

function showjson() {
    file=${1}

    if [ ! -x /data/clamav/scripts/quick_json.pl ]; then
        chmod u+x ${ZSH}/plugins/clamav/quick_json.pl
    fi

    if [ ! -f ${file} ]; then
        echo "Yeah, so that file doesn't exist. What're you doing, idiot?"
        return 1
    fi

    (
        echo -n "LibClamAV Error: "
        cat ${file}
    ) | ${ZSH}/plugins/clamav/quick_json.pl
}

function cleanclamdir() {
    foreach file in $(git status --porcelain -uall | grep -F '??' | awk '{print $2;}'); do
        rm -rf ${file}
    done
}

function freshclam() {
    config=${1}

    if [ ${#config} -eq 0 ]; then
        config="${clambase}/conf/${conf_freshclam}"
    fi

    clamrun freshclam --config-file=${config}
}

function clamd() {
    config=${1}

    if [ ${#config} -eq 0 ]; then
        config="${clambase}/conf/${conf_clamd}"
    else
        shift
    fi

    clamrun clamd --config-file=${config} $*
}

function clamdscan() {
    config="${clambase}/conf/${conf_clamd}"
    clamrun clamdscan --config-file=${config} $*
}

function perftest() {
    # Run performance tests against clamscan
    #
    # This will pass any special options you have to clamscan,
    # but will specify the samples used in our unit tests for
    # scanning. The performance test is run with caching
    # disabled.
    #
    # By default, 20 scans will be run. You can override that
    # by setting the environment variable PERFRUNS to a
    # different value.

    tmpfile=$(mktemp)

    nruns=${PERFRUNS}
    if [ ${#nruns} -eq 0 ]; then
        nruns=20
    fi

    totaltime=0.0
    mintime=0.0
    maxtime=0.0

    j=0
    for ((i=0; i < ${nruns}; i++)); do
        echo "[*] $(date '+%F %T'): Executing run $((${i} + 1)) out of ${nruns}" >&2

        clamrun clamscan --disable-cache --dev-performance ${*} ${clam}/clam* 2>&1 | grep "LibClamAV info: performance:" > ${tmpfile}

        while read line; do
            j=$((${j} + 1))
            perf=$(echo ${line} | awk '{print $6;}' | sed -e 's/ms,//')

            if (( ${mintime} == 0 )) || (( ${perf} < ${mintime} )); then
                mintime=${perf}
            fi

            if (( ${perf} > ${maxtime} )); then
                maxtime=${perf}
            fi

            totaltime=$((${totaltime} + ${perf}))
        done < ${tmpfile}
    done
    rm ${tmpfile}

    averagetime=$((${totaltime} / ${j}))

    echo "Note: Times are in miliseconds" >&2
    printf "Tot: %.03f\n" ${totaltime}
    printf "Avg: %.03f\n" ${averagetime}
    printf "Min: %.03f\n" ${mintime}
    printf "Max: %.03f\n" ${maxtime}
}

function vt_innerfiles() {
    pluginfound=0
    foreach plugin in ${plugins}; do
        if [ ${plugin} = "virustotal" ]; then
            pluginfound=1
        fi
    done

    if [ ${pluginfound} -eq 0 ]; then
        echo "[-] The virustotal oh-my-zsh plugin hasn't been loaded. Please load it."
        return 1
    fi

    if [ ${#vtapikey} -eq 0 ]; then
        echo "[-] Please set vtapikey"
        return 1
    fi

    clamtemps="yes" clamrun clamscan ${*}

    isMalware ${lasttmpdir}
    res=${?}

    return ${res}
}

function set_clam() {
    myclam=${1}
    if [ ${#myclam} -eq 0 ]; then
        echo "USAGE: ${0} [clam|full_path]"
        return 1
    fi

    if [ "${myclam[1]}" != "/" ]; then
        myclam="${HOME}/clamav/${myclam}"
    fi

    if [ ! -d ${myclam} ]; then
        echo "${myclam} does not exist."
        return 1
    fi

    clam="${myclam}"
    cd ${clam}
    return ${?}
}
