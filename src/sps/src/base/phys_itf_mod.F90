!--------------------------------------------------------------------------
! This is free software, you can use/redistribute/modify it under the terms of
! the EC-RPN License v2 or any later version found (if not provided) at:
! - http://collaboration.cmc.ec.gc.ca/science/rpn.comm/license.html
! - EC-RPN License, 2121 TransCanada, suite 500, Dorval (Qc), CANADA, H9P 1J3
! - ec.service.rpn.ec@canada.ca
! It is distributed WITHOUT ANY WARRANTY of FITNESS FOR ANY PARTICULAR PURPOSE.
!-------------------------------------------------------------------------- 

!/@*
module phys_itf_mod
   use, intrinsic :: iso_fortran_env, only: REAL64, INT64
   use rmn_gmm
   use clib_itf_mod
   use wb_itf_mod
   use phy_itf
   use hgrid_wb
   use config_mod
   use cmcdate_mod
   use statfld_dm_mod
   use phy_output_mod, only: phy_output0, phy_output1_4
   use phys_prestep_mod
   implicit none
   private
   !@objective Interface to RPNPhy
   !@author Stephane Chamberland, 2012-02
   !@revisions
   !  2013-06 S.Chamberland: adapt to rpnphy 5.5 API
   !  2014-04 S.Chamberland: adapt to rpnphy 5.6 API
   !  2015-06 S.Chamberland: adapt to rpnphy 5.7 API
   !  2016-03 S.Chamberland: adapt to rpnphy 5.8 API
   !@public_functions
   public :: phys_config,phys_init,phys_input,phys_step,phys_output,phys_blocstats
   !@public_params
   !@public_vars
!*@/
!!!#include <arch_specific.hf>
#include <rmnlib_basics.hf>
#include <rmn/msg.h>

   character(len=*),parameter :: HGRID_S = 'local#'
   character(len=*),parameter :: HGRIDZ_S = 'localz'
   character(len=3),parameter :: OPT_GET = 'GET'
   character(len=3),parameter :: OPT_SET = 'SET'
   integer,parameter :: COMPATIBILITY_LVL = 20
   integer,parameter :: MAX_LEVELS = 1024
   integer,parameter :: PE_MASTER = 0

   character(len=RMN_PATH_LEN),save :: &
        geofilename_S = 'GEOPHY/Gem_geophy.fst',&
        config_S = '',&
        input_dir_S = ''

   logical,save :: m_init_L = .false. ,&
        m_init2_L = .false., &
        m_isphy_L = .false.
   integer,save :: m_msgUnit = RMN_ERR

   integer,save :: p_nk

   interface phys_output
      module procedure phy_output0
      module procedure phy_output1_4
   end interface

contains

   !/@*
   function phys_config(F_cfg_basename_S) result(F_istat)
      implicit none
      !@objective Read phy nml
      !@arguments
      character(len=*),intent(in) :: F_cfg_basename_S  !- Name of the config file [w/o extension]
      !@return
      integer :: F_istat
      !@author Stephane Chamberland, 2012-02
      !@revisions
   !*@/
      character(len=*),parameter :: NML_S = "physics_cfgs"
      integer,external :: msg_getUnit
      character(len=RMN_PATH_LEN) :: path_nml_S
      character(len=MSG_MAXLEN) :: msg_S
      integer :: istat
      !---------------------------------------------------------------------
      call msg(MSG_DEBUG,'[BEGIN] phys_config')
      F_istat = RMN_OK
      if (m_init_L) return
      m_init_L = .true.
      F_istat = RMN_ERR

      m_msgUnit = msg_getUnit(MSG_INFO)

      if (PHY_COMPATIBILITY_LVL /= COMPATIBILITY_LVL) then
         write(msg_S,'(a,i2,a,i2)') &
              '(phys) InCompatible Physic Interface; Need  level=',&
              COMPATIBILITY_LVL,'; Found physic Compat level=',PHY_COMPATIBILITY_LVL
         call msg(MSG_INFO,msg_S)
         return
      endif
      write(msg_S,'(a,i2,a)') '(phys) Compatibility level is OK: (level=',PHY_COMPATIBILITY_LVL,')'
      call msg(MSG_INFO,msg_S)

      istat = config_path(path_nml_S,F_cfg_basename_S)
      istat = clib_isfile(trim(path_nml_S))
      if (.not.RMN_IS_OK(istat)) then
         call msg(MSG_WARNING,'(phys) Config file not found: '//trim(path_nml_S))
      else
         call msg(MSG_INFO,'(phys) Reading Config: '//trim(path_nml_S)//'::'//trim(NML_S))
         F_istat = phy_nml(path_nml_S)
      endif

      if (F_istat /= PHY_OK) then
         call msg(MSG_INFO,'(phys) Config reading problem')
      else
         m_isphy_L = .true.

      endif

      call msg(MSG_DEBUG,'[END] phys_config')
      !---------------------------------------------------------------------
      return
   end function phys_config


   !/@*
   function phys_init(F_dateo_S,F_dt_8,F_step) result(F_istat)
      implicit none
      !@objective 
      !@arguments
      character(len=*),intent(in) :: F_dateo_S
      real(RDOUBLE),intent(in) :: F_dt_8
      integer,intent(in) :: F_step
      !@return
      integer :: F_istat
      !@author Stephane Chamberland, 2012-02
      !@revisions
   !*@/
      integer,parameter :: NK_MIN = 3
      integer :: err(12),idateo,istat,p_nk,G_ngrids
      real :: std_p_prof(MAX_LEVELS),sgo_tdfilter
      logical :: atm_external_L
      character(len=128) :: msg_S
      character(len=WB_MAXSTRINGLENGTH) :: input_type_S
      !---------------------------------------------------------------------
      call msg(MSG_DEBUG,'[BEGIN] phys_init')
      F_istat = RMN_ERR
      if (.not.m_init_L) return

      F_istat = RMN_OK
      if (m_init2_L) return
      m_init2_L = .true.
      if (.not.m_isphy_L) then
         call msg(MSG_INFO,'(phys) Initialisation OK, Nothing done, no Physic')
         return
      endif

      idateo = cmcdate_fromprint(F_dateo_S)
      err(:) = RMN_OK
      err(1) = wb_get('std_p_prof_m',std_p_prof,p_nk)
      if (RMN_IS_OK(err(1))) then
          if (p_nk < NK_MIN) then
              F_istat = RMN_ERR
              write(msg_S,'(a,i4,a,i2)') "(phys_init) Not enough levels, nk=",p_nk," <",NK_MIN
              call msg(MSG_ERROR,msg_S)
              return
          else
              call msg(MSG_DEBUG,'(phys_init) Number of levels ok')
          endif
      else
          write(msg_S,'(a)') "(phys_init) cannot wb_get std_p_prof_m "
          call msg(MSG_ERROR,msg_S)
          return
      endif

      err(2) = wb_get('path/input',input_dir_S)
      istat = wb_get('ptopo/ngrids',G_ngrids)
      if (RMN_IS_OK(istat) .and. G_ngrids > 1) then
           input_dir_S = trim(input_dir_S)//'/..'
      else
          call msg(MSG_DEBUG,'(phys_init) cannot wb_get ptopo/ngrids, G_ngrids will be set to 1')
      endif

      err(3) = wb_put('model/outout/pe_master',PE_MASTER)
      err(4) = phy_init( &
           input_dir_S, &
           idateo, real(F_dt_8), &
           HGRIDZ_S, HGRIDZ_S, &         !#TODO: dieze or Z grid?
           p_nk, std_p_prof(1:p_nk) )

      if (.not.RMN_IS_OK(err(4))) &
           call msg(MSG_ERROR,'(phys_init) Problem in phy_init')
      
      
      !check input_type
      err(9) = wb_get('phy/input_type', input_type_S)
      if (WB_IS_OK(err(9))) then
         call msg(MSG_DEBUG, 'phy/input_type: '//input_type_S)
         if (.not.(trim(input_type_S) == 'GEM_4.8')) then
            call msg(MSG_ERROR, "input_type='GEM_4.8' required in namelist physics_cfgs")
            err(9) = RMN_ERR
         endif
      else
         call msg(MSG_ERROR, '(phys_init) cannot wb_get phy/input_type')
         call msg(MSG_ERROR, "input_type='GEM_4.8' required in namelist physics_cfgs")
         err(9) = RMN_ERR
      endif

      !check fluvert (atm_external)
      err(10) = wb_get('phy/atm_external', atm_external_L)
      if (WB_IS_OK(err(10))) then
         if (.not. atm_external_L) then
            call msg(MSG_ERROR, "fluvert='SURFACE' required in namelist physics_cfgs")
            err(10) = RMN_ERR
         else
            call msg(MSG_DEBUG, "fluvert='SURFACE' detected namelist physics_cfgs: wb_get phy/atm_external=T")
         endif
      else
         call msg(MSG_ERROR, '(phys_init) cannot wb_get phy/atm_external')
         call msg(MSG_ERROR, "fluvert='SURFACE' required in namelist physics_cfgs")
      endif

      !check sgo_tdfilter
      err(11) = wb_get('phy/sgo_tdfilter', sgo_tdfilter)
      if (WB_IS_OK(err(11))) then
         if (.not.(sgo_tdfilter == -1.0) ) then
            call msg(MSG_ERROR, 'sgo_tdfilter = -1.0 required in namelist physics_cfgs')
            err(11) = RMN_ERR
         endif
      else
         call msg(MSG_ERROR, '(phys_init) cannot wb_get phy/sgo_tdfilter')
         call msg(MSG_ERROR, 'sgo_tdfilter = -1.0 required in namelist physics_cfgs')
      endif
      
      F_istat = minval(err(:))
      F_istat = min(priv_consis(),F_istat)
      F_istat = min(priv_geom(),F_istat)
      if (RMN_IS_OK(F_istat)) then
         call msg(MSG_INFO,'(phys) Initialisation OK')
      else
         call msg(MSG_ERROR,'(phys) Problem in Initialisation')
      endif
      call msg(MSG_DEBUG,'[END] phys_init')
      !---------------------------------------------------------------------
      return
   end function phys_init


   !/@*
   function phys_input(F_step) result(F_istat)
      implicit none
      !@objective 
      !@arguments
      integer,intent(in) :: F_step
      !@return
      integer :: F_istat
      !@author Stephane Chamberland, 2012-02
      !@revisions
   !*@/
      integer, external :: itf_prefold_opr,phy_gmm2phy2
      character(len=*),parameter :: INPUT_TABLE = 'physics_input_table'
      logical,save :: is_init_L = .false.
      character(len=RMN_PATH_LEN) :: config_dir0_S,pwd_S,msg_S
      !---------------------------------------------------------------------
      call msg(MSG_DEBUG,'[BEGIN] phys_input')
      F_istat = RMN_ERR
      if (.not.m_init2_L) return

      F_istat = RMN_OK
      write(msg_S,'(a,I5.5)') '(phys) Input Step=',F_step
      if (.not.m_isphy_L) then
         call msg(MSG_INFO,trim(msg_S)//' OK, Nothing done, no Physic')
         return
      endif
      call msg(MSG_INFO,trim(msg_S)//' Begin')

      IF_INIT: if (.not.is_init_L) then
         is_init_L = .true.
         F_istat = min(wb_get('path/config_dir0',config_dir0_S),F_istat)
         F_istat = min(config_cp2localdir(INPUT_TABLE,config_dir0_S),F_istat)
         F_istat = min(clib_getcwd(pwd_S),F_istat)
         config_S = trim(pwd_S)//'/'//INPUT_TABLE
      endif IF_INIT
      call collect_error(F_istat)
      if (.not.RMN_IS_OK(F_istat)) then
         call msg(MSG_ERROR,trim(msg_S)//' End with Problems in Init')
         return
      endif

      F_istat = min(phy_input1(itf_prefold_opr,F_step,config_S,input_dir_S,geofilename_S),F_istat)

      call collect_error(F_istat)
      if (RMN_IS_OK(F_istat)) then
         call msg(MSG_INFO,trim(msg_S)//' End OK')
      else
         call msg(MSG_ERROR,trim(msg_S)//' End with Problems')
      endif
      call msg(MSG_DEBUG,'[END] phys_input')
      !---------------------------------------------------------------------
      return
   end function phys_input


   !/@*
   function phys_step(F_step) result(F_istat)
      implicit none
      !@objective 
      !@arguments
      integer,intent(in) :: F_step
      !@return
      integer :: F_istat
      !@author Stephane Chamberland, 2012-02
      !@revisions
   !*@/
      character(len=MSG_MAXLEN) :: msg_S
      !---------------------------------------------------------------------
      call msg(MSG_DEBUG,'[BEGIN] phys_step')
      F_istat = RMN_ERR
      if (.not.m_init2_L) return

      F_istat = RMN_OK
      write(msg_S,'(a,I5.5)') '(phys) Step=',F_step
      if (.not.m_isphy_L) then
         call msg(MSG_INFO,trim(msg_S)//' OK, Nothing done, no Physic')
         return
      endif

      call msg(MSG_INFO,trim(msg_S)//' Begin')

      F_istat = phys_prestep(F_step)
      call collect_error(F_istat)

      if (RMN_IS_OK(F_istat)) then
         F_istat = phy_step(F_step,F_step)
         call collect_error(F_istat)
      endif

      if (RMN_IS_OK(F_istat)) then
         call msg(MSG_INFO,trim(msg_S)//' End OK')
      else
         call msg(MSG_ERROR,trim(msg_S)//' End with Problems')
      endif
      call msg(MSG_DEBUG,'[END] phys_step')
      !---------------------------------------------------------------------
      return
   end function phys_step


   !/@*
   subroutine phys_blocstats(F_step,F_by_levels_L)
      implicit none
      !@objective Stub
      !@arguments
      integer,intent(in) :: F_step
      logical,intent(in) :: F_by_levels_L
   !*@/
      integer,parameter :: STAT_PRECISION = 4
      integer,parameter :: NSTATMAX = 64
!!$      integer,parameter :: MAX_PARAMS = 8
!!$      integer,parameter :: BUSPAR_NIK=2
      integer,parameter :: STAT_NK_MAX = 2
      character(len=32),save :: stat_list_S(NSTATMAX)
      integer,save :: l_ijk(3) = (/0,0,0/)
      integer,save :: u_ijk(3) = (/0,0,0/)
      integer,save :: nstat = 0
      logical,save :: init_L = .false.
      character(len=MSG_MAXLEN) :: msg_S,name2_S
      real,pointer :: data3dr4(:,:,:)
      integer :: istat,ivar,grid_id,gi0,gj0,lni,lnj,hx,hy,k0,kn,k
      type(phymeta) :: mymeta

      !---------------------------------------------------------------------
      IF_INIT: if (.not.init_L) then
         istat = wb_get('sps_cfgs/stat_list_s',stat_list_S,nstat)
         istat = hgrid_wb_get(HGRID_S,grid_id,gi0,gj0,lni,lnj,hx,hy)
         if (.not.RMN_IS_OK(istat)) then
            call msg(MSG_ERROR,'(phys_blocstats) Problem getting grid info')
            nstat = 0
         else
            l_ijk(1:2) = (/1-hx,1-hy/) ; l_ijk(3) = 1
            u_ijk(1:2) = (/lni+hx,lnj+hy/) ; u_ijk(3) = 1
         endif
         init_L = .true.
      endif IF_INIT

      if (nstat <= 0) return

      write(msg_S,'(a,I5.5)') '---- (phys) Blocstat Step=',F_step
      call msg(MSG_INFO,trim(msg_S)//' [Begin] ------------')
      
      VARLOOP: do ivar=1,nstat
         if (stat_list_S(ivar) == '') cycle
         
         istat = phy_getmeta(mymeta,stat_list_S(ivar),F_quiet=.true.)
         if (.not.RMN_IS_OK(istat)) then
            call msg(MSG_INFOPLUS,'(phys_blocstats) Skipping var (not in bus): '//trim(stat_list_S(ivar))//')')
            cycle VARLOOP
         endif

         nullify(data3dr4)
         istat = phy_get(data3dr4,stat_list_S(ivar))
         if (.not.RMN_IS_OK(istat)) then
            call msg(MSG_INFOPLUS,'(phys_blocstats) Problem getting values from bus for: '//trim(stat_list_S(ivar)))
            cycle VARLOOP
         endif

         kn = size(data3dr4,dim=3)
!!$         k0 = max(1,kn-STAT_NK_MAX+1)
         k0 = 1
         if (F_by_levels_L) then
            do k=k0,kn
               write(name2_S,'(a,i3.3,a)') trim(stat_list_S(ivar))//'(',k,')'
               call statfld_dm(data3dr4(:,:,k),name2_S,F_step,'phy_blocstats',STAT_PRECISION) 
            enddo
         else
            call statfld_dm(data3dr4(:,:,k0:kn),stat_list_S(ivar),F_step,'phy_blocstats',STAT_PRECISION) 
         endif
      enddo VARLOOP

      call msg(MSG_INFO,trim(msg_S)//' [End]   ------------')
      !---------------------------------------------------------------------
      return
   end subroutine phys_blocstats


   !/@*
   function priv_consis() result(F_istat)
      implicit none
      !@objective Check option consistency
      !@return
      integer :: F_istat
   !*@/
      integer,parameter :: MAX_LEVELS = 1024
      real, parameter :: epsilon_4 = 1.e-5
      logical :: use_zua_zta_L
      real :: zua, zta, Lvl_list(MAX_LEVELS) , max_level
      integer :: nlvls
      !---------------------------------------------------------------------
      call msg(MSG_INFOPLUS,'(phys) Checking options consistency')
      F_istat = wb_get('itf_phy/zua',zua)
      F_istat = min(wb_get('itf_phy/zta',zta), F_istat)
      F_istat = min(wb_get('levels_cfgs/Lvl_list',Lvl_list,nlvls),F_istat)
      if (.not.RMN_IS_OK(F_istat)) then
         call msg(MSG_ERROR,'(phys_itf) Problem getting phy and levels cfgs to check options consistency')
         return
      endif

      use_zua_zta_L = (zua > epsilon_4 .or. zta > epsilon_4)
      if (use_zua_zta_L) then

         max_level = maxval(Lvl_list)
         if (max_level > epsilon_4) then
            call msg(MSG_ERROR,'(phys_itf) Incompatible sps cfg options: Can specify Lvl_list OR zua and zta, not BOTH')
            F_istat = RMN_ERR
         endif

      else 

         max_level = maxval(Lvl_list, mask=(Lvl_list<1.))
         if (max_level < epsilon_4) then
            call msg(MSG_ERROR,'(phys_itf) Incompatible cfg options: Must specify Lvl_list OR zua and zta')
            F_istat = RMN_ERR
         endif

      endif
      !---------------------------------------------------------------------
      return
   end function priv_consis


   !/@*
   function priv_geom() result(my_istat)
      implicit none
      integer :: my_istat
      !*@/
      integer, external :: gdll
      integer :: gid, istat
      real :: deg2rad
      real,pointer,dimension(:,:) :: dlat,dlon,tdmask
      type(gmm_metadata) :: mymeta
      !---------------------------------------------------------------------
      my_istat = RMN_OK

      nullify(dlat,dlon,tdmask)
      my_istat = min(hgrid_wb_gmmmeta(HGRIDZ_S,mymeta),my_istat)
      istat = gmm_create('DLAT',dlat,mymeta)
      istat = gmm_create('DLON',dlon,mymeta)
      istat = gmm_create('TDMASK',tdmask,mymeta)
      if (.not.(associated(dlat) .and. associated(dlon) .and. &
           associated(tdmask) )) then
         call msg(MSG_ERROR,'(phys_itf) geom - Problem getting gmm pointers')
         my_istat = RMN_ERR
         return
      endif

      my_istat = hgrid_wb_get(HGRIDZ_S,gid)
      if (RMN_IS_OK(my_istat)) my_istat = gdll(gid,dlat,dlon)
      if (.not.RMN_IS_OK(my_istat)) then
         call msg(MSG_ERROR,'(dyn_input_init) Problem computing Lat-lon')
         return
      endif
      deg2rad = acos(-1.)/180.
      dlat = deg2rad*dlat
      where(dlon >= 0)
         dlon = deg2rad*dlon
      elsewhere
         dlon = deg2rad*(dlon+360.)
      endwhere

      tdmask = 1.
      !---------------------------------------------------------------------
      return
   end function priv_geom

end module phys_itf_mod

