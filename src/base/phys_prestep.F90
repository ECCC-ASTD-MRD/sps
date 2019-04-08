!--------------------------------------------------------------------------
! This is free software, you can use/redistribute/modify it under the terms of
! the EC-RPN License v2 or any later version found (if not provided) at:
! - http://collaboration.cmc.ec.gc.ca/science/rpn.comm/license.html
! - EC-RPN License, 2121 TransCanada, suite 500, Dorval (Qc), CANADA, H9P 1J3
! - service.rpn@ec.gc.ca
! It is distributed WITHOUT ANY WARRANTY of FITNESS FOR ANY PARTICULAR PURPOSE.
!-------------------------------------------------------------------------- 

!>
module phys_prestep_mod
   use phy_itf
   implicit none
   private
   !@objective 
   !@author Stephane Chamberland, April 2012
   !@revisions
   ! 001    M. Abrahamowicz    May 2014
   !        Abort if PR0 (1hr precip. accumulation) has negative value
   ! 002    M. Abrahamowicz    March 2015
   !        Use new sps_cfgs key to decide if Pr0 negative enough to abort
   ! 2015-06, S. Chamberland: Adapt to RPNPhy 5.7 API
   !@public_functions
   public :: phys_prestep
   !@public_params
   !@public_vars
!**/
#include <arch_specific.hf>
#include <rmnlib_basics.hf>
#include <gmm.hf>
#include <msg.h>
#include <WhiteBoard.hf>

contains

   !>
   function phys_prestep(F_step) result(F_istat)
      implicit none
      !@objective
      !@arguments
      integer,intent(in) :: F_step
      !@return
      integer :: F_istat
   !**/
      logical,save :: is_init_L = .false.
      real,pointer,save :: BUSVOL3d(:,:) => null()
      real,pointer :: data3d(:,:,:)
      real, save :: max_neg_pr0 = -1.0000E-5
      integer :: istat
      character(len=MSG_MAXLEN) :: msg_S
      !---------------------------------------------------------------------
      F_istat = RMN_OK

      if (.not.is_init_L) then
         call msg(MSG_INFO,'(Phys) Pre-Step Init [Begin]')
         F_istat = wb_get('sps_cfgs/max_neg_pr0',max_neg_pr0)
         if (max_neg_pr0 > 0. .or. .not.RMN_IS_OK(F_istat)) then
            write(msg_S,'(a,es10.3,a)') '(Phys) Pre-Step ABORT: BAD sps cfg option: max_neg_pr0 (=',max_neg_pr0,') should be NEGATIVE '
            F_istat = RMN_ERR
            call msg(MSG_ERROR,msg_S)
         endif
         F_istat = min(gmm_get('BUSVOL_3d',BUSVOL3d),F_istat)
         call collect_error(F_istat)
         if (.not.RMN_IS_OK(F_istat)) then
            call msg(MSG_ERROR,'(Phys) Pre-Step Problem in Init')
            return
         else
            call msg(MSG_INFO,'(Phys) Pre-Step Init End')
         endif
         is_init_L = .true.
      endif

      !# Reset to Zero at every step: tendencies, accumulators, ... in Vol Bus
      BUSVOL3d = 0.

      !# Note: 1h PR accumulation PR0 is read into PREN then copied to TSS
      nullify(data3d)
      F_istat = phy_get(data3d,'PREN')
      if (.not.(RMN_IS_OK(F_istat).and.associated(data3d))) then
         F_istat = RMN_ERR
         call msg(MSG_ERROR,'(Phys) Pre-Step problem getting PREN')
         return
      endif

      if (minval(data3d) < max_neg_pr0) then
         F_istat = RMN_ERR
      endif
      call collect_error(F_istat)
      if (.not.RMN_IS_OK(F_istat)) then
         write(msg_S,'(a,es10.3,a,es10.3,a)') '(Phys) Pre-Step ABORT: 1hr precip accum. PR0 (=',minval(data3d),') exceeds maximum negative value allowed (max_neg_pr0=',max_neg_pr0,') '
         call msg(MSG_ERROR,msg_S)
         return
      endif

      !# Clean up negative values and change units for TSS then save in bus
      data3d = max(0.,data3d)/3600.
      istat = phy_put(data3d,'TSS')
      if (.not.RMN_IS_OK(F_istat)) then
         F_istat = RMN_ERR
         call msg(MSG_ERROR,'(Phys) Pre-Step problem updating TSS')
         return
      endif

      deallocate(data3d,stat=istat)
      !---------------------------------------------------------------------
      return
   end function phys_prestep


end module phys_prestep_mod
