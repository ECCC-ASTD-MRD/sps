#/bin/ksh
# taken from S. Chamberland from here:
# /users/dor/armn/sch/_Code_Depot_/work/mid-a6/YEC15w_a5-n2/batch_submit.ksh
set -x

cfgdir=$1
mymach=hadar
BATCH_launch_mach=$mymach
BATCH_launch_time_mod=1800 #1800
BATCH_launch_cm=4G
npex=2 #4
npey=2 #4
#nomp=2
nomp=1
isyygrid=1
#SMT="-smt"
BATCH_launch_listings=~/listings/$mymach
batch_class=
batch_waste="-waste 100"
#cfgdir=ont_1_batch


here=$(pwd)
myname=${cfgdir} #           ${here##*/}
jobname=${myname}.job
rm -f ${jobname}
read wait for me
cat >${jobname} <<EOF
cd ${here}
echo $storage_model
. .setenv.dot
sps.ksh --dircfg ${cfgdir} --ptopo ${npex}x${npey}x${nomp} --btopo=1x1
EOF
#cat >${jobname} <<EOF
#date
#echo storage: $storage_model
#EOF
set -x
ord_soumet $(true_path ${here}/${jobname}) \
   -mach $BATCH_launch_mach -t $BATCH_launch_time_mod -cm $BATCH_launch_cm  \
   -cpus ${npex}x${npey}x${nomp} -listing $BATCH_launch_listings     \
   -jn ${jobname} -mpi ${batch_class} ${batch_waste} $SMT  \
   -shell bash
