!--------------------------------------------------------------------------
! This is free software, you can use/redistribute/modify it under the terms of
! the EC-RPN License v2 or any later version found (if not provided) at:
! - http://collaboration.cmc.ec.gc.ca/science/rpn.comm/license.html
! - EC-RPN License, 2121 TransCanada, suite 500, Dorval (Qc), CANADA, H9P 1J3
! - ec.service.rpn.ec@canada.ca
! It is distributed WITHOUT ANY WARRANTY of FITNESS FOR ANY PARTICULAR PURPOSE.
!-------------------------------------------------------------------------- 

!/@*
module dyn_itf_mod
   use hgrid_wb
   use config_mod
   use gmmx_mod
   use drv_time_mod
   use dyn_grid_mod, only: dyn_grid_init,dyn_grid_post_init,dyn_lat_lon,dyn_dxdy
   use dyn_levels_mod, only: dyn_levels_init
   use dyn_input_mod, only: dyn_input
   use dyn_output_mod, only: dyn_output
   use dyn_step_mod, only: dyn_step
   use statfld_dm_mod
   implicit none
   private
   !@objective 
   !@author Stephane Chamberland, July 2008
   !@revisions
   !  2012-02, Stephane Chamberland: RPNPhy offline
   !@public_functions
   public :: dyn_config,dyn_init,dyn_input,dyn_step,dyn_output, &
        dyn_grid_init,dyn_grid_post_init,dyn_lat_lon,dyn_dxdy, &
        dyn_levels_init,dyn_blocstats
   !@public_params
   integer,parameter,public :: DYN_NTIMELEVELS = 2
   !@public_vars
!*@/
#include <arch_specific.hf>
#include <rmnlib_basics.hf>
#include <WhiteBoard.hf>
#include <msg.h>

contains

   !/@*
   function dyn_config(F_cfg_basename_S) result(F_istat)
      implicit none
      !@objective Read config file
      !@arguments
      character(len=*),intent(in) :: F_cfg_basename_S
      !@return
      integer :: F_istat
   !*@/
      !---------------------------------------------------------------------
      call msg(MSG_DEBUG,'[BEGIN] dyn_config')
      F_istat = config_read(F_cfg_basename_S,'sps_cfgs')
      call msg(MSG_DEBUG,'[END] dyn_config')
      !---------------------------------------------------------------------
      return
   end function dyn_config


   !/@*
   function dyn_init(F_dateo_S,F_dt_8,F_step) result(F_istat)
      implicit none
      !@objective Dyn init (check consitency)
      !@arguments
      character(len=*),intent(in) :: F_dateo_S
      real(RDOUBLE),intent(in) :: F_dt_8
      integer,intent(in) :: F_step
      !@return
      integer :: F_istat
   !*@/
     !---------------------------------------------------------------------
      call msg(MSG_DEBUG,'[BEGIN] dyn_init')
      F_istat = priv_consis()
      !---------------------------------------------------------------------
      return
   end function dyn_init


   !/@*
   subroutine dyn_blocstats(F_step,F_by_levels_L)
      implicit none
      !@objective Print Dyn Fields Statistics
      !@arguments
      integer,intent(in) :: F_step
      logical,intent(in) :: F_by_levels_L
   !*@/
      logical,parameter :: NOPRINT = .false.
      integer,parameter :: MAXNVAR = 64
      integer,parameter :: STAT_PRECISION = 4
      integer,parameter :: STAT_NK_MAX = 2
      character(len=MSG_MAXLEN) :: msg_S
      character(len=32) :: varlist_S(MAXNVAR),name_S,name2_S
      integer :: istat,nvars,ivar,k0,kn,k
      real,pointer :: gmmdata3d(:,:,:),gmmdata2d(:,:)
      !---------------------------------------------------------------------
      write(msg_S,'(a,I5.5)') '---- (dyn) Blocstat Step=',F_step
      call msg(MSG_INFO,trim(msg_S)//' [Begin] ------------')

      nvars = drv_time_shuffle_list(varlist_S,(/'m','p'/))
      do ivar = 1, nvars
         nullify(gmmdata2d,gmmdata3d)
         name_S = trim(varlist_S(ivar))//'p'
         istat = gmmx_data(name_S,gmmdata2d,NOPRINT)
         if (.not.(RMN_IS_OK(istat) .and. associated(gmmdata2d))) then
            istat = gmmx_data(name_S,gmmdata3d,NOPRINT)
            if (.not.(RMN_IS_OK(istat) .and. associated(gmmdata3d))) then
               cycle
            endif
            kn = ubound(gmmdata3d,3)
            k0 = max(lbound(gmmdata3d,3),kn-STAT_NK_MAX+1)
            if (F_by_levels_L) then
               do k=k0,kn
                  write(name2_S,'(a,i3.3,a)') trim(name_S)//'(',k,')'
                  call statfld_dm(gmmdata3d(:,:,k),name2_S,F_step,'dyn_blocstats',STAT_PRECISION) 
               enddo
            else
               call statfld_dm(gmmdata3d(:,:,k0:kn),name_S,F_step,'dyn_blocstats',STAT_PRECISION) 
            endif
         else
            call statfld_dm(gmmdata2d,name_S,F_step,'dyn_blocstats',STAT_PRECISION) 
         endif
      enddo

      call msg(MSG_INFO,trim(msg_S)//' [End]   ------------')
      !---------------------------------------------------------------------
      return
   end subroutine dyn_blocstats

   !/@*
   function priv_consis() result(F_istat)
      implicit none
      !@objective Check option consistency
      !@return
      integer :: F_istat, F_istat2
   !*@/
      integer,parameter :: MAX_LEVELS = 1024
      real, parameter :: epsilon_4 = 1.e-5
      logical :: read_hu_L, adapt_L
      real :: Lvl_list(MAX_LEVELS) , max_level
      real :: zta, zua = -1.
      integer :: nlvls
      !---------------------------------------------------------------------
      call msg(MSG_INFOPLUS,'(dyn_itf) Checking options consistency')
      F_istat = wb_get('sps_cfgs/read_hu_l',read_hu_L)
      F_istat = min(wb_get('sps_cfgs/adapt_L',adapt_L),F_istat)
      F_istat = min(wb_get('sps_cfgs/zta',zta),F_istat)
      F_istat = min(wb_put('itf_phy/zta',zta),F_istat)
      F_istat = min(wb_get('sps_cfgs/zua',zua),F_istat)
      F_istat = min(wb_put('itf_phy/zua',zua),F_istat)
      if (.not.RMN_IS_OK(F_istat)) then
         call msg(MSG_WARNING,'(dyn_itf) Problem getting sps_cfgs params to check options consistency')
         return
      endif

      if (read_hu_L .and. adapt_L) then
         call msg(MSG_WARNING,'(dyn_itf) Incompatible options: read_hu_L=.T. and adapt_L=.T.')
         F_istat = RMN_ERR
         return
      endif
      !---------------------------------------------------------------------
      return
   end function priv_consis


end module dyn_itf_mod

