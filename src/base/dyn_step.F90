!--------------------------------------------------------------------------
! This is free software, you can use/redistribute/modify it under the terms of
! the EC-RPN License v2 or any later version found (if not provided) at:
! - http://collaboration.cmc.ec.gc.ca/science/rpn.comm/license.html
! - EC-RPN License, 2121 TransCanada, suite 500, Dorval (Qc), CANADA, H9P 1J3
! - service.rpn@ec.gc.ca
! It is distributed WITHOUT ANY WARRANTY of FITNESS FOR ANY PARTICULAR PURPOSE.
!-------------------------------------------------------------------------- 

!/@*
module dyn_step_mod
   use phy_itf
   use vGrid_Descriptors
   use vgrid_wb
   use gmmx_mod
   use drv_time_mod
   implicit none
   private
   !@objective 
   !@author Stephane Chamberland, April 2012
   !@revisions
   !@public_functions
   public :: dyn_step
   !@public_params
   !@public_vars
!*@/
#include <arch_specific.hf>
#include <rmnlib_basics.hf>
#include <clib_interface_mu.hf>
#include <WhiteBoard.hf>
#include <gmm.hf>
#include <msg.h>
   include "thermoconsts.inc"

   integer,parameter :: MAXNVAR = 64
   integer,parameter :: NK_MAX0 = 1024
   !# integer,parameter :: NK_MAX1 = 2
   integer,parameter :: NK_MAX1 = 999

contains

   !/@*
   function dyn_step(F_step) result(F_istat)
      implicit none
      !@objective 
      !@arguments
      integer,intent(in) :: F_step
      !@return
      integer :: F_istat
      !@author Stephane Chamberland, 2012-03
      !@revisions
   !*@/
      character(len=MSG_MAXLEN) :: msg_S
      character(len=32) :: readlist_S(MAXNVAR)
      integer :: istat,nread,nk_max,nn
      logical :: read_hu_L
      !---------------------------------------------------------------------
      write(msg_S,'(a,I5.5)') '(dyn) Step=',F_step
      call msg(MSG_INFO,trim(msg_S)//' [Begin]')
      F_istat = RMN_OK

      nk_max = NK_MAX1 !# Note: limite operations to nk-1:nk (speed optimiz)
      if (F_step == 0) nk_max = NK_MAX0

      istat = wb_get('dyn/readlist',readlist_S,nread)
      istat = wb_get('dyn/nreadlist',nread)
      istat = wb_get('sps_cfgs/read_hu_l',read_hu_L)

      F_istat = min(dyn_press(readlist_S,nread,nk_max),F_istat)

      F_istat = min(dyn_mfbr2mf_adapt(readlist_S,nread,nk_max,F_step),F_istat)

      if (any(readlist_S(1:nread) == 'tr/hr:p')) then
         F_istat = min(dyn_hr2hu(readlist_S,nread,nk_max),F_istat)
      elseif (read_hu_L) then
         nread = nread + 1
         readlist_S(nread) = 'tr/hr:p'
      endif

      if (any(readlist_S(1:nread) == 'pw_gz:p')) then
         !#Note: in rpnphy5.7 GZ is ASL (not AGL)
         continue
      else
         !# Note: make sure dyn_press,hr2hu is done before dyn_aglgz
         F_istat = min(dyn_aglgz(readlist_S,nread,nk_max),F_istat)
      endif

      F_istat = min(priv_copy_special(readlist_S,nread,nk_max),F_istat)

      !# Note: at step==0, it is needed to init :M vars; :P var are copied
      if (F_step == 0) then
         call drv_time_shuffle((/'M','P'/),DRV_TIME_MODE_COPY)
      endif
      call priv_add_shuffle_list(readlist_S,nread,(/'M','P'/))

      F_istat = min(priv_checklist(readlist_S,nread,F_step),F_istat)

      if (RMN_IS_OK(F_istat)) then
         call msg(MSG_INFO,trim(msg_S)//' [End] OK')
      else
         call msg(MSG_ERROR,trim(msg_S)//' [End] with Problems')
      endif
      !---------------------------------------------------------------------
      return
   end function dyn_step


   !/@*
   function dyn_press(my_readlist_S,my_nread,my_nk_max) result(my_istat)
      !@objective Compute Pressure
      implicit none
      character(len=*) :: my_readlist_S(:)
      integer :: my_nread,my_istat,my_nk_max
      !*@/
      logical,save :: is_init_L = .false.
      real,pointer,save :: p0(:,:,:)
      integer,pointer,save :: ip1_m(:),ip1_t(:)
      type(vgrid_descriptor),save :: vgrid_m,vgrid_t
      integer :: i,j,istat,istat2,k,k0m,k0t,knm,knt
      real,pointer :: pm3d(:,:,:),pt3d(:,:,:),pm3d0(:,:,:),pt3d0(:,:,:)
      !---------------------------------------------------------------------
      my_istat = RMN_ERR
      if (.not.is_init_L) then
         nullify(p0,ip1_m,ip1_t)
         istat = vgrid_wb_get('ref-m',vgrid_m,ip1_m)
         istat = vgrid_wb_get('ref-t',vgrid_t,ip1_t)
         istat = gmmx_data('P0',p0)
         if (associated(ip1_m) .and. associated(ip1_t) .and. associated(p0)) is_init_L = .true.
      endif
      nullify(pm3d,pt3d)
      istat = gmmx_data('PW_PM:P',pm3d)
      istat = gmmx_data('PW_PT:P',pt3d)
      if (.not.(associated(ip1_m) .and. associated(ip1_t) .and. &
           associated(p0) .and. associated(pm3d) .and. associated(pt3d))) then
         call msg(MSG_ERROR,'(dyn_step) Probleme getting data to compute Pressure')
         return
      endif
      knm = ubound(ip1_m,1)
      knt = ubound(ip1_t,1)
      k0m = max(lbound(ip1_m,1),knm-my_nk_max+1)
      k0t = max(lbound(ip1_t,1),knt-my_nk_max+1)
      nullify(pm3d0,pt3d0)
      istat = vgd_levels(vgrid_m,ip1_m(k0m:knm),pm3d0,p0(:,:,1),in_log=.false.)
      istat = min(vgd_levels(vgrid_t,ip1_t(k0t:knt),pt3d0,p0(:,:,1),in_log=.false.),istat)
      if (.not.RMN_IS_OK(istat)) then
         call msg(MSG_ERROR,'(dyn_step) Probleme getting pressure from vgrid')
         return
      endif
      pm3d(:,:,k0m:knm) = pm3d0(:,:,1:knm-k0m+1)
      pt3d(:,:,k0t:knt) = pt3d0(:,:,1:knt-k0t+1)
      if (associated(pm3d0)) deallocate(pm3d0,stat=istat2)
      if (associated(pt3d0)) deallocate(pt3d0,stat=istat2)
      my_nread = min(my_nread+1,size(my_readlist_S))
      my_readlist_S(my_nread) = 'pw_pm:p'
      my_nread = min(my_nread+1,size(my_readlist_S))
      my_readlist_S(my_nread) = 'pw_pt:p'
      my_istat = RMN_OK
      call msg(MSG_INFO,'(dyn_step) Compute Pressure [PW_PM:P, PW_PT:P]')
      !---------------------------------------------------------------------
      return
   end function dyn_press


   !/@*
   function dyn_mfbr2mf_adapt(my_readlist_S,my_nread,my_nk_max,my_step) result(my_istat)
      !@objective Adapt fields to High Res. Topography
      !@revisions
      ! Bug fix for surface pressure M.A. 2016 
      implicit none
      character(len=*) :: my_readlist_S(:)
      integer :: my_nread,my_istat,my_nk_max,my_step
      !*@/
      real,parameter :: SMALLDIFF = 0.1
      logical,save :: is_init_L = .false.
      logical,save :: nodiff_L=.false.
      logical,save :: adapt_L = .false.
      real,save :: lapserate = 0.0065
      real,pointer,save :: p0(:,:,:) => null()
      real,pointer,save :: dmf(:,:,:) => null()
      real,pointer,save :: local_sigmat(:,:,:) => null()
      real,pointer,save :: local_sigmam(:,:,:) => null()
      real,pointer,dimension(:,:,:) :: mf,mfbr,hr,tt,pt,pm
      integer :: istat,istat2,k0,kn,k,lijk(3),uijk(3)
      !---------------------------------------------------------------------
      my_istat = RMN_OK
      if (.not.is_init_L) then
         nullify(dmf)
         istat = wb_get('sps_cfgs/adapt_L',adapt_L)
         istat = wb_get('sps_cfgs/lapserate',lapserate)
         is_init_L = .true.
      endif  

      if (.not.adapt_L) return
      
      nullify(mf,mfbr,hr,tt,pt,pm)
      my_istat = min(gmmx_data('MF',mf),my_istat)
      my_istat = min(gmmx_data('MFBR',mfbr),my_istat)
      my_istat = min(gmmx_data('TR/HR:P',hr),my_istat)
      my_istat = min(gmmx_data('PW_TT:P',tt),my_istat)
      my_istat = min(gmmx_data('PW_PT:P',pt),my_istat)
      my_istat = min(gmmx_data('PW_PM:P',pm),my_istat)
      my_istat = min(gmmx_data('P0',p0),my_istat)
      
      if (.not.(associated(mf) .and. associated(mfbr) .and. &
           associated(hr) .and. associated(tt)        .and. &
           associated(pt) .and. associated(pm)        .and. &
           associated(p0))) then
         call msg(MSG_ERROR,'(dyn_step) Probleme getting data in dyn_mfbr2mf_adapt')
         my_istat = RMN_ERR
         return
      endif

      if (my_step == 0) then
         if (.not.any(my_readlist_S(1:my_nread) == 'mfbr')) then
            call msg(MSG_ERROR,'(dyn_step) Cannot run adaptation without MFBR')
            my_istat = RMN_ERR
            return
         endif
      endif
    
      lijk = lbound(hr)
      uijk = ubound(hr)

      if (.not.associated(dmf)) then
         allocate(dmf(lijk(1):uijk(1),lijk(2):uijk(2),1),stat=istat)
         dmf = mfbr - mf
         if (maxval(abs(dmf)) < SMALLDIFF) then
            nodiff_L = .true.
         endif
      endif

      if (nodiff_L) then
         call msg(MSG_INFO,'(dyn_step) Adaptation to High Res. Topography (nothing to do)')
         return
      endif

     
       kn = uijk(3)

       ! calculate local sigma before adaptation
       if (.not.associated(local_sigmat)) then
          allocate(local_sigmat(lijk(1):uijk(1),lijk(2):uijk(2),1),stat=istat)
       endif
       if (.not.associated(local_sigmam)) then
          allocate(local_sigmam(lijk(1):uijk(1),lijk(2):uijk(2),1),stat=istat)
       endif
       
       local_sigmat(:,:,1) = pt(:,:,kn-1)/pt(:,:,kn)
       local_sigmam(:,:,1) = pm(:,:,kn-1)/pm(:,:,kn)
       
       ! First adapt Temperature at Forcing level k=kn-1
       tt(:,:,kn-1) = tt(:,:,kn-1) + dmf(:,:,1) * lapserate
      
       ! re-calculate pressure at forcing level with new temperature
       pt(:,:,kn-1) = exp( &
           (dmf(:,:,1)*GRAV/RGASD)/tt(:,:,kn-1) + log(pt(:,:,kn-1)) &
           )
       pm(:,:,kn-1) = exp( &
           (dmf(:,:,1)*GRAV/RGASD)/tt(:,:,kn-1) + log(pm(:,:,kn-1)) &
           )

       ! calculate sfc pressure, keeping local sigma=p(kn-1)/p(kn) value constant
       pt(:,:,kn) = pt(:,:,kn-1) / local_sigmat(:,:,1)
       pm(:,:,kn) = pm(:,:,kn-1) / local_sigmam(:,:,1)
       ! the variable p0 is used in the physics to get the forcing height
       p0(:,:,1) = pm(:,:,kn) 
                
      
       call msg(MSG_INFO,'(dyn_step) Adaptation to High Res. Topography')
      !---------------------------------------------------------------------
      return
   end function dyn_mfbr2mf_adapt


   !/@*
   function dyn_hr2hu(my_readlist_S,my_nread,my_nk_max) result(my_istat)
      !@objective Compute HU from HR
      implicit none
      character(len=*) :: my_readlist_S(:)
      integer :: my_nread,my_istat,my_nk_max
      !*@/
      logical,parameter :: SWPH = .false. !# consider water phase only
      logical,save :: is_init_L = .false.
      logical,save :: clip_hu_L = .false.
      integer :: k0,kn,lijk(3),uijk(3),i,j,k,nij,istat
      real,pointer :: hu(:,:,:),hr(:,:,:),tt(:,:,:),pt(:,:,:)
      !---------------------------------------------------------------------
      my_istat = RMN_OK
      if (.not.is_init_L) then
         istat = wb_get('sps_cfgs/clip_hu_L',clip_hu_L)
         is_init_L = .true.
      endif

      nullify(hu,hr,tt,pt)
      my_istat = min(gmmx_data('TR/HU:P',hu),my_istat)
      my_istat = min(gmmx_data('TR/HR:P',hr),my_istat)
      my_istat = min(gmmx_data('PW_TT:P',tt),my_istat)
      my_istat = min(gmmx_data('PW_PT:P',pt),my_istat)
      if (.not.(RMN_IS_OK(my_istat) .and. &
           associated(hu) .and. associated(hr) .and. &
           associated(tt) .and. associated(pt) )) then
         call msg(MSG_ERROR,'(dyn_step) Probleme Getting pointers, cannot compute HU')
         return
      endif
      lijk = lbound(hu)
      uijk = ubound(hu)
      kn = uijk(3)
      k0 = max(lijk(3),kn-my_nk_max+1)
 !!$      k0 = lijk(3)
      nij = (uijk(1)-lijk(1)+1) *  (uijk(2)-lijk(2)+1)
      call mhrahu3(hu(:,:,k0:kn),hr(:,:,k0:kn),tt(:,:,k0:kn),pt(:,:,k0:kn),SWPH,nij,kn-k0+1,nij)
      if (clip_hu_L) then
         hu(:,:,k0:kn) = max(0.,hu(:,:,k0:kn))
      endif
      my_nread = min(my_nread+1,size(my_readlist_S))
      my_readlist_S(my_nread) = 'tr/hu:p'
      call msg(MSG_INFO,'(dyn_step) Compute Specific Humidity HU')
      !---------------------------------------------------------------------
      return
   end function dyn_hr2hu


   !/@*
   function dyn_aglgz(my_readlist_S,my_nread,my_nk_max) result(my_istat)
      !@objective Compute GZ (ASL, m^2/s^2) on momentum levels
      implicit none
      character(len=*) :: my_readlist_S(:)
      integer :: my_nread,my_istat,my_nk_max
      !*@/
      include "dintern.inc"
      include "fintern.inc"
      integer :: kn,kn1,lijk(3),uijk(3),i,j,istat
      real,pointer :: gz(:,:,:),tt(:,:,:),hu(:,:,:),pm(:,:,:),mf(:,:,:)
      real :: tve
      !---------------------------------------------------------------------
      my_istat = RMN_OK
      nullify(mf,gz,tt,hu,pm)
      my_istat = min(gmmx_data('MF',mf),my_istat)
!!$      my_istat = min(gmmx_data('MFBR',mf),my_istat)
      my_istat = min(gmmx_data('PW_GZ:P',gz),my_istat)
      my_istat = min(gmmx_data('PW_TT:P',tt),my_istat)
      my_istat = min(gmmx_data('TR/HU:P',hu),my_istat)
      my_istat = min(gmmx_data('PW_PM:P',pm),my_istat)
      if (.not.(RMN_IS_OK(my_istat) &
           .and. associated(mf) .and. associated(gz) .and. associated(tt) &
           .and. associated(hu) .and. associated(pm) )) then
         call msg(MSG_ERROR,'(dyn_step) Probleme Getting pointers, cannot compute GZ')
         return
      endif
      lijk = lbound(gz)
      uijk = ubound(gz)
      kn = uijk(3)
      kn1 = max(lijk(3),kn-1)

      gz(:,:,:) = 0.
      do j=lijk(2),uijk(2)
         do i=lijk(1),uijk(1)
            !# Note: tve(k=nk-1) is used since we cannot compute mid-layer TVE
            tve = FOTVT(tt(i,j,kn1),hu(i,j,kn1))
            gz(i,j,kn1) = RGASD * tve * log(pm(i,j,kn)/pm(i,j,kn1))
!!$            gz(i,j,kn1) = gz(i,j,kn) + GRAV * RGASD/GRAV * tve * log(pm(i,j,kn)/pm(i,j,kn1))
         enddo
      enddo
      gz(:,:,kn1) = gz(:,:,kn1) + mf(:,:,1)*GRAV
      !TODO: levels above nk-1

      my_nread = min(my_nread+1,size(my_readlist_S))
      my_readlist_S(my_nread) = 'PW_GZ:P'
      call msg(MSG_INFO,'(dyn_step) Compute AGL GZ ')
      !---------------------------------------------------------------------
      return
   end function dyn_aglgz


   !/@*
   function priv_copy_special(my_readlist_S,my_nread,my_nk_max) result(my_istat)
      !@objective Copy some field to special names for the physic
      !  copy P0 into PW_P0:P
      !  copy MF into PW_ME:M with change of units from [m] to [m^2/s^2]
      implicit none
      character(len=*) :: my_readlist_S(:)
      integer :: my_nread,my_istat,my_nk_max
      !*@/
      real,pointer :: mf(:,:,:),p0(:,:,:),pw_me(:,:,:),pw_p0(:,:,:)
      real :: tve
      !---------------------------------------------------------------------
      my_istat = RMN_OK
      nullify(mf,p0,pw_me,pw_p0)
      my_istat = min(gmmx_data('MF',mf),my_istat)
!!$      my_istat = min(gmmx_data('MFBR',mf),my_istat)
      my_istat = min(gmmx_data('P0',p0),my_istat)
      my_istat = min(gmmx_data('PW_ME:M',pw_me),my_istat)
      my_istat = min(gmmx_data('PW_P0:P',pw_p0),my_istat)

      if (.not.(RMN_IS_OK(my_istat) &
           .and. associated(mf) .and. associated(p0) &
           .and. associated(pw_me) .and. associated(pw_p0) )) then
         call msg(MSG_ERROR,'(dyn_step) Probleme Getting pointers, cannot copy fields to PW')
         return
      endif

      pw_p0 = p0
      pw_me = mf*GRAV

      my_nread = min(my_nread+1,size(my_readlist_S))
      my_readlist_S(my_nread) = 'PW_ME:M'
      my_nread = min(my_nread+1,size(my_readlist_S))
      my_readlist_S(my_nread) = 'PW_P0:P'
      call msg(MSG_INFO,'(dyn_step) Copy special ')
      !---------------------------------------------------------------------
      return
   end function priv_copy_special


   !/@*
   subroutine priv_add_shuffle_list(my_readlist_S,my_nread,my_timeflags_S)
      !@objective Check if all requested var have been read
      implicit none
      character(len=*) :: my_readlist_S(:),my_timeflags_S(:)
      integer :: my_nread
      !*@/
      character(len=GMM_MAXNAMELENGTH),save :: varlist2_S(2,MAXNVAR)
      integer,save :: nvars = 0
      character(len=GMM_MAXNAMELENGTH) :: varlist_S(MAXNVAR),names_S(2)
      integer :: ivar,istat
      !---------------------------------------------------------------------
      if (nvars == 0) then
         nvars = drv_time_shuffle_list(varlist_S,my_timeFlags_S)
         do ivar = 1, nvars
            names_S(1) = trim(varlist_S(ivar))//trim(my_timeFlags_S(1))
            names_S(2) = names_S(1)
            call drv_time_shuffle_name(names_S(2),my_timeFlags_S)
            istat = clib_tolower(names_S(1))
            istat = clib_tolower(names_S(2))
            varlist2_S(1,ivar) = names_S(1)
            varlist2_S(2,ivar) = names_S(2)
         enddo
      endif
      do ivar = 1, my_nread
         istat = clib_tolower(my_readlist_S(ivar))
      enddo
      do ivar = 1, nvars
         if (any(my_readlist_S(1:my_nread) == varlist2_S(2,ivar)) .and. &
              .not.any(my_readlist_S(1:my_nread) == varlist2_S(1,ivar))) then
            my_nread = min(my_nread+1,size(my_readlist_S))
            my_readlist_S(my_nread) = varlist2_S(1,ivar)
            call msg(MSG_INFOPLUS,'(dyn_step) Add shuffled Var: '//trim(varlist2_S(1,ivar)))
         else
            call msg(MSG_INFOPLUS,'(dyn_step) Skipping shuffled Var: '//trim(varlist2_S(1,ivar)))
         endif
      enddo
      !---------------------------------------------------------------------
      return
   end subroutine priv_add_shuffle_list


   !/@*
   function priv_checklist(my_readlist_S,my_nread,my_step) result(my_istat)
      !@objective Check if all requested var have been read
      implicit none
      character(len=*) :: my_readlist_S(:)
      integer :: my_nread,my_step,my_istat
      !*@/
      integer,parameter :: MUST_INIT = 1
      integer,save :: nbvar = 0, nreq_vars = 0
      logical,save :: is_init_L = .false.
      character(len=GMM_MAXNAMELENGTH),save :: req_varlist_S(MAXNVAR),varname_S
      integer :: ivar,istat,n,nvars0
      type(phymeta), pointer :: mymetalist(:)
      !---------------------------------------------------------------------
      my_istat = RMN_OK
      IF_INIT: if (.not.is_init_L) then
         is_init_L = .true.
         nullify(mymetalist)
         nvars0 = phy_getmeta(mymetalist,' ',F_bpath='D',F_quiet=.true.)
         nreq_vars = 0
         do ivar=1,nvars0
            if (mymetalist(ivar)%init > 0) then
               nreq_vars = nreq_vars + 1
               req_varlist_S(nreq_vars) = mymetalist(ivar)%vname
               istat = clib_tolower(req_varlist_S(nreq_vars))
               varname_S = req_varlist_S(nreq_vars)
               n = len_trim(varname_S)
               if (varname_S(n-1:n) == ',w') req_varlist_S(nreq_vars) = varname_S(1:n-2)
            endif
         enddo
         deallocate(mymetalist,stat=istat)
      endif IF_INIT

      do ivar=1,my_nread
         istat = clib_tolower(my_readlist_S(ivar))
      enddo

      do ivar=1,nreq_vars
         if (my_nread == 0 .or. &
              .not.any(req_varlist_S(ivar) == my_readlist_S(1:my_nread))) then
            my_istat = RMN_ERR
            call msg(MSG_ERROR,'(dyn_step) Missing mandatory var: '//trim(req_varlist_S(ivar)))
         endif
      enddo
      !---------------------------------------------------------------------
      return
   end function priv_checklist


end module dyn_step_mod

