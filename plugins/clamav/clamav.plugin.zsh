if [ "${clam}" = "" ]; then
    clam=${HOME}/clamav/clamav-devel
fi

alias sigtool='$(echo ${clam}/sigtool/sigtool)'
alias clamscan='$(echo ${clam}/clamscan/clamscan)'
alias clamd='$(echo ${clam}/clamd/clamd)'
alias clamdcscan='$(echo ${clam}/clamdscan/clamdscan)'
alias clamdtop='$(echo ${clam}/clamdtop/clamdtop)'
