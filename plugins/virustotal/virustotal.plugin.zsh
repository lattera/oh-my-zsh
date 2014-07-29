if [ ${#vtapikey} -eq 0 ]; then
    vtapikey=""

    vtreporturl="https://www.virustotal.com/vtapi/v2/file/report"
fi

function vtlookup() {
    fhash=${1}
    output=${2}

    if [ ${#vtapikey} -eq 0 ]; then
        echo "[-] Please set the vtapikey variable"
        return 1
    fi

    if [ ${#fhash} -eq 0 ]; then
        echo "[-] Please specify the hash"
        return 1
    fi

    if [ ${#output} -eq 0 ]; then
        echo "[-] Please specify the output file"
        return 1
    fi

    curl -F "resource=${fhash}" -F "apikey=${vtapikey}" -o ${output} ${vtreporturl} 2> /dev/null
    res=${?}
    if [ ! ${res} -eq 0 ]; then
        echo "[-] curl failed"
    fi

    return ${res}
}

# Non-zero return code means error or clean
# Zero return code means malware
function isMalware_ByHash() {
    fhash=${1}

    if [ ${#fhash} -eq 0 ]; then
        echo "[-] Please specify the file's hash"
        return 1
    fi

    outfile=$(mktemp)
    res=${?}
    if [ ${?} -gt 0 ]; then
        echo "[-] Could not generate a temporary file"
        return 1
    fi

    output=$(vtlookup ${fhash} ${outfile})
    res=${?}
    if [ ! ${res} -eq 0 ]; then
        echo "[-] vtlookup failed"
        rm ${outfile}
        return 1
    fi

    fsize=$(wc -c ${outfile} | awk '{print $1;}')
    if [ $((${fsize})) -eq 0 ]; then
        rm ${outfile}
        return 1
    fi

    ret=$(cat ${outfile} | jshon -e positives 2> /dev/null);
    res=${?}
    if [ ! ${res} -eq 0 ]; then
        rm ${outfile}
        return 1
    fi

    rm ${outfile}
    if [ ${#ret} -eq 0 ] || [ $((${ret})) -eq 0 ]; then
        return 1
    fi

    return 0
}

function isMalware_ByFile() {
    file=${1}

    if [ ${#file} -eq 0 ]; then
        echo "[-] Please specify the file"
        return 0
    fi

    fhash=$(sha256 -q ${file})
    res=${?}
    if [ ${res} -gt 0 ]; then
        echo "[-] Could not get the file's hash"
        return 0
    fi

    isMalware_ByHash ${fhash}
    return ${?}
}

function isMalware_ByDirectory() {
    dir=${1}

    if [ ${#dir} -eq 0 ]; then
        echo "[-] Please specify the directory"
        return 0
    fi

    tmpfile=$(mktemp)

    find ${dir} -type f > ${tmpfile} 2> /dev/null
    if [ ! ${?} -eq 0 ]; then
        echo "[-] Could not run find"
        rm ${tmpfile}
        return 0
    fi

    while read line; do
        isMalware_ByFile ${line}
        if [ ${?} -eq 0 ]; then
            echo "FOUND: ${line}"
            rm ${tmpfile}
            return 0
        fi
    done < ${tmpfile}

    return 1
}

function isHash() {
    input=${1}
    inputsz=${#input}
    sizes=(32 40 64)

    if [ ${inputsz} -eq 0 ] || [ $((${inputsz} % 2)) -eq 1 ] ; then
        return 1
    fi

    res=$(expr "${input}" : '[a-f0-9]\{2,64\}')

    if [ $((${res})) -eq ${inputsz} ]; then
        foreach size in ${sizes}; do
            if [ $((${size})) -eq ${inputsz} ]; then
                return 0
            fi
        done
    fi

    return 1
}

function isMalware() {
    arg=${1}

    if [ ${#arg} -eq 0 ]; then
        echo "[-] Argument (hash or filepath) required"
        return 1
    fi

    isHash ${arg}
    if [ ${?} -eq 0 ]; then
        isMalware_ByHash ${arg}
        return ${?}
    fi

    if [ -d ${arg} ]; then
        isMalware_ByDirectory ${arg}
        return ${?}
    fi

    isMalware_ByFile ${arg}
    return ${?}
}
