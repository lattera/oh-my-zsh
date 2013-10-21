if [ "${clam}" = "" ]; then
    clam=${HOME}/clamav/clamav-devel
    clamconfig=/data/clamav/conf/clamav.conf
    clamcc="clang"
fi

alias sigtool='$(echo ${clam}/sigtool/sigtool) --config=${clamconfig}'
alias clamscan='$(echo ${clam}/clamscan/clamscan) --config=${clamconfig}'
alias clamd='$(echo ${clam}/clamd/clamd) --config=${clamconfig}'
alias clamdscan='$(echo ${clam}/clamdscan/clamdscan) --config=${clamconfig}'
alias clamdtop='$(echo ${clam}/clamdtop/clamdtop) --config=${clamconfig}'
alias freshclam='$(echo ${clam}/freshclam/freshclam) --config=${clamconfig}'
alias dbtool='$(echo ${clam}/dbtool/dbtool) --config=${clamconfig}'
alias clamconf='$(echo ${clam}/clamconf/clamconf) --config=${clamconfig}'

function buildclam() {
    make="gmake"
    cflags="-g -O2"
    ldflags=""

    if [ $(uname) = "Linux" ]; then
        make="make"
    fi

    (
        cd $clam

        if [ -f config.status ]; then
            ${make} clean distclean
        fi
        autoreconf -fi && \
        CC=${clamcc} LDFLAGS=${ldflags} CFLAGS=${cflags} ./configure --disable-silent-rules --with-dbdir=/data/clamav/db --disable-clamav --prefix=/data/clamav/install --enable-milter --enable-debug && \
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
