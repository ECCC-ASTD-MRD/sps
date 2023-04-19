#!/bin/bash

# link to database at CMC

DOMAIN=`hostname -d`

if [[ "${DOMAIN}"  = cmc.ec.gc.ca ]]; then
    SPS_DBASE=/users/dor/armn/sps/SPS_MODEL_DFILES
    [ -e ${SPS_DBASE} ] && [ ! -e sps_dbase ] && ln -sf ${SPS_DBASE} sps_dbase
elif [[ ${DOMAIN} = "collab.science.gc.ca" ]]; then
    SPS_DBASE=/space/hall0/work/eccc/mrd/rpnenv/smsh001
    [ -e ${SPS_DBASE} ] && [ ! -e sps_dbase ] && ln -sf ${SPS_DBASE} sps_dbase
elif [[ -z "${DOMAIN}" || ${DOMAIN} = "science.gc.ca" ]]; then
    SPS_DBASE=/home/ssps121/SPS_MODEL_DFILES
    [ -e ${SPS_DBASE} ] && [ ! -e sps_dbase ] && ln -sf ${SPS_DBASE} sps_dbase
else
    echo "hostname not found: don't know where database is."
fi
