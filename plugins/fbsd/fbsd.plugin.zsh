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

function findpid() {
    app=${1}
    pattern=${2}

    if [ ${#app} -eq 0 ]; then
        return 0
    fi

    if [ ${#pattern} -eq 0 ]; then
        return 0
    fi

    foreach i in $(pgrep ${app}); do
        ps -o command ${i} | sed 1d | grep -q ${pattern}
        if [ ${?} -eq 0 ]; then
            echo ${i}
            return ${i}
        fi
    done

    return 0
}

function killimap() {
    timeout=30

    pid=$(findpid python offlineimap)
    pid=$((${pid} + 0))

    if [ ${pid} -gt 0 ]; then
        kill -TERM ${pid}

        for ((i=0; i < ${timeout}; i++)); do
            newpid=$(findpid python offlineimap)
            if [ $((${newpid} + 0)) -eq 0 ]; then
                return 0
            fi

            sleep 1
        done
        kill -KILL ${pid}
    fi

    return 0
}
