if [ "${clam}" = "" ]; then
    clam=${HOME}/clamav/clamav-devel
fi

alias sigtool='$(echo ${clam}/sigtool/sigtool)'
alias clamscan='$(echo ${clam}/clamscan/clamscan)'
alias clamd='$(echo ${clam}/clamd/clamd)'
alias clamdcscan='$(echo ${clam}/clamdscan/clamdscan)'
alias clamdtop='$(echo ${clam}/clamdtop/clamdtop)'
alias freshclam='$(echo ${clam}/freshclam/freshclam)'
alias dbtool='$(echo ${clam}/dbtool/dbtool)'

function buildclam() {
    (
        cd $clam

        if [ -f config.status ]; then
            gmake clean distclean
        fi
        autoreconf -fi && \
        CC=clang CFLAGS="-g -O0" ./configure --enable-debug --disable-silent-rules --with-dbdir=/data/clamav/db --disable-clamav && \
        gmake -j7 && \
        gmake check
    ) 2>&1 | tee /tmp/build.log
}
