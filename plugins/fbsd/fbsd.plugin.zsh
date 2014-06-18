if [ "${makejobs}" = "" ]; then
    makejobs=7
fi

# BE management
alias beupdate='/src/helpers/beupdate.sh -b $(date +%F_%T) -s'

# Package management
alias pkgv="pkg version '-vIl<'"
alias pkgup="sudo portmaster -awD --no-confirm"

# Kernel/world building
alias fbsdbuild="(cd /usr/src && make -sj${makejobs} buildworld buildkernel KERNCONF=SEC)"

# Snapshot a ZFS dataset.
function zsnap() {
    mydate=$(date '+%F_%T')

    for dataset in ${@}; do
        sudo zfs snapshot ${dataset}@${mydate}
        if [ ! ${?} -eq 0 ]; then
            echo "[-] Could not snapshot ${dataset}@${mydate}. Return value: ${?}"
            return 1
        fi
    done

    return 0
}

# Install a new kernel/world. Optional argument points DESTDIR to a new location. Enforce using the SEC kernel.
function fbsdinstall() {
    DESTDIR=/
    if [ ${#1} -gt 0 ]; then
        DESTDIR=${1}
    fi

    zsnap $(zfs get -H -o value name ${DESTDIR})
    if [ ! ${?} -eq 0 ]; then
        return 1
    fi

    (
        cd /usr/src
        if [ ! ${?} -eq 0 ]; then
            echo "[-] Could not change directory to the src tree"
            return 1
        fi

        sudo make -s installkernel KERNCONF=SEC DESTDIR=${DESTDIR}
        if [ ! ${?} -eq 0 ]; then
            echo "[-] Could not install the kernel to ${DESTDIR}"
            return 1
        fi

        sudo make -s installworld DESTDIR=${DESTDIR}
        if [ ! ${?} -eq 0 ]; then
            echo "[-] Could not install world to ${DESTDIR}"
            return 1
        fi
    )

    return 0
}

function _fbsd() {

}