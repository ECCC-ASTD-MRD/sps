#!/bin/ksh
myself=${0##*/}
model_name=sps
MODEL_NAME="$(echo ${model_name} | tr 'a-z' 'A-Z')"
DESC="SetUp and Launch script for the Surface Process Model [${MODEL_NAME}]"
USAGE="USAGE: ${myself##*/} [-h] [-v LEVEL] [--ptopo {NPEX}x{NPEY}x{NOMP}] [--btopo {NPEX}x{NPEY}] [--intopo {NPEX}x{NPEY}] [--cfg 0:N] [--dircfg ${MODEL_NAME}_cfgs] [--postclean] [--restart] [--nompi] [--dryrun] [--inorder] [--gdb] [--timeout TIMEOUT]"

usage_long() {
         toto=$(echo -e $USAGE)
         cat <<EOF
============================================================
$DESC

$toto

Options:
    -h, --help
       print this help
    -v, --verbosity
        set verbosity level [debug, plusinfo, info, warning, error, critical]
        default=info
    --ptopo 
        Define processor topology, format {NPEX}x{NPEY}x{NOMP}
        default=1x1x1
    --btopo
        Define blocking processor topology (used in output), format {NPEX}x{NPEY}
        default=ptopo
    --intopo
        Define blocking processor topology (used in input), format {NPEX}x{NPEY}
        default=btopo
    --dircfg
        Dirname where domains config files are located
        default=${MODEL_NAME}_cfgs
    --cfg
        Range of config/domains to run, format 0:0
        default=0:0
    --postclean 
        Erase working dir after run
    --restart
        Restart mode, do not clean workdir before the run
    --nompi
        Run the No-MPI version
    --inorder
        List stdout/stderr of members in process order
    --gdb
        Run in debugger
    --preexec 
        Prefix program execution with this (time/gdb/...)
    --timeout 
        Max number of seconds between steps in the model run
    -n, --dryrun
        Do not run the model, only perform init steps (task_setup,...)
============================================================
EOF
}


#==== Parse inline options
verbosity=info
postclean=0
restart=0
previous=""
ptopo="1x1x1"
btopo=""
intopo=""
dircfg="${MODEL_NAME}_cfgs"
cfg="0:0"
binMPIext=Abs
dryrun=0
ngrids=1 #TODO: for yinyang grid, ngrids=2
nompi=""
inorder=""
debug=""
preexec=""
timeout=""
while [[ $# -gt 0 ]] ; do
   case $1 in
      (-h|--help) usage_long ; exit 0;;
      (-v|--verbosity) verbosity=plus ;;
      (--verbosity=*) verbosity=${1##*=} ;;
      (--postclean) postclean=1 ;;
      (--restart) restart=1 ;;
      (--ptopo) ptopo="1x1x1" ;;
      (--ptopo=*) ptopo="${1##*=}" ;;
      (--btopo) btopo="$ptopo" ;;
      (--btopo=*) btopo="${1##*=}" ;;
      (--intopo) intopo="$intopo" ;;
      (--intopo=*) intopo="${1##*=}" ;;
      (--dircfg) ;;
      (--dircfg=*) dircfg="${1##*=}";;
      (--timeout) ;;
      (--timeout=*) timeout="${1##*=}";;
      (--cfg) ;;
      (--cfg=*) cfg="${1##*=}";;
      (--nompi) binMPIext="Abs" ; nompi='-nompi';;
      (--inorder) inorder="-inorder -tag" ;;
      (--gdb) debug="-gdb";;
      (--preexec=*) preexec="-preexec '${1##*=}'";;
      (--preexec) ;;
      (-n|--dryrun) dryrun=1 ;;
      (-*) echo "Error: unknown option '$1'"; 
           echo $USAGE
           exit 1;;
      *) [[ x"$previous" == x"-v" ]] && verbosity=$1;
         [[ x"$previous" == x"--verbosity" ]] && verbosity=$1 ;
         [[ x"$previous" == x"--ptopo" ]] && ptopo=$1;
         [[ x"$previous" == x"--btopo" ]] && btopo=$1 ;
         [[ x"$previous" == x"--intopo" ]] && intopo=$1 ;
         [[ x"$previous" == x"--dircfg" ]] && dircfg=$1 ;
         [[ x"$previous" == x"--cfg" ]] && cfg=$1 ;
         [[ x"$previous" == x"--timeout" ]] && timeout=$1 ;
         [[ x"$previous" == x"--preexec" ]] && preexec="-preexec '${1}'" ;;
   esac
   previous=$1
   shift
done

if [[ x$dircfg == x || ! -d $dircfg ]] ; then
   echo "Error: dircfg Not Found: $dircfg"
   echo $USAGE
   exit 1
fi

npex=$(echo $ptopo | cut -dx -f1) ; [[ x$npex == x ]] && npex=1
npey=$(echo $ptopo | cut -dx -f2) ; [[ x$npey == x ]] && npey=1
nomp=$(echo $ptopo | cut -dx -f3) ; [[ x$nomp == x ]] && nomp=1
ptopo=${npex}x${npey}x${nomp}
if [[ x$btopo != x ]] ; then
   nblx=$(echo $btopo | cut -dx -f1) ; [[ x$nblx == x ]] && nblx=1
   nbly=$(echo $btopo | cut -dx -f2) ; [[ x$nbly == x ]] && nbly=1
else
	nblx=${npex}
   nbly=${npey}
fi
btopo=${nblx}x${nbly}
if [[ x$intopo != x ]] ; then
   ninblx=$(echo $intopo | cut -dx -f1) ; [[ x$ninblx == x ]] && ninblx=1
   ninbly=$(echo $intopo | cut -dx -f2) ; [[ x$ninbly == x ]] && ninbly=1
else
	ninblx=${nblx}
   ninbly=${nbly}
fi
intopo=${ninblx}x${ninbly}



#==== Define Basic var
#TODO: make sure to use basedir in run_basedir (many concurent exp) ${PWD##*/}
config_basedir=$(pwd)/$dircfg
myexpname=${PWD##*/}
run_basedir_name=RUNMOD_${ORDENV_PLAT}
export model_cfg_filename=${model_name}.cfg
export model_tsk_file=${TMPDIR}/${model_name}.tsk
export model_incdir=${sps}/include
export model_exp_storage=$(true_path ${PWD}/${run_basedir_name})
if [[ x$model_exp_storage == x ]] ; then 
   cat <<EOF
ERROR: RUNDIR does not exists:
       ${PWD}/${run_basedir_name}
       Try running 'sps-linkit' then launching SPS (sps.ksh) again
EOF
   exit 1
fi

#==== Abs Search script
find_sps_bin() {
   _UM_EXEC_ovbin=$1
   _UM_EXEC_Abs=$2
   model_abs_basename=${model_name}_${BASE_ARCH}
   
   if [[ x$_UM_EXEC_Abs == x ]] ; then
      if [[ x$_UM_EXEC_ovbin != x ]] ; then
         export _UM_EXEC_Abs=${_UM_EXEC_ovbin}/${model_abs_basename}.${binMPIext}
      else
         export _UM_EXEC_Abs=$(pwd)/${model_abs_basename}.${binMPIext}
         [[ ! -x $_UM_EXEC_Abs ]] && _UM_EXEC_Abs=$(pwd)/malib${EC_ARCH}/${model_abs_basename}.${binMPIext}
         [[ ! -x $_UM_EXEC_Abs ]] && _UM_EXEC_Abs=$(pwd)/${EC_ARCH}/build/${model_abs_basename}.${binMPIext}
         [[ ! -x $_UM_EXEC_Abs ]] && _UM_EXEC_Abs=$(pwd)/build/${EC_ARCH}/${model_abs_basename}.${binMPIext}
         [[ ! -x $_UM_EXEC_Abs ]] && _UM_EXEC_Abs=$(pwd)/build-${ORDENV_PLAT}/bin/${model_abs_basename}.${binMPIext}
         [[ ! -x $_UM_EXEC_Abs ]] && _UM_EXEC_Abs=$(pwd)/build-${ORDENV_PLAT}/bin/${COMP_ARCH}/${model_abs_basename}.${binMPIext}
         [[ ! -x $_UM_EXEC_Abs ]] && _UM_EXEC_Abs=$(pwd)/build-${ORDENV_PLAT}/bin/*/${model_abs_basename}.${binMPIext}
      fi
   fi

   if [[ ! -x $_UM_EXEC_Abs ]] ; then
      export UM_EXEC_Abs=''
      export UM_EXEC_ovbin=''
      cat <<EOF
ERROR: Executable not found: ${model_abs_basename}.${binMPIext}
==== Abort ====
EOF
      exit 1
   fi
   export UM_EXEC_Abs=${_UM_EXEC_Abs}
   export UM_EXEC_ovbin=${_UM_EXEC_Abs%/*}
#    cat <<EOF
# echo #Executable found at: \n
# echo $(ls -l $UM_EXEC_Abs) \n
# echo $(ls -lL $UM_EXEC_Abs) \n
# EOF
}


#==== Task config file Setup scripts
int4digits() {
   __int=$1
   __int2=$1
   [[ $__int -lt 1000 ]] && __int2=0$__int
   [[ $__int -lt 100 ]] && __int2=00$__int
   [[ $__int -lt 10 ]] && __int2=000$__int
   echo $__int2
}

prep_model_cfg() {
   __cfg_file0=$1
   __cfg_file1=$2
   __NPEX=$3
   __NPEY=$4
   __NBLOCX=$5
   __NBLOCY=$6
   __NINBLOCX=$7
   __NINBLOCY=$8
   cp ${__cfg_file0} ${__cfg_file1}
   cat >> ${__cfg_file1} <<EOF

@ptopo_cfgs
npx = ${__NPEX:-1}
npy = ${__NPEY:-1}
nblocx = $__NBLOCX
nblocy = $__NBLOCY
ninblocx = ${__NINBLOCX:-${__NBLOCX}}
ninblocy = ${__NINBLOCY:-${__NBLOCX}}
@

EOF
}

set_tsk_init() {
   __tsk_file=$1
   cat > ${__tsk_file} <<EOF
# Variable Declaration Section
MODEL_NAME=${model_name}
# Task Setup Instruction Section
#############################################
# <input>
EOF
}

set_tsk_cfg() {
   __tsk_file=$1
   __cfg_id=$2
   __cfg_dir=$3
   __cfg_file=$4
   __inc_dir=$5
   . ${__cfg_dir}/configexp.cfg
   export UM_EXEC_Abs=${UM_EXEC_Abs:-""}
   export UM_EXEC_ovbin=${UM_EXEC_ovbin:-""}
   __dict_dir=${__inc_dir}
   if [[ -f ${__cfg_dir}/${model_name}.dict ]] ; then
      __dict_dir=${__cfg_dir}
   fi
   find_sps_bin "$UM_EXEC_ovbin" "$UM_EXEC_Abs"
   #TODO: geophy and inrep should link individual files not the dir
   cat >> ${__tsk_file} <<EOF
# cfg_${__cfg_id}/CLIMATO					${UM_EXEC_climato}
# cfg_${__cfg_id}/GEOPHY			 		${UM_EXEC_geophy}
# cfg_${__cfg_id}/ANALYSIS		 			${UM_EXEC_anal}
# cfg_${__cfg_id}/INREP			 			${UM_EXEC_inrep}
# cfg_${__cfg_id}/ozone_clim.fst				${UM_EXEC_ozone}
# cfg_${__cfg_id}/configexp.cfg			${__cfg_dir}/configexp.cfg
# cfg_${__cfg_id}/${model_name}.cfg		${__cfg_file}
# cfg_${__cfg_id}/${model_name}.dict   ${__dict_dir}/\${MODEL_NAME}.dict
# cfg_${__cfg_id}/outcfg.out	 			${__cfg_dir}/outcfg.out
# cfg_${__cfg_id}/dyn_input_table		${SPS_dyn_intable:-${__inc_dir}/dyn_input_table}
# cfg_${__cfg_id}/physics_input_table	${SPS_phy_intable:-${__inc_dir}/physics_input_table}
EOF
   if [[ -f ${__cfg_dir}/tape1 ]] ; then
       cat >> ${__tsk_file} <<EOF
# cfg_${__cfg_id}/tape1 ${__cfg_dir}/tape1
EOF
   fi
   echo "${UM_EXEC_Abs}:${UM_EXEC_ovbin}"
}

set_tsk_final() {
   __tsk_file=$1
   cat >> ${__tsk_file} <<EOF
# </input>
# <executables>
# ${model_name}.Abs \${UM_EXEC_Abs}
# </executables>
# <output>
# </output>
#############################################
EOF
}

set_tsk() {
   export __tsk_file=$1
   MPI_DOMS=$2
   MPI_NGRIDS=$3
   MPI_NPEX=$4
   MPI_NPEY=$5
   MPI_NBLOCX=${6:-$MPI_NPEX}
   MPI_NBLOCY=${7:-$MPI_NPEY}
   MPI_NINBLOCX=${8:-$MPI_NBLOCX}
   MPI_NINBLOCY=${9:-$MPI_NBLOCY}
   set_tsk_init ${model_tsk_file}
   dom0=${MPI_DOMS%%:*}
   domN=${MPI_DOMS##*:}
   ndoms=0
   ngrids=-1
   if [[ ! -d ${model_exp_storage} ]] ; then
      mkdir -p ${model_exp_storage} 2>/dev/null || true
   fi
   while [[ $dom0 -le $domN ]] ; do
      cfgid=$(int4digits $dom0)
      if [[ ! -d ${config_basedir}/cfg_${cfgid} ]] ; then
         echo "# ERROR: config dir Not found: ${config_basedir}/cfg_${cfgid}" 1>&2
         export ndomsngrids=0
         return 1
      fi
      echo "# Setting up config: ${config_basedir}/cfg_${cfgid}" 1>&2
      export cfgdir=${config_basedir}/cfg_${cfgid}
      export cfgfile0=${cfgdir}/${model_cfg_filename}
      export cfgfile1=${model_exp_storage}/${model_cfg_filename}_${cfgid}
      prep_model_cfg ${cfgfile0} ${cfgfile1} $MPI_NPEX $MPI_NPEY $MPI_NBLOCX $MPI_NBLOCY $MPI_NINBLOCX $MPI_NINBLOCY
      UM_EXEC_Abs_ovbin=$(set_tsk_cfg ${__tsk_file} ${cfgid} ${cfgdir} ${cfgfile1} ${model_incdir})
      ((dom0 = dom0 + 1 ))
      ((ndoms = ndoms + 1 ))
      isyygrid="$(cat $cfgfile0 | grep Grd_typ_S | grep -i GY)"
      ngrid0=1
      [[ x"$isyygrid" != x"" ]] && ngrid0=2
      if [[ x$ngrids == x-1 ]] ; then
         ngrids=$ngrid0
      elif [[ x$ngrids != x$ngrid0 ]] ; then
         echo "# ERROR: all domains should be YY grid or none of them" 1>&2
         export ndomsngrids=-1
         ngrids=-1
         return 1
      fi
   done
   set_tsk_final ${model_tsk_file}
   export ndomsngrids=${ndoms}:${ngrids}
   export UM_EXEC_Abs=${UM_EXEC_Abs_ovbin%:*}
   export UM_EXEC_ovbin=${UM_EXEC_Abs_ovbin#*:}
}


#==== Exit Status check
set_status() {
   MPI_DOMS=$1
   dom0=${MPI_DOMS%%:*}
   domN=${MPI_DOMS##*:}
   ndoms=0
   while [[ $dom0 -le $domN ]] ; do
      cfgid=$(int4digits $dom0)
      mkdir -p ${TASK_OUTPUT}/cfg_${cfgid}
      touch ${TASK_OUTPUT}/cfg_${cfgid}/status_mod.dot
      echo '_status=ABORT' >> ${TASK_OUTPUT}/cfg_${cfgid}/status_mod.dot
      ((dom0 = dom0 + 1 ))
   done
}

check_status() {
   MPI_DOMS=$1
   dom0=${MPI_DOMS%%:*}
   domN=${MPI_DOMS##*:}
   ndoms=0
   __status=0
   while [[ $dom0 -le $domN ]] ; do
      cfgid=$(int4digits $dom0)
      [[ -f ${TASK_OUTPUT}/cfg_${cfgid}/status_mod.dot ]] &&
         . ${TASK_OUTPUT}/cfg_${cfgid}/status_mod.dot
      cat <<EOF 
    $myself $dircfg/cfg_${cfgid} Ended with status=$_status
EOF
      #TODO: ?if _status=RESTART, force postclean=0?
      if [[ x$postclean == x0 && x$_status != xABORT ]] ; then
         cat <<EOF
    NOTE: Output can be found in $TASK_OUTPUT/cfg_${cfgid}
EOF
      else
         cat <<EOF
    ERROR: Model ended Abnormally for $cfgid
EOF
         __status=1
      fi
      ((dom0 = dom0 + 1 ))
   done
   [[ $__status == 1 ]] && exit 1
}

#==== Main script
runmodel() {
   MPI_DOMS=$1
   MPI_NGRIDS=$2
   MPI_NPEX=$3
   MPI_NPEY=$4
   MPI_NBLOCX=${5:-$MPI_NPEX}
   MPI_NBLOCY=${6:-$MPI_NPEY}
   MPI_NOMP=${7:-1}
   MPI_NINBLOCX=${8:-$MPI_NBLOCX}
   MPI_NINBLOCY=${9:-$MPI_NBLOCY}

   #-- SetUp dir and files for each domain
   myclean=" "
   if [[ x$restart == x0 ]] ; then
      myclean=" --clean"
      rm -rf ${model_exp_storage}/ 2>/dev/null || true
   fi

   if [[ -r ${config_basedir}/batch_config ]] ; then 
      . ${config_basedir}/batch_config
   fi
   set_tsk ${model_tsk_file} $MPI_DOMS $MPI_NGRIDS $MPI_NPEX $MPI_NPEY $MPI_NBLOCX $MPI_NBLOCY $MPI_NINBLOCX $MPI_NINBLOCY
   echo ndomsngrids=${ndomsngrids}
   echo UM_EXEC_Abs=${UM_EXEC_Abs:-""}
   echo UM_EXEC_ovbin=${UM_EXEC_ovbin:-""}

   MPI_NDOMS=${ndomsngrids%%:*}
   MPI_NGRIDS=${ndomsngrids##*:}
   if [[ x$ndomsngrids == x-1 ]] ;then
      echo $USAGE
      exit 1
   elif [[ x$MPI_NDOMS == x0 ]] ;then
      echo "ERROR: No domain was setup"
      echo $USAGE
      exit 1
   fi

   . ${config_basedir}/cfg_$(int4digits ${MPI_DOMS%%:*})/configexp.cfg

   task_setup_verbose=" "
   if [ "$verbosity" = "debug" ]; then
       task_setup_verbose=" --verbose"
   fi
   . task_setup.dot --file="$model_tsk_file" --base="$model_exp_storage""$myclean""$task_setup_verbose"
   
   #-- Export Mandatory EnvVar
   export UM_EXEC_VERBOSITY=$verbosity
   export UM_EXEC_NGRIDS=$MPI_NGRIDS
   export UM_EXEC_CONFIG_BASENAME=${model_cfg_filename%.*}
   export UM_EXEC_NDOMAINS=$MPI_DOMS
   export UM_EXEC_TIMEOUT=${timeout:-${UM_EXEC_TIMEOUT}}
   export OMP_NUM_THREADS=$MPI_NOMP

   #-- Run
   cd ${TASK_BASEDIR}
   set_status $MPI_DOMS
   echo "D=${UM_EXEC_NDOMAINS} G=${UM_EXEC_NGRIDS} P=${MPI_NPEX}x${MPI_NPEY}x${MPI_NOMP} B=${MPI_NBLOCX}x${MPI_NBLOCY}"
   #NOTE: MPI_NPEX computation will not work for domains with a mix of YY and non-YY grids 
   #((MPI_NPEX = MPI_NDOMS * MPI_NGRIDS * MPI_NPEX))
   mycmd=$MODEL_ABS
   if [[ x$binMPIext == xAbs ]] ; then
      rmpirun="$(which r.run_in_parallel || true)"
      [[ x$rmpirun == x ]] && rmpirun="r.mpirun"
      mycmd="$rmpirun -pgm ${TASK_BIN}/${model_name}.Abs -npex $((MPI_NGRIDS*MPI_NPEX*MPI_NPEY)) -npey $MPI_NDOMS ${inorder} ${nompi} ${debug} ${preexec} -minstdout 3"
   fi
   echo $mycmd
   if [[ x$dryrun == x0 ]] ; then
      $mycmd
      echo
      check_status $MPI_DOMS
      echo
   else
      echo "Dry Run: not running the model"
   fi
   
   #-- Cleanup
   if [[ x$clean == x1 ]] ; then
      rm -rf ${model_exp_storage} ${run_basedir_name} || true
   fi

}

runmodel $cfg $ngrids ${npex} ${npey} ${nblx} ${nbly} ${nomp} ${ninblx} ${ninbly} 
