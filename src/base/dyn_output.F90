!--------------------------------------------------------------------------
! This is free software, you can use/redistribute/modify it under the terms of
! the EC-RPN License v2 or any later version found (if not provided) at:
! - http://collaboration.cmc.ec.gc.ca/science/rpn.comm/license.html
! - EC-RPN License, 2121 TransCanada, suite 500, Dorval (Qc), CANADA, H9P 1J3
! - service.rpn@ec.gc.ca
! It is distributed WITHOUT ANY WARRANTY of FITNESS FOR ANY PARTICULAR PURPOSE.
!-------------------------------------------------------------------------- 

!/@*
module dyn_output_mod
   use output_mod
   use config_mod
   use cmcdate_mod
   implicit none
   private
   !@objective 
   !@author Stephane Chamberland, April 2012
   !@revisions
   !@public_functions
   public :: dyn_output
   !@public_params
   !@public_vars
!*@/
#include <arch_specific.hf>
#include <rmnlib_basics.hf>
#include <clib_interface_mu.hf>
#include <WhiteBoard.hf>
#include <msg.h>

contains


   !/@*
   function dyn_output(F_step) result(F_istat)
      implicit none
      !@objective Stub
      !@arguments
      integer,intent(in) :: F_step
      !@return
      integer :: F_istat
      !*@/
      integer, external :: dyn_output_callback
      character(len=*),parameter :: WB_LVL_SEC = 'levels_cfgs/'
      character(len=*),parameter :: OUTCFG_NAME = 'outcfg.out'
      integer,save :: out_id = -1
      integer :: reduc_core(4),dateo,istat,l_nk
      real(RDOUBLE) :: dt_8
      character(len=RMN_PATH_LEN) :: basedir_S,config_dir0_S,pwd_S,outcfg_S,dateo_S,msg_S
      !---------------------------------------------------------------------
      F_istat = RMN_OK
      if (out_id < 0) then
         call msg(MSG_INFO,'(dyn) Output Init Begin')
         F_istat = min(wb_get('path/config_dir0',config_dir0_S),F_istat)
         F_istat = min(config_cp2localdir(OUTCFG_NAME,config_dir0_S),F_istat)
         F_istat = min(clib_getcwd(pwd_S),F_istat)
         outcfg_S = trim(pwd_S)//'/'//OUTCFG_NAME
         F_istat = min(wb_get('time_run_start',dateo_S),F_istat)
         F_istat = min(wb_get('time_dt',dt_8),F_istat)
         dateo = cmcdate_fromprint(dateo_S)
         reduc_core(1:4) = (/1,-1,1,-1/) !#model == core
         out_id = output_new(outcfg_S,'d', dateo,nint(dt_8),reduc_core)
         F_istat = min(out_id,F_istat)
         if (RMN_IS_OK(out_id)) then
            F_istat = min(wb_get('path/output',basedir_S),F_istat)
            F_istat = min(output_set_basedir(out_id,basedir_S),F_istat)
         endif
         call collect_error(F_istat)
         if (.not.RMN_IS_OK(F_istat)) then
            out_id  = -1
            call msg(MSG_ERROR,'(dyn) Output Problem in Init')
            return
         else
            call msg(MSG_INFO,'(dyn) Output Init End')
         endif
         istat = wb_get(WB_LVL_SEC//'nk',l_nk)
         istat = output_set_diag_level(out_id,l_nk)
      endif

      F_istat = output_writestep(out_id,F_step,dyn_output_callback)
      call collect_error(F_istat)
      write(msg_S,'(a,I5.5)') '(dyn) Output Step=',F_step
     if (F_istat == 0) then
         call msg(MSG_INFO,trim(msg_S)//' No Output')
      else if (F_istat > 0) then
         write(msg_S,'(a,I5)') trim(msg_S)//' Wrote nvar=',F_istat
         call msg(MSG_INFO,trim(msg_S))
      else
         call msg(MSG_INFO,trim(msg_S)//' End with problems')
      endif
      !---------------------------------------------------------------------
      return
   end function dyn_output


end module dyn_output_mod

