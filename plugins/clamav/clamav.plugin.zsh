if [ "${clam}" = "" ]; then
    clam=${HOME}/clamav/clamav-devel
    clamcc="clang"
    clambase="/data/clamav"
    conf_freshclam="freshclam.conf"
    conf_clamd="clamd.conf"
    dbdir="0.98"
fi

alias sigtool='$(echo ${clam}/sigtool/sigtool)'
alias clamscan='$(echo ${clam}/clamscan/clamscan)'
alias clamd='$(echo ${clam}/clamd/clamd) --config-file=${clambase}/conf/${conf_clamd}'
alias clamdscan='$(echo ${clam}/clamdscan/clamdscan) --config-file=${clambase}/conf/${conf_clamd}'
alias clamdtop='$(echo ${clam}/clamdtop/clamdtop) --config-file=${clambase}/conf/${conf_clamd}'
alias freshclam='$(echo ${clam}/freshclam/freshclam) --config-file=${clambase}/conf/${conf_freshclam}'
alias dbtool='$(echo ${clam}/dbtool/dbtool)'
alias clamconf='$(echo ${clam}/clamconf/clamconf)'

function buildclam() {
    make="gmake"
    cflags="${CFLAGS} -g -O0"
    ldflags="${LDFLAGS}"

    case $(uname) in
        Linux)
            make="make"
            ;;
        FreeBSD)
            cflags="${cflags} -fPIE"
            ldflags="${ldflags} -pie"
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
    logfile=$(mktemp)

    echo "[*] Logging to ${logfile}"

    LD_LIBRARY_PATH=$clam/libclamav/.libs /usr/bin/time -h valgrind \
        --verbose \
        --track-fds=yes \
        --log-file=${logfile} \
        --read-var-info=yes \
        --leak-check=full \
        --track-origins=yes \
        $*
}

function debugclam() {
    app=${1}
    shift

    if [ ! -f ${clam}/${app}/.libs/${app} ]; then
        if [ ! -f ${clam}/${app}/${app} ]; then
            echo "You need to compile ClamAV first, dimwit."
            return 1
        fi

        app=${clam}/${app}/${app}
    else
        app=${clam}/${app}/.libs/${app}
    fi

    LD_LIBRARY_PATH=${clam}/libclamav/.libs \
        gdb ${app} \
        $*
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
