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
    cflags="-g -O2"
    ldflags=""

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

        if [ -f config.status ]; then
            ${make} clean distclean
        fi
        CC=${clamcc} LDFLAGS=${ldflags} CFLAGS=${cflags} ./configure --disable-silent-rules --with-dbdir=/data/clamav/db/${dbdir} --disable-clamav --prefix=/data/clamav/install --enable-milter --enable-debug && \
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
