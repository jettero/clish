#!/bin/bash

# export PS4="[1;32m....oO: [m"; set -x
# trap "echo \"ERROR(\$?) at \$0 line \${LINENO}\"; sleep 1" ERR
# trap "exit 1" SIGINT # fucking die when I fucking say
# tmp=$(mktemp); trap "rm -f ${tmp:-/tmp/oops}; exit" 0 1 2 5 15

declare -A options # # ${options[something]} {{{
declare -A optspeco  # options
declare -A optspeca  # options with args


optspeco[h]="this help"


optspec=""
for o in ${!optspeca[@]}; do optspec+=$o:; done
for o in ${!optspeco[@]}; do optspec+=$o ; done

function help() {
    e=$1
    [ -z "$e" ] || echo
    echo "$(basename $0) [opt]"

    spaces=""
    if [ ${#optspeca[@]} -gt 0 ]; then
        for o in ${!optspeca[@]}; do
            echo "  -$o arg  ${optspeca[$o]}"
        done
        spaces="    "
    fi

    if [ ${#optspeco[@]} -gt 0 ]; then
        for o in ${!optspeco[@]}; do
            echo "  -$o$indent  ${optspeco[$o]}"
        done
    fi

    exit ${e:-0}
}

dieafter=0
while getopts "$optspec" _o; do
    [ $? -gt 0 ] && dieafter=1 # happens when argument to (eg f:) is not given
    case "$_o" in
        h) help ;;
       \?) dieafter=1 ;; # given an arg that doesn't exist
        *) options[$_o]=${OPTARG:-1} ;;
    esac
done
[ $dieafter -gt 0 ] && help 1

# }}}

PERL="${THIS_PERL:-perl}"
HERE="$(dirname $0)"
PROC=$(grep bogo /proc/cpuinfo | wc -l)

cd "$HERE" || exit 1

if [ ! -f Makefile -o Makefile.PL -nt Makefile ]; then
    REQMOD_YES=1 PERL_MM_USE_DEFAULT=1 "$PERL" Makefile.PL
fi

make -j $PROC

"$PERL" -Iblib/{arch,arch} example/myshell.pl
