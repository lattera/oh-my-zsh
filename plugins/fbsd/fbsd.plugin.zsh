if [ "${makejobs}" = "" ]; then
    makejobs=7
    kernel="LATT-ASLR"
fi

function buildfreebsd() {
    (
        set -e

        echo "==== $(date '+%F %T') building world and kernel ===="

        cd /usr/src
        make -sj${makejobs} buildworld buildkernel KERNCONF=${kernel}
    ) 2>&1 | tee /tmp/build.log

    return ${?}
}

function buildrelease() {
    version=${1}
    if [ ${#version} -eq 0 ]; then
        echo "[-] Please specify the version"
        return 1
    fi

    (
        set -e

        buildfreebsd
        cd /usr/src/release
        sudo make clean || true # I don't care if this fails
        echo "==== $(date '+%F %T') building release ===="
        sudo make -s release KERNCONF=${kernel}
        echo "==== $(date '+%F %T') copying release ===="
        sudo cp /usr/obj/usr/src/release/*.{iso,txz} /src/release/pub/FreeBSD/snapshots/amd64/amd64/${version}
    ) 2>&1 | tee /tmp/build.log

    return ${?}
}
