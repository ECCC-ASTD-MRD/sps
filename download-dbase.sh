#!/bin/bash

set -e

SPS_DBASE="sps_dbase.tar.gz"
SPS_DBASE_URL="http://collaboration.cmc.ec.gc.ca/science/outgoing/goas/${SPS_DBASE}"
SPS_DBASE_MD5SUM="b539d0110dc02fa248d5af41e4d7e642"

printUsage() {
    echo -e "Download a sample database of data files needed to run SPS"
    echo -e "If a local database archive file is provided, use it instead"
    echo -e "Usage:"
    echo -e "./$(basename $0) <SPS-GIT-DIR> [Local SPS dbase archive path]\n"
    echo -e "Usually, SPS-GIT-DIR is the current directory, so use:"
    echo -e "./$(basename $0) ."
}

checkMd5() {
    # $1 File path
    # $2 Expected MD5
    # Return: 0 if matching; 1 otherwise
    md5=$(md5sum "$1" | cut -d' ' -f1)
    [[ "$md5" = "$2" ]]
}

if [[ ! -d "$1" ]]; then
    printUsage
    exit 1
fi

if [[ $# -eq 2 ]]; then
    if [[ ! -r "$2" ]]; then
        echo "Can't read ${2} !"
        exit 1
    else
        tarballPath="$2"
    fi
else
    tarballPath="${1}/${SPS_DBASE}"
    if [[ -x $(which wget) ]]; then
        wget ${SPS_DBASE_URL} -O "${tarballPath}";
    elif [[ -x $(which curl) ]]; then
        curl -o "${tarballPath}" ${SPS_DBASE_URL}
    else
        echo "Error: cannot download using wget or curl."
        echo "Please download database at: ${SPS_DBASE_URL}" 
        exit 1
    fi
fi

if checkMd5 "$tarballPath" "$SPS_DBASE_MD5SUM"; then
    echo "MD5 check OK"
else
    echo "The MD5 of $SPS_DBASE does not match what was expected.  The file might be corrupted."
    exit 1
fi

tar -xzvf ${tarballPath} -C "$1"
