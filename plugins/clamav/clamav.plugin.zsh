if [ "${clam}" = "" ]; then
    clam=${HOME}/clamav/clamav-devel
    clamcc="clang"
    clamcxx="clang++"
    clambase="/data/clamav"
    conf_freshclam="freshclam.conf"
    conf_clamd="clamd.conf"
    dbdir="0.98"

    clamtemps="no"
fi

# These aliases are now deprecated by the clamrun function below
alias sigtool='$(echo ${clam}/sigtool/sigtool)'
alias clamscan='$(echo ${clam}/clamscan/clamscan)'
alias clamd='$(echo ${clam}/clamd/clamd) --config-file=${clambase}/conf/${conf_clamd}'
alias clamdscan='$(echo ${clam}/clamdscan/clamdscan) --config-file=${clambase}/conf/${conf_clamd}'
alias clamdtop='$(echo ${clam}/clamdtop/clamdtop) --config-file=${clambase}/conf/${conf_clamd}'
alias freshclam='$(echo ${clam}/freshclam/freshclam) --config-file=${clambase}/conf/${conf_freshclam}'
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

    tempdir=$(clamtemp)

    if [ ${#tempdir} -eq 0 ]; then
        echo "[-] Could not create temporary directory"
        return 1
    fi

    leavetemps=""
    if [ ${clamtemps} = "yes" ]; then
        if [ ${origapp} = "clamscan" ]; then
            leavetemps="--leave-temps"
        fi
    fi

    LD_LIBRARY_PATH=${clam}/libclamav/.libs ${app} --tempdir=${tempdir} ${leavetemps} $*

    if [ ${clamtemps} = "yes" ]; then
        echo "[+] Leaving temporary files in ${tempdir}"
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
    cflags="${CFLAGS} -g -O0"
    ldflags="${LDFLAGS}"

    case $(uname) in
        Linux)
            make="make"
            ;;
    esac

    (
        cd $clam

        json=""
        if [ $(git branch | grep \* | awk '{print $2;}') = "master" ]; then
            json="--with-libjson"
        fi

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
            --enable-debug \
            ${json} && \
        ${make} -j7 && \
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

    if [ ! -f /data/clamav/scripts/quick_json.pl ]; then
        echo "The json script doesn't exist. Copy it to /data/clamav/scripts/quick_json.pl or die a slow death."
        return 1
    fi

    if [ ! -f ${file} ]; then
        echo "Yeah, so that file doesn't exist. What're you doing, idiot?"
        return 1
    fi

    (
        echo -n "LibClamAV Error: "
        cat ${file}
    ) | /data/clamav/scripts/quick_json.pl
}