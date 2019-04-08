!--------------------------------------------------------------------------
! This is free software, you can use/redistribute/modify it under the terms of
! the EC-RPN License v2 or any later version found (if not provided) at:
! - http://collaboration.cmc.ec.gc.ca/science/rpn.comm/license.html
! - EC-RPN License, 2121 TransCanada, suite 500, Dorval (Qc), CANADA, H9P 1J3
! - service.rpn@ec.gc.ca
! It is distributed WITHOUT ANY WARRANTY of FITNESS FOR ANY PARTICULAR PURPOSE.
!-------------------------------------------------------------------------- 

!/@*
module dyn_levels_mod
   use vGrid_Descriptors
   use vgrid_wb
   use sort_mod
   implicit none
   private
   !@objective 
   !@author Stephane Chamberland, July 2008
   !@revisions
   !  2012-02, Stephane Chamberland: RPNPhy offline
   !@public_functions
   public :: dyn_levels_init
   !@public_params
   !@public_vars
!*@/
#include <arch_specific.hf>
#include <rmnlib_basics.hf>
#include <WhiteBoard.hf>
#include <msg.h>
   include "thermoconsts.inc"

   integer,external :: msg_getUnit
   character(len=*),parameter :: WB_LVL_SEC = 'levels_cfgs/'
   integer,parameter :: MAX_LEVELS = 1024
   real(RDOUBLE),parameter :: PREF_8 = 100000.d0

contains

   !/@*
   function dyn_levels_init(F_nk,F_vcoor,F_stag_L,F_surf_idx) result(F_istat)
      implicit none
      !@objective 
      !@arguments
      integer,intent(out) :: F_nk,F_surf_idx
      type(vgrid_descriptor),intent(out) :: F_vcoor
      logical,intent(out) :: F_stag_L
      !@return
      integer :: F_istat
      !@author Stephane Chamberland, 2012-02
      !@description
   !*@/
      character(len=32) :: Lvl_typ_S,tmp_S
      integer :: istat,istat2,Lvl_nk,nlvls,nrcoef,nn,n2(1),lvl_kind,lvl_version,k0,kn,msgUnit,iverb
      logical :: Lvl_NoTopThL_L,Lvl_Tlift_L
      real :: Lvl_list(MAX_LEVELS),Lvl_rcoef(2),hybtop
      real(RDOUBLE) :: Lvl_ptop_8,Lvl_pref_8,Lvl_tstr_8,tmp_8
      !---------------------------------------------------------------------
      F_istat = RMN_ERR
      F_stag_L = .false.
      F_surf_idx = RMN_ERR
      
      istat = wb_get(WB_LVL_SEC//'Lvl_typ_S',Lvl_typ_S)
      istat = min(wb_get(WB_LVL_SEC//'Lvl_nk',Lvl_nk),istat)
      istat = min(wb_get(WB_LVL_SEC//'Lvl_list',Lvl_list,nlvls),istat)
      istat = min(wb_get(WB_LVL_SEC//'Lvl_rcoef',Lvl_rcoef,nrcoef),istat)
      istat = min(wb_get(WB_LVL_SEC//'Lvl_ptop_8',Lvl_ptop_8),istat)
      iverb = wb_verbosity(WB_MSG_FATAL)
      istat2 = wb_get(WB_LVL_SEC//'Lvl_pref_8',Lvl_pref_8)
      iverb = wb_verbosity(iverb)
      if (.not.RMN_IS_OK(istat2)) Lvl_pref_8 = PREF_8
      istat = min(wb_get(WB_LVL_SEC//'Lvl_tstr_8',Lvl_tstr_8),istat)
!!$      istat = min(wb_get(WB_LVL_SEC//'Lvl_NoTopThL_L',Lvl_NoTopThL_L),istat)
      Lvl_NotopThL_L = .false. !TODO: is this needed?
      istat = min(wb_get(WB_LVL_SEC//'Lvl_Tlift_L',Lvl_Tlift_L),istat)

      if (.not.RMN_IS_OK(istat)) then
         call msg(MSG_ERROR,'(dyn_levels) Problem getting config options')
         return
      endif

      !# Note: Ignore model levels outside of [0,1[ range
      Lvl_list = max(Lvl_list,0.)
      where(Lvl_list >= 1.) Lvl_list = 0.

      nn = sort(Lvl_list(1:nlvls),order_L=SORT_DOWN,unique_L=SORT_UNIQUE)
      n2 = minloc(Lvl_list(1:nn))
      F_nk = n2(1) - 1

      if (F_nk < 1) then
          call msg(MSG_INFO,'(dyn_levels) Forcing at zua, zta <= 10m heights. Forcing level set to 0.999')
          Lvl_list(1) = 0.999
          F_nk = 1
      endif

      if (F_nk > 1) nn = sort(Lvl_list(1:F_nk),order_L=SORT_UP)

      !# Note: add top and surf levels
      Lvl_list(2:F_nk+1) = Lvl_list(1:F_nk)
      Lvl_list(1) = real(lvl_ptop_8/Lvl_pref_8)
      Lvl_list(F_nk+2) = 1.
         
      F_nk = F_nk+2
      F_surf_idx = F_nk

      lvl_kind = RMN_ERR
      IF_TYP: if (Lvl_typ_S == 'HS') then

         F_stag_L = .true.
         if (Lvl_Tlift_L) then
            call msg(MSG_ERROR,'(dyn_levels) Not yet supported Lvl_typ_S='//trim(Lvl_typ_S)//' with Lvl_Tlift_L=.true.')
            return
!!$            lvl_kind    = VGRID_HYBT_KIND    !#5,3
!!$            lvl_version = VGRID_HYBT_VER
         else
            lvl_kind    = VGRID_HYBMD_KIND    !#5,5
            lvl_version = VGRID_HYBMD_KIND
         endif
         F_istat = vgd_new(F_vcoor, &
              kind     = lvl_kind, &
              version  = lvl_version, &
              hyb      = lvl_list(1:F_nk-1), &
              ptop_out_8 = tmp_8, &
              pref_8   = lvl_pref_8, &
              rcoef1   = lvl_rcoef(1), &
              rcoef2   = lvl_rcoef(2), &
              dhm      = 0., &
              dht      = 0.)

     else !IF_TYP

         F_stag_L = .false.
         if (Lvl_typ_S == 'HN') then
            call msg(MSG_ERROR,'(dyn_levels) Not yet supported Lvl_typ_S='//trim(Lvl_typ_S))
!!$            lvl_kind = VGRID_HYBN_KIND
!!$            lvl_version = VGRID_HYBN_VER
         endif
         if (Lvl_typ_S == 'HU') then
            lvl_kind = VGRID_HYB_KIND
            lvl_version = VGRID_HYB_VER
         endif
         if (RMN_IS_OK(lvl_kind)) then
            F_istat = vgd_new(F_vcoor, &
                 kind     = lvl_kind, &
                 version  = lvl_version, &
                 hyb      = lvl_list(1:F_nk), &
                 ptop_8   = lvl_ptop_8, &
                 pref_8   = lvl_pref_8, &
                 rcoef1   = lvl_rcoef(1))
         endif

      endif IF_TYP

      if (.not.RMN_IS_OK(lvl_kind)) then
         call msg(MSG_ERROR,'(dyn_levels) Unknown Lvl_typ_S='//trim(Lvl_typ_S))
         F_istat = RMN_ERR
         return         
      endif

      write(tmp_S,'(i4)') F_nk
      tmp_S = adjustl(tmp_S)
      msgUnit = msg_getUnit(MSG_INFO)
      if (msgUnit >= 0) then
         write(msgUnit,'(a," [type=",a,"] [stag=",l2,"] [surf_k=",i2,"] [nk=",i4,"] Lvl_list=",'//trim(tmp_S)//'(f10.7,","))') '(dyn_levels)',Lvl_typ_S(1:2),F_stag_L,F_surf_idx,F_nk,lvl_list(1:F_nk)
         call flush(msgUnit)
      endif
      !---------------------------------------------------------------------
      return
   end function dyn_levels_init


   !==== Private functions =================================================

end module dyn_levels_mod

