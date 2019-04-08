!--------------------------------------------------------------------------
! This is free software, you can use/redistribute/modify it under the terms of
! the EC-RPN License v2 or any later version found (if not provided) at:
! - http://collaboration.cmc.ec.gc.ca/science/rpn.comm/license.html
! - EC-RPN License, 2121 TransCanada, suite 500, Dorval (Qc), CANADA, H9P 1J3
! - service.rpn@ec.gc.ca
! It is distributed WITHOUT ANY WARRANTY of FITNESS FOR ANY PARTICULAR PURPOSE.
!-------------------------------------------------------------------------- 

!>
module dyn_input_mod
   use vGrid_Descriptors
   use vgrid_wb
   use phy_itf
   use gmmx_mod
   use input_mod
   use hgrid_wb
   use config_mod
   use cmcdate_mod
   use statfld_dm_mod
   implicit none
   private
   !@objective 
   !@author Stephane Chamberland, April 2012
   !@revisions
   !@public_functions
   public :: dyn_input
   !@public_params
   !@public_vars
!**/
#include <arch_specific.hf>
#include <rmnlib_basics.hf>
#include <clib_interface_mu.hf>
#include <WhiteBoard.hf>
#include <gmm.hf>
#include <msg.h>
   include "thermoconsts.inc"

   real,parameter :: MB2PA =  100.
   real,parameter :: DAM2M =  10.
   real,parameter :: P0MIN =  30000. !# Above highest Mtn
   real,parameter :: P0MAX = 108570. !# Highest ever recorded
   integer,parameter :: MAXNVAR = 64
   integer,parameter :: STAT_PRECISION = 4
   integer,parameter :: NK_MAX0 = 1024
   integer,parameter :: NK_MAX1 = 2
   character(len=*),parameter :: WB_LVL_SEC = 'levels_cfgs/'
   character(len=*),parameter :: HGRID_S = 'local#'
   character(len=*),parameter :: HGRIDZ_S = 'localz'

   interface dyn_input
      module procedure dyn_input0
      module procedure dyn_input1
   end interface

contains

   !>
   function dyn_input1(F_step) result(F_istat)
      implicit none
      !@objective 
      !@arguments
      integer,intent(in) :: F_step
      !@return
      integer :: F_istat
      !@author Stephane Chamberland, 2012-03
      !@revisions
   !**/
      character(len=*),parameter :: INPUT_TABLE = 'dyn_input_table'
      logical,save :: is_init_L = .false.
      integer,save :: gridid,dateo,minxzy(3),mzxxyz(3)
      real(RDOUBLE),save :: dt_8
      character(len=RMN_PATH_LEN),save :: incfg_S,basedir_S
      character(len=RMN_PATH_LEN) :: msg_S,pwd_S,config_dir0_S,dateo_S
      !---------------------------------------------------------------------
      F_istat = RMN_OK
      if (.not.is_init_L) then
         is_init_L = .true.
         F_istat = hgrid_wb_get(HGRIDZ_S,gridid)
         F_istat = min(wb_get('path/input',basedir_S),F_istat)
         F_istat = min(wb_get('path/config_dir0',config_dir0_S),F_istat)
         F_istat = min(config_cp2localdir(INPUT_TABLE,config_dir0_S),F_istat)
         F_istat = min(clib_getcwd(pwd_S),F_istat)
         incfg_S = trim(pwd_S)//'/'//INPUT_TABLE
         F_istat = min(wb_get('time_run_start',dateo_S),F_istat)
         F_istat = min(wb_get('time_dt',dt_8),F_istat)
         dateo = cmcdate_fromprint(dateo_S)
      endif
      call collect_error(F_istat)
      if (.not.RMN_IS_OK(F_istat)) then
         write(msg_S,'(a,I5.5)') '(dyn_input) Step=',F_step
         call msg(MSG_ERROR,trim(msg_S)//' End with Problems in Init')
         return
      endif
      F_istat = dyn_input0(dateo,nint(dt_8),F_step,gridid,incfg_S,basedir_S)
      !---------------------------------------------------------------------
      return
   end function dyn_input1


   !>
   function dyn_input0(F_dateo,F_dt,F_step,F_gridid,F_incfg_S,F_basedir_S) result(F_istat)
      implicit none
      !@objective 
      !@arguments
      integer,intent(in) :: F_dateo,F_dt,F_step,F_gridid
      character(len=*),intent(in) :: F_incfg_S,F_basedir_S
      !@return
      integer :: F_istat
      !@author Stephane Chamberland, 2012-03
      !@revisions
   !**/
      !TODO: remove mfbr from optionals in final version
      character(len=32),parameter :: optional_list_S(1) = (/'mfbr'/)
      logical, save :: is_init_L = .false.
      logical, save :: read_gz_L = .false.
      logical, save :: read_hu_L = .false.
      integer, save :: inputid = -1
      integer, save :: nbvar = 0
      integer, save :: nskip = 0
      character(len=32), save :: skip_list_S(16)

      integer :: ivar,istat,nn,nread,nk_max
      character(len=4) :: inname_S,inname2_S,bus_S
      character(len=32) :: name_S,name2_S,horiz_interp_S,readlist_S(MAXNVAR),vgrid_S
      character(len=512) :: dummylist_S(10),msg_S,geofilename_S
      real,pointer :: data(:,:,:),data2(:,:,:)
!!$      integer,pointer :: ip1_m1(:)
      integer, target :: ip1_m1(1),ip1_t1(1)
      integer :: G_ngrids
      integer,pointer :: ip1list(:),ip1list0(:)
      logical :: is_3d, has_ip1m
      type(vgrid_descriptor) :: vgridm, vgridt
      !---------------------------------------------------------------------
      F_istat = RMN_OK
      write(msg_S,'(a,I5.5)') '(dyn_input) Step=',F_step
      call msg(MSG_INFO,trim(msg_S)//' Begin')

      !TODO: split into init/read
      nk_max = NK_MAX1 !# Note: limite operations to nk-1:nk (speed optimiz)
      if (F_step == 0) nk_max = NK_MAX0
      IF_INIT: if (.not.is_init_L) then
         is_init_L = .true.
         istat = wb_get('ptopo/ngrids',G_ngrids)
         if (.not.RMN_IS_OK(F_istat)) G_ngrids = 1
         !TODO: DXDY from cfgs if Y grid

         istat = wb_get('sps_cfgs/ip1a',ip1_m1(1))
         nullify(ip1list0)
         istat = vgrid_wb_get('ref-m',vgridm,ip1list0)
         has_ip1m = .true.
         if (ip1_m1(1) == -1) then
            has_ip1m = .false.
            ip1_m1(1) = ip1list0(size(ip1list0)-1)
         endif
         ip1list => ip1_m1
         istat = vgrid_wb_put('dyn-m',vgridm,ip1list)

         istat = wb_get('sps_cfgs/ip1at',ip1_t1(1))
         nullify(ip1list0)
         istat = vgrid_wb_get('ref-t',vgridt,ip1list0)
         if (ip1_t1(1) == -1) then
            ip1_t1(1) = ip1_m1(1)
            if (.not.has_ip1m) ip1_t1(1) = ip1list0(size(ip1list0)-1)
         endif
         ip1list => ip1_t1
         istat = vgrid_wb_put('dyn-t',vgridt,ip1list)

!!$         inputid = input_new(F_dateo,F_dt,F_incfg_S,ip1_m1)
         inputid = input_new(F_dateo,F_dt,F_incfg_S)
         if (.not.RMN_IS_OK(min(inputid,istat))) then
            call msg(MSG_ERROR,'(dyn_input) problem with dyn_input init')
            istat = RMN_ERR
         else
            nbvar = input_nbvar(inputid)
            if (G_ngrids == 1) then
               istat = input_set_basedir(inputid,F_basedir_S)
            else
               istat = input_set_basedir(inputid,trim(F_basedir_S)//'/..')
            endif
            geofilename_S = 'GEOPHY/Gem_geophy.fst'
            istat = min(input_set_filename(inputid,'geop',geofilename_S,.false.,INPUT_FILES_GEOP),istat)            
         endif
         F_istat = min(istat,F_istat)
         F_istat = min(dyn_create_vars(F_step),F_istat)
         nk_max = NK_MAX0
         skip_list_S = ' '
         nskip = 0
         istat = wb_get('sps_cfgs/read_gz_l',read_gz_L)
         istat = wb_get('sps_cfgs/read_hu_l',read_hu_L)
         if (.not.read_gz_L) then
            nskip = nskip + 1
            skip_list_S(nskip) = 'gz'
         endif
         nskip = nskip + 1
         if (read_hu_L) then
            skip_list_S(nskip) = 'hr'
         else
            skip_list_S(nskip) = 'hu'
         endif
      endif IF_INIT
      call collect_error(F_istat)
      if (.not.RMN_IS_OK(F_istat)) then
         call msg(MSG_ERROR,trim(msg_S)//' End with Problems in Init')
         return
      endif

      readlist_S = ' '
      nread = 0
      istat = input_setgridid(inputid,F_gridid)
      VARLOOP: do ivar=1,nbvar

         istat = input_isvarstep(inputid,ivar,F_step)
         if (.not.RMN_IS_OK(istat)) then
            cycle VARLOOP !var not requested at this step
         endif
         inname_S = ' '
         inname2_S = ' '
         istat = input_meta(inputid,ivar,inname_S,inname2_S,dummylist_S,horiz_interp_S)
         if (.not.RMN_IS_OK(istat)) then
            F_istat = RMN_ERR
            call msg(MSG_ERROR,'(dyn_input) problem getting input varname')
            cycle VARLOOP
         endif
         if (any(inname_S == skip_list_S(1:nskip))) then
            call msg(MSG_INFO,'(dyn_input) ignoring var: '//trim(inname_S))
            cycle VARLOOP !var not needed
         endif
         name_S = ' '
         name2_S = ' '
         bus_S = 'g'
         istat = gmmx_meta(name_S,F_namein_S=inname_S,F_vb_S=bus_S, F_vgrid_S=vgrid_S)
         if (name_S == '') then
            call msg(MSG_INFO,'(dyn_input) ignoring var: '//trim(inname_S)//' : '//trim(inname2_S))
            cycle VARLOOP !var not needed
         endif
         if (inname2_S /= ' ') then
            istat = gmmx_meta(name2_S,F_namein_S=inname2_S,F_vb_S=bus_S)
            if (name2_S == '') then
               call msg(MSG_INFO,'(dyn_input) ignoring var: '//trim(inname_S)//' : '//trim(inname2_S))
               cycle VARLOOP !var not needed
            endif
         endif

         if (vgrid_S == 'ref-t') then
            vgrid_S = 'dyn-t'
         else if (vgrid_S == 'ref-m') then
            vgrid_S = 'dyn-m'
         else
            vgrid_S = ' '
         endif
         nullify(data,data2)
!!$         istat = input_get(inputid,ivar,F_step,F_gridid,data,data2)
         istat = input_get(inputid,ivar,F_step,F_gridid,vgrid_S,data,data2)
         call collect_error(istat)
         if (.not.(RMN_IS_OK(istat) .and. associated(data))) then
            if (any(name_S == optional_list_S)) then
               call msg(MSG_WARNING,'(dyn_input) missing optional var: '//trim(inname_S)//' : '//trim(name_S))
               cycle VARLOOP
            endif
            F_istat = RMN_ERR
            call msg(MSG_ERROR,'(dyn_input) missing var: '//trim(inname_S)//' : '//trim(name_S))
            if (inname2_S /= ' ' .and. .not.associated(data2)) &
                 call msg(MSG_ERROR,'(dyn_input) missing var: '//trim(inname2_S)//' : '//trim(name2_S))
            if (associated(data)) deallocate(data,stat=istat)
            if (associated(data2)) deallocate(data2,stat=istat)
           cycle VARLOOP
         endif

         istat = dyn_simple_transform(inname_S,data)
         istat = min(priv_copy(inname_S,name_S,data,nk_max),istat)
         if (.not.RMN_IS_OK(istat)) then
            F_istat = RMN_ERR
            cycle VARLOOP
         endif
         call statfld_dm(data,name_S,F_step,'dyn_input, read: '//trim(inname_S),STAT_PRECISION)
         nread = min(nread + 1,MAXNVAR)
         readlist_S(nread) = name_S
         if (associated(data)) deallocate(data,stat=istat)

         if (name2_S /= ' ' .and. associated(data2)) then
            F_istat = min(dyn_simple_transform(inname2_S,data2),F_istat)
            F_istat = min(priv_copy(inname2_S,name2_S,data2,nk_max),F_istat)
            if (RMN_IS_OK(F_istat)) then
               call statfld_dm(data2,name2_S,F_step,'dyn_input, read: '//trim(inname2_S),STAT_PRECISION)
               nread = min(nread + 1,MAXNVAR)
               readlist_S(nread) = name2_S
            endif
         endif
         if (associated(data2)) deallocate(data2,stat=istat)

      enddo VARLOOP

      istat = wb_put('dyn/readlist',readlist_S,WB_REWRITE_MANY)
      istat = wb_put('dyn/nreadlist',nread,WB_REWRITE_MANY)

      if (RMN_IS_OK(F_istat)) then
         call msg(MSG_INFO,trim(msg_S)//' End OK')
      else
         call msg(MSG_ERROR,trim(msg_S)//' End with Problems')
      endif
      !---------------------------------------------------------------------
      return
   end function dyn_input0


   !>
   function priv_copy(my_inname_S,my_name_S,my_data,my_nk_max) result(my_istat)
      implicit none
      character(len=*),intent(in) :: my_inname_S,my_name_S
      real,pointer :: my_data(:,:,:)
      integer :: my_istat,my_nk_max
      !**/
      logical,parameter :: NOPRINT = .false.
      character(len=32) :: hgrid_S,name_S
      integer :: minijki(3),maxijki(3),minijkg(3),maxijkg(3),k0,kn,k,gid,i0,j0,lni,lnj
      real,pointer :: gmmdata3d(:,:,:),gmmdata2d(:,:)
      !---------------------------------------------------------------------
      nullify(gmmdata2d,gmmdata3d)
      my_istat = gmmx_data(my_name_S,gmmdata2d,NOPRINT)
      if (.not.(RMN_IS_OK(my_istat) .and. associated(gmmdata2d))) then
         my_istat = gmmx_data(my_name_S,gmmdata3d,NOPRINT)
         if (.not.(RMN_IS_OK(my_istat) .and. associated(gmmdata3d))) then
            call msg(MSG_ERROR,'(dyn_input) Problem getting GMM ptr for var: '//trim(my_inname_S)//' : '//trim(my_name_S))
            nullify(gmmdata2d,gmmdata3d)
            return
         endif
      endif
      name_S = my_name_S
      my_istat = gmmx_meta(name_S,F_hgrid_S=hgrid_S)
      my_istat = hgrid_wb_get(hgrid_S,gid,i0,j0,lni,lnj)
      minijkg(1:2) = (/1,1/)
      maxijkg(1:2) = (/lni,lnj/)
      if (associated(gmmdata2d)) then
         minijkg(3) = 1
         maxijkg(3) = 1
      else
         minijkg(3) = lbound(gmmdata3d,3)
         maxijkg(3) = ubound(gmmdata3d,3)
      endif

      minijki = lbound(my_data)
      maxijki = ubound(my_data)
      !TODO: k0g = 1 ; if (ip1a/=surf.or.zta>=0) k0g=get_k(ip1list,ip1a)
      k0 = max(max(minijki(3),minijkg(3)),1)
      kn = max(min(maxijki(3),maxijkg(3)),k0)
      if (any(minijki(1:2) /= minijkg(1:2)) .or. &
           any(maxijki(1:2) /= maxijkg(1:2)) &
!!$           .or. k0 > minijkg(3) .or. kn < maxijkg(3) &
           ) then
         my_istat = RMN_ERR
         call msg(MSG_ERROR,'(dyn_input) size mismatch: '//trim(my_inname_S)//' : '//trim(my_name_S))
         return
      endif

      call msg(MSG_INFOPLUS,'(dyn_input) Copy: IN='//trim(my_inname_S)//' > GMM='//trim(my_name_S))
      if (associated(gmmdata2d)) then
         gmmdata2d(1:lni,1:lnj) = my_data(1:lni,1:lnj,1)
      else
!!$         gmmdata3d(1:lni,1:lnj,k0:kn) = my_data(1:lni,1:lnj,k0:kn)
!!$            k0 = lbound(gmmdata3d,3)
            kn = ubound(gmmdata3d,3)
            k0 = max(lbound(gmmdata3d,3),kn-my_nk_max+1)
         do k = k0,kn
            gmmdata3d(1:lni,1:lnj,k) = my_data(1:lni,1:lnj,1)
         enddo
      endif
      !TODO: if halox,y > 0: halo_xch on gmmdata2d/3d
      !---------------------------------------------------------------------
      return
   end function priv_copy


   !>
   function dyn_simple_transform(my_inname_S,my_data) result(my_istat)
      implicit none
      character(len=*),intent(in) :: my_inname_S
      real,pointer :: my_data(:,:,:)
      integer :: my_istat
      !**/
      character(len=4) :: inname2_S
      integer :: istat
      !---------------------------------------------------------------------
      my_istat = RMN_OK
      inname2_S = my_inname_S
      istat = clib_tolower(inname2_S)
      select case(inname2_S(1:2))
      case('p0') !# convert from mb to Pa
         my_data = min(max(P0MIN,my_data * MB2PA),P0MAX)
      case('gz') !# convert from DAM to m2/s2
         my_data = my_data * DAM2M * GRAV
      case('tt') !# convert from C to K
         my_data = my_data + TCDK
      !case('hu') !# KG/KG
      !case('hr') !# %
      case('uu') !# convert from kt to m/s
         my_data = my_data * KNAMS
      case('vv') !# convert from kt to m/s
         my_data = my_data * KNAMS
      !case('ww') !# Pa/s
      case default
         return
      end select
      call msg(MSG_INFOPLUS,'(dyn_input) simple_transform '//trim(inname2_S))
      !---------------------------------------------------------------------
      return
   end function dyn_simple_transform


   !TODO: should be moved into dyn_init or something (need phy_init done before though)
   !>
   function dyn_create_vars(F_step) result(F_istat)
      implicit none
      !@objective
      !@arguments
      integer,intent(in) :: F_step
      !@return
      integer :: F_istat
   !**/
      logical,save :: is_init_L = .false.
      integer,parameter :: NVARMAX = 64
      integer,parameter :: NVARLIST = 5
!!$      character(len=32),parameter :: HGRID = "HGRID=local#+h ;"
      character(len=32),parameter :: HGRID = "HGRID=local# ;"
      character(len=128),parameter :: VARLIST(NVARLIST) = (/&
           "VN=PW_GZ:P ; "//trim(HGRID)//" VGRID='ref-m'; in=GZ ; ON=GZ   ;VD='Geopotential on momentum levels [m^2/s^2]' ; VB=g;          ", &
           "VN=TR/HR:P ; "//trim(HGRID)//" VGRID='ref-t'; in=HR ; ON=HR   ;VD='Relative humidity [%]'              ; VB=g;          ", &
           "VN=MFBR ; "//trim(HGRID)//" VGRID='surf' ; in=MFBR; ON=MFBR ;VD='Filtered Terrain Elevetion [m] from Analisys'; VB=g;   ", &
           "VN=MF   ; "//trim(HGRID)//" VGRID='surf' ; in=MF ; ON=MF ;VD='Filtered Terrain Elevetion [m] at model resolution'; VB=g;", &
           "VN=P0   ; "//trim(HGRID)//" VGRID='surf' ; in=P0 ; ON=P0   ;VD='Surface Pressure [Pa] from Analisys'; VB=g;          " &
           /)
      character(len=128),parameter :: VARDESC_FMT = &
           "('VN=',a,' ; "//trim(HGRID)//" VGRID=',a,' ;  in=',a,' ; ON=',a,' ;VD=',a,'; VB=g;')"
      integer :: istat,nvars,ivar,idx,n
      character(len=GMM_MAXNAMELENGTH) :: vgrid_S
      character(len=256) :: vardesc_S,desc_S
      type(phymeta), pointer :: mymetalist(:)
      !---------------------------------------------------------------------
      call msg(MSG_DEBUG,'(dyn_input) dyn_create_vars [BEGIN]')
      F_istat = RMN_OK
      if (is_init_L) return
      is_init_L = .true.
      if (F_step > 0) return

      nullify(mymetalist)
!!$      nvars = phy_getmeta(mymetalist,' ',F_npath='V',F_bpath='D',F_maxmeta=512,F_quiet=.true.,F_shortmatch=.true.)
      nvars = phy_getmeta(mymetalist,' ',F_npath='V',F_bpath='D',F_maxmeta=512,F_quiet=.true.)
      if (nvars <= 0) then
         call msg(MSG_ERROR,'(dyn_input) Problem getting Phy D-bus var list in dyn_create_vars')
         F_istat = RMN_ERR
         return
      endif
      do ivar = 1,nvars
         
         if (mymetalist(ivar)%init == 0) cycle
         vgrid_S = 'surf'
         if ((mymetalist(ivar)%nk * mymetalist(ivar)%fmul) > 1) then
            vgrid_S = 'ref-m'
            if (mymetalist(ivar)%stag > 0) vgrid_S = 'ref-t'
         endif
!!$         !#TODO: check this exception in 4.7, 4.8
!!$         !# Note: Special case since this var is 2d in DYNBUS
!!$         if (any(mymetalist(ivar)%vname == (/'pw_pm:m','PW_PM:M'/))) &
!!$              vgrid_S = 'ref-m'

         if (mymetalist(ivar)%iname /= ' ') mymetalist(ivar)%oname = mymetalist(ivar)%iname
         n = len_trim(mymetalist(ivar)%vname)
         if (mymetalist(ivar)%vname(n-1:n) == ',w') mymetalist(ivar)%vname = mymetalist(ivar)%vname(1:n-2)

         desc_S = ' '
         write(vardesc_S,VARDESC_FMT) trim(mymetalist(ivar)%vname),trim(vgrid_S),trim(mymetalist(ivar)%iname),trim(mymetalist(ivar)%oname),trim(desc_S)
         F_istat = min(gmmx_new(vardesc_S,GMM_FLAG_RSTR+GMM_FLAG_IZER),F_istat)

      enddo
      deallocate(mymetalist,stat=istat)

      do ivar = 1,NVARLIST
         F_istat = min(gmmx_new(VARLIST(ivar),GMM_FLAG_RSTR+GMM_FLAG_IZER),F_istat)
      enddo
      call msg(MSG_DEBUG,'(dyn_input) dyn_create_vars [END]')
      !---------------------------------------------------------------------
      return
   end function dyn_create_vars


end module dyn_input_mod

