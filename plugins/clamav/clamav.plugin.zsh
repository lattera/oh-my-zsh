if [ "${clam}" = "" ]; then
    clam=${HOME}/clamav/clamav-devel
    clamconfig=/data/clamav/conf/clamav.conf
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
    (
        cd $clam

        if [ -f config.status ]; then
            gmake clean distclean
        fi
        autoreconf -fi && \
        CC=clang LDFLAGS="-v" CFLAGS="-g -O0" ./configure --enable-debug --disable-silent-rules --with-dbdir=/data/clamav/db --disable-clamav --prefix=/data/clamav/install --enable-milter && \
        gmake -j7 && \
        gmake check
    ) 2>&1 | tee /tmp/build.log
}

function vg() {
    logfile=$(mktemp)

    echo "[*] Logging to ${logfile}"

    LD_LIBRARY_PATH=$clam/libclamav/.libs valgrind \
        --verbose \
        --track-fds=yes \
        --log-file=${logfile} \
        --read-var-info=yes \
        --leak-check=full \
        --track-origins=yes \
        $*
}
