if [[ x${SEQ_MAESTRO_VERSION} == x ]] ; then
   if [[ x$(echo $CMCLNG | cut -c1-2) == xfr ]] ; then
	 cat<<EOF
============================================================================
ERREUR: Vous essayez de charger SPS sans MAESTRO dans votre environnement.
        SVP charger une version de MAESTRO avant de recharger SPS
============================================================================
EOF
   else
	 cat<<EOF
============================================================================
ERROR: You are trying to load SPS without MAESTRO in your ENV.
       Please load a MAESTRO version before reloading SPS
============================================================================
EOF
   fi
   return 111
fi
