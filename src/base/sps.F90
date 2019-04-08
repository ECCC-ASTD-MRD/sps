!--------------------------------------------------------------------------
! This is free software, you can use/redistribute/modify it under the terms of
! the EC-RPN License v2 or any later version found (if not provided) at:
! - http://collaboration.cmc.ec.gc.ca/science/rpn.comm/license.html
! - EC-RPN License, 2121 TransCanada, suite 500, Dorval (Qc), CANADA, H9P 1J3
! - service.rpn@ec.gc.ca
! It is distributed WITHOUT ANY WARRANTY of FITNESS FOR ANY PARTICULAR PURPOSE.
!-------------------------------------------------------------------------- 

!/@*
subroutine sps()
   use env_utils, only: env_get
   use ptopo_utils, only: ptopo_grid_npe,ptopo_grid_ipe
   use drv_itf_mod, only: drv_ptopo_init,drv_ptopo_terminate,drv_verbosity,drv_config, drv_init,drv_time_info,drv_time_increment
   use phys_itf_mod, only: phys_config,phys_init,phys_input,phys_step,phys_output,phys_blocstats
   use dyn_itf_mod, only: dyn_config,dyn_init,dyn_input,dyn_step,dyn_output,dyn_blocstats,DYN_NTIMELEVELS
!!$   use input_step_mod, only: input_step
!!$   use output_step_mod, only: output_step
   implicit none
   !@objective SPS entry point and sequencer
   !@author 
   !  Michel Desgagne, Feb 2008
   !  Ron McTaggart-Cowan, Feb 2008
   !  Stephane Chamberland, Feb 2008
   !@revisions
   !  2008-11, Stephane Chamberland: ico/geodesic model
   !  2010-07, Stephane Chamberland: refactor for ico/geodesic model
   !  2012-02, Stephane Chamberland: RPNPhy offline (SPS)
!*@/
#include <arch_specific.hf>
#include <rmnlib_basics.hf>
#include <WhiteBoard.hf>
#include <gmm.hf>
#include <msg.h>

   integer, external :: model_timeout_alarm

   character(len=*),parameter :: MODEL_NAME = 'SPS'
   character(len=*),parameter :: TIME_FLAGS(2) = (/'M','P'/)
   character(len=*),parameter :: out_settings_S = 'outcfg.out'

   logical,parameter :: PRINT_ACCUM_L = .true.

   integer,parameter :: NGRIDS_DEFAULT = 1
   integer,parameter :: NGRIDS_MIN = 1
   integer,parameter :: NGRIDS_MAX = 10

   integer,parameter :: TIMEOUT_DEFAULT = 600
   integer,parameter :: TIMEOUT_MIN = 1
   integer,parameter :: TIMEOUT_MAX = 3600

   integer,parameter :: TMG_ALL = 1
   integer,parameter :: TMG_INIT = 2
   integer,parameter :: TMG_LOOP = 3
   integer,parameter :: TMG_DYN = 4
   integer,parameter :: TMG_PHYS = 5
   integer,parameter :: TMG_IN = 6
   integer,parameter :: TMG_OUT = 7
   integer,parameter :: TMG_STAT = 8
   integer,parameter :: TMG_CKPT = 9

   integer :: istat,istat2,ngrids,stepno,steps_total,delta_step,timeout,seconds_since
   logical :: is_last, is_chkpt, is_stat, stat_by_level_L
   real(RDOUBLE) :: dt_8
   character(len=RMN_PATH_LEN) :: tmp_S,config_name_S,dateo_S
   !---------------------------------------------------------------------
   istat = wb_put('ATM_MODEL_NAME',MODEL_NAME)

   istat = env_get('UM_EXEC_TIMEOUT',timeout,TIMEOUT_DEFAULT,TIMEOUT_MIN,TIMEOUT_MAX)
   istat = env_get('UM_EXEC_NGRIDS',ngrids,NGRIDS_DEFAULT,NGRIDS_MIN,NGRIDS_MAX)
   istat = drv_ptopo_init(ngrids)
   call handle_error(istat,MODEL_NAME,'(drv_ptopo_init) MPI init problems')

   call model_usage_stats(MODEL_NAME,.not.PRINT_ACCUM_L)

   call drv_verbosity('UM_EXEC')

   call timing_init2(ptopo_grid_ipe,MODEL_NAME)
   call timing_start2(TMG_ALL,MODEL_NAME//'-all',0)
   call timing_start2(TMG_INIT,MODEL_NAME//'-init',0)
   call model_usage_stats(trim(MODEL_NAME)//': START',.not.PRINT_ACCUM_L)

   !- Read config files
   seconds_since = model_timeout_alarm(timeout)
   istat = drv_config(config_name_S)
   istat = min(dyn_config(config_name_S),istat)
   istat = min(phys_config(config_name_S),istat)
   call handle_error(istat,MODEL_NAME,'error in config read')

   !- Initialize model components
   seconds_since = model_timeout_alarm(timeout)
   istat = drv_init(dateo_S,dt_8,stepno,DYN_NTIMELEVELS)
   if (RMN_IS_OK(istat)) istat = dyn_init(dateo_S,dt_8,stepno)

   if (RMN_IS_OK(istat)) istat = phys_init(dateo_S,dt_8,stepno)
   call handle_error(istat,MODEL_NAME,'error in init')

   istat = wb_get('sps_cfgs/stat_by_level_L',stat_by_level_L)   

   call timing_stop(TMG_INIT)

   !- Time loop
   istat = wb_get('time_cfgs/step_total',steps_total)
   call timing_start2(TMG_LOOP,MODEL_NAME//'-loop',0)
   call model_usage_stats(trim(MODEL_NAME)//': TIMELOOP START',.not.PRINT_ACCUM_L)
   delta_step = 1
   if (stepno == 0) delta_step = 0
   call drv_time_info(F_is_last_L = is_last)
   istat = RMN_OK
   DO_STEP: do while (.not.is_last .and. RMN_IS_OK(istat))
      seconds_since = model_timeout_alarm(timeout)
      call drv_time_increment(stepno,is_chkpt,is_last,is_stat,F_timeFlags_S=TIME_FLAGS,F_delta_step=delta_step)
      delta_step = 1
      write(tmp_S,*) "\n==== Processing Stepno: ",stepno,'/',steps_total,'[chkpt=',is_chkpt,', last=',is_last,"] ============\n"
      call msg(MSG_INFO,tmp_S)
      write(tmp_S,*) stepno

      call timing_start2(TMG_IN,MODEL_NAME//'-in',0)
      istat = dyn_input(stepno)
      call timing_stop(TMG_IN)
      call handle_error(istat,MODEL_NAME,'Problemes in dyn_input')

      call timing_start2(TMG_DYN,MODEL_NAME//'-dyn',0)
      istat = min(dyn_step(stepno),istat)
      call timing_stop(TMG_DYN)
      call handle_error(istat,MODEL_NAME,'Problemes in dyn_step')

      call timing_start2(TMG_IN,MODEL_NAME//'-in',0)
      istat = phys_input(stepno)
      call timing_stop(TMG_IN)
      call handle_error(istat,MODEL_NAME,'Problemes in phys_input')

      call timing_start2(TMG_PHYS,MODEL_NAME//'-phys',0)
      istat = min(phys_step(stepno),istat)
      call timing_stop(TMG_PHYS)
      call handle_error(istat,MODEL_NAME,'Problemes in physstep')

      if (is_stat.or.is_last) then
         call timing_start2(TMG_STAT,MODEL_NAME//'-stat',0)
         call dyn_blocstats(stepno,stat_by_level_L)
         call phys_blocstats(stepno,stat_by_level_L)
         call timing_stop(TMG_STAT)
      endif

      call timing_start2(TMG_OUT,MODEL_NAME//'-out',0)
      istat2 = dyn_output(stepno)
      istat2 = phys_output(stepno)
      call timing_stop(TMG_OUT)

      call model_usage_stats(trim(MODEL_NAME)//': END STEPNO = '//trim(tmp_S),.not.PRINT_ACCUM_L)

      !- Save info for restart
      CHECKPOINT: if (RMN_IS_OK(istat) .and. is_chkpt) then
         call timing_start2(TMG_CKPT,MODEL_NAME//'-ckpt',0)
         call msg(MSG_INFO,"Writing Restart File")
         istat2 = wb_checkpoint()
         istat2 = gmm_checkpoint_all(GMM_WRIT_CKPT)
         call timing_stop(TMG_CKPT)
      endif CHECKPOINT
      
   end do DO_STEP
   call timing_stop(TMG_LOOP)
   call model_usage_stats(trim(MODEL_NAME)//': TIMELOOP END',.not.PRINT_ACCUM_L)

   seconds_since = model_timeout_alarm(timeout)
   call handle_error(istat,MODEL_NAME,'error... somewhere!!! ;-)')
      
 !!$   istat = min(out_finalize(),istat)

   call timing_stop(TMG_ALL)
   call timing_terminate2(ptopo_grid_ipe,MODEL_NAME)
   call model_usage_stats(trim(MODEL_NAME)//': END OF_RUN',PRINT_ACCUM_L)
   call model_mem_usage_stats(ptopo_grid_npe, ptopo_grid_ipe)

   tmp_S = 'END'
   if (stepno < steps_total) tmp_S = 'RESTART'
   call drv_ptopo_terminate(tmp_S)
   !---------------------------------------------------------------------
   return

end subroutine sps
