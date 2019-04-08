!--------------------------------------------------------------------------
! This is free software, you can use/redistribute/modify it under the terms of
! the EC-RPN License v2 or any later version found (if not provided) at:
! - http://collaboration.cmc.ec.gc.ca/science/rpn.comm/license.html
! - EC-RPN License, 2121 TransCanada, suite 500, Dorval (Qc), CANADA, H9P 1J3
! - service.rpn@ec.gc.ca
! It is distributed WITHOUT ANY WARRANTY of FITNESS FOR ANY PARTICULAR PURPOSE.
!-------------------------------------------------------------------------- 

!/@*
module dyn_grid_mod
   implicit none
   private
   !@objective 
   !@author Stephane Chamberland, July 2008
   !@revisions
   !  2012-02, Stephane Chamberland: RPNPhy offline
   !@public_functions
   public :: dyn_grid_init,dyn_grid_post_init,dyn_lat_lon,dyn_dxdy
   !@public_params
   !@public_vars
   character(len=64),public,save :: Grd_typ_S
   integer,public,save :: Grd_bsc_base,Grd_bsc_ext1,Grd_bsc_adw,Grd_extension
   integer,public,save :: Grd_ni,Grd_nj,Grd_nila,Grd_njla,Grd_maxcfl
   integer,public,save :: Grd_iref,Grd_jref
   real,public,save :: grd_dx,grd_dy,Grd_dxmax,Grd_dymax,Grd_overlap
   real,public,save :: Grd_latr,Grd_lonr,Grd_xlon1,Grd_xlat1,Grd_xlon2,Grd_xlat2
   logical,public,save :: Grd_yy_L,Grd_gauss_L,G_islam_L,G_isuniform_L

   integer,public,save :: G_ni,G_nj,G_halox,G_haloy,G_ngrids,G_igrid,Grd_left,Grd_belo,G_grid_id

   logical,public,save :: G_periodx,G_periody
   real,public,save :: Grd_x0,Grd_y0,Grd_xl,Grd_yl
!*@/
#include <arch_specific.hf>
#include <rmnlib_basics.hf>
#include <clib_interface_mu.hf>
#include <WhiteBoard.hf>
#include <msg.h>
   include "thermoconsts.inc"

   character(len=*),parameter :: WB_GRID_SEC = 'grid_cfgs/'
   integer,parameter :: IGRID_YIN = 0
   integer,parameter :: IGRID_YANG = 1

   logical,save :: m_init_L = .false., m_init2_L = .false.
   real(RDOUBLE),pointer,save :: m_xgi_8(:,:), m_ygi_8(:,:) !NOTE: needs to be 2D to support Y/L grids

contains

   !/@*
   function dyn_grid_init(F_ni,F_nj,F_halox,F_haloy,F_periodx,F_periody,F_grid_id) result(F_istat)
      implicit none
      !@objective Provide grid size info for the dyn grid/tile
      !@arguments
      integer,intent(out) :: F_ni,F_nj           !- Dyn Tile Grid dims
      integer,intent(out) :: F_halox,F_haloy     !- Dyn Tile Halo Dims
      logical,intent(out) :: F_periodx,F_periody !- Dyn Grid Periodicity
      integer,intent(out) :: F_grid_id           !- ezscing grid id
      !@return
      integer :: F_istat
      !@author Stephane Chamberland, July 2008
      !@revisions
      !  2012-02, Stephane Chamberland: RPNPhy offline
   !*@/
      integer,external :: msg_getUnit,yyg_checkrot2
      real,pointer :: xgi(:,:), ygi(:,:)
      real(RDOUBLE) :: x0_8,y0_8,xl_8,yl_8,yan_xlat1_8, yan_xlon1_8, yan_xlat2_8, yan_xlon2_8,yin_xlat1_8, yin_xlon1_8, yin_xlat2_8, yin_xlon2_8,delta_8
      integer :: istat,msgUnit,ierx,iery,gridid,ig1,ig2,ig3,ig4,hx,hy
      character(len=256) :: tmp_S
      !---------------------------------------------------------------------
      call msg(MSG_DEBUG,'[BEGIN] dyn_grid_init')
      F_istat = RMN_OK
      if (m_init_L) return
      m_init_L = .true.

      F_istat = wb_get(WB_GRID_SEC//'Grd_typ_S',Grd_typ_S)
      if (.not.RMN_IS_OK(F_istat)) then
         call msg(MSG_ERROR,'(dyn_grid) Unable to get Grd_typ_S from WB')
         return
      endif
      Grd_typ_S = adjustl(Grd_typ_S)
      istat = clib_toupper(Grd_typ_S)
      
      Grd_yy_L = .false.
      G_islam_L = .false.
      G_isuniform_L = .false.
      Grd_bsc_base = 0  !# 5
      Grd_bsc_ext1 = 0  !# 3
      Grd_bsc_adw = 0
      Grd_extension = 0
      Grd_x0 =   0.0 
      Grd_xl = 360.0
      Grd_y0 = -90.0
      Grd_yl =  90.0
      F_istat = wb_get(WB_GRID_SEC//'Grd_ni',Grd_ni)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_nj',Grd_nj),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_nila',Grd_nila),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_njla',Grd_njla),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_maxcfl',Grd_maxcfl),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'grd_dx',grd_dx),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'grd_dy',grd_dy),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'grd_dxmax',grd_dxmax),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'grd_dymax',grd_dymax),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_iref',Grd_iref),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_jref',Grd_jref),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_latr',Grd_latr),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_lonr',Grd_lonr),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_xlon1',Grd_xlon1),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_xlat1',Grd_xlat1),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_xlon2',Grd_xlon2),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_xlat2',Grd_xlat2),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_overlap',Grd_overlap),F_istat)
      F_istat = min(wb_get(WB_GRID_SEC//'Grd_gauss_L',Grd_gauss_L),F_istat)

      if (.not.RMN_IS_OK(F_istat)) then
         call msg(MSG_ERROR,'(dyn_grid) Unable to get Grid def from WB')
         return
      endif

      istat = wb_get('ptopo/ngrids',G_ngrids)
      istat = min(wb_get('ptopo/igrid',G_igrid),istat)
      if (.not.RMN_IS_OK(F_istat)) then
         call msg(MSG_WARNING,'(dyn_grid) Unable to get Grid index from WB, assuming only one grid ')
         G_ngrids = 1
         G_igrid  = 0
      endif

      if ((Grd_typ_S == 'GY' .and. G_ngrids /= 2) .or. (Grd_typ_S /= 'GY' .and. G_ngrids /= 1)) then
         call msg(MSG_ERROR,'(dyn_grid) Wrong number of RPN_COMM grids for Grd_typ_S='//trim(Grd_typ_S))
         F_istat = RMN_ERR
         return
      endif

      hx=0 ; hy=0
      SEL_GorL: select case(Grd_typ_S(1:1))

         !TODO-later: implement case(Grd_typ_S=from_file)

      case('G')                             ! Global grid

         SEL_GTYPE: select case (Grd_typ_S(2:2))
         case('U')             ! Uniform
            Grd_nila = Grd_ni
            Grd_njla = Grd_nj
         case('Y')             ! Yin-Yang
            Grd_yy_L = .true.
            G_islam_L = .true.
            F_istat = yyg_checkrot2(Grd_xlat1,Grd_xlon1,Grd_xlat2,Grd_xlon2)
            if (.not.RMN_IS_OK(F_istat)) then
               call msg(MSG_ERROR,'(dyn_grid) Wrong GY grid rotation config')
               return
            endif
            IF_YANG: if (G_igrid == IGRID_YANG) then
               yin_xlat1_8 = dble(Grd_xlat1)
               yin_xlon1_8 = dble(Grd_xlon1)
               yin_xlat2_8 = dble(Grd_xlat2)
               yin_xlon2_8 = dble(Grd_xlon2)
               call yyg_yangrot( &
                    yin_xlat1_8, yin_xlon1_8, yin_xlat2_8, yin_xlon2_8, &
                    yan_xlat1_8, yan_xlon1_8, yan_xlat2_8, yan_xlon2_8)
               Grd_xlat1 = sngl(yan_xlat1_8)
               Grd_xlon1 = sngl(yan_xlon1_8)
               Grd_xlat2 = sngl(yan_xlat2_8)
               Grd_xlon2 = sngl(yan_xlon2_8)
               istat = wb_put(WB_GRID_SEC//'Grd_xlon1',Grd_xlon1)
               istat = wb_put(WB_GRID_SEC//'Grd_xlat1',Grd_xlat1)
               istat = wb_put(WB_GRID_SEC//'Grd_xlon2',Grd_xlon2)
               istat = wb_put(WB_GRID_SEC//'Grd_xlat2',Grd_xlat2)
            endif IF_YANG
            Grd_dxmax=370.0
            Grd_dymax=370.0
            Grd_nila = Grd_ni
            Grd_njla = Grd_nj
            Grd_maxcfl    = max(1,Grd_maxcfl)
            Grd_bsc_adw   = 0   !# Grd_maxcfl  + Grd_bsc_base
            Grd_extension = 0   !# Grd_bsc_adw + Grd_bsc_ext1
            Grd_ni   = Grd_ni   + 2*Grd_extension
            Grd_nj   = Grd_nj   + 2*Grd_extension
            Grd_x0 =   45.0 - 3.0*Grd_overlap
            Grd_xl =  315.0 + 3.0*Grd_overlap
            Grd_y0 = -45.0  -     Grd_overlap
            Grd_yl =  45.0  +     Grd_overlap
            delta_8  = (dble(Grd_xl)-dble(Grd_x0))/(Grd_nila-1)
            Grd_x0 = Grd_x0 - Grd_extension*delta_8
            Grd_xl = Grd_xl + Grd_extension*delta_8
            delta_8  = (dble(Grd_yl)-dble(Grd_y0))/(Grd_njla-1)
            Grd_y0 = Grd_y0 - Grd_extension*delta_8
            Grd_yl = Grd_yl + Grd_extension*delta_8

        case('V')             ! Variable resolution
            if (Grd_nila*Grd_njla*Grd_dx*Grd_dy == 0) then
               call msg(MSG_ERROR,'(dyn_grid) Verify Grd_nila, Grd_njla, Grd_dx , Grd_dy in grid_cfgs')
               F_istat = RMN_ERR
            endif
         case default
            call msg(MSG_ERROR,'(dyn_grid) Unrecognize Grd_typ_S in grid_cfgs: '//trim(Grd_typ_S))
            F_istat = RMN_ERR
         end select SEL_GTYPE

      case('L')                             ! Limited area grid

         G_islam_L = .true.
         SEL_LTYPE: select case(Grd_typ_S(2:2))
         case('U')             ! Uniform
            Grd_maxcfl    = max(1,Grd_maxcfl)
            Grd_bsc_adw   = 0   !# Grd_maxcfl  + Grd_bsc_base
            Grd_extension = 0   !# Grd_bsc_adw + Grd_bsc_ext1
            Grd_ni   = Grd_ni   + 2*Grd_extension
            Grd_nj   = Grd_nj   + 2*Grd_extension
            Grd_iref = Grd_iref +   Grd_extension
            Grd_jref = Grd_jref +   Grd_extension
            Grd_nila = Grd_ni
            Grd_njla = Grd_nj
            Grd_x0   = Grd_lonr - (Grd_iref-1) * Grd_dx
            Grd_y0   = Grd_latr - (Grd_jref-1) * Grd_dy
            Grd_xl   = Grd_x0   + (Grd_ni  -1) * Grd_dx
            Grd_yl   = Grd_y0   + (Grd_nj  -1) * Grd_dy
            if (Grd_dx*Grd_dy == 0.) then
               call msg(MSG_ERROR,'(dyn_grid) Verify Grd_dx, Grd_dy in grid_cfgs')
               F_istat = RMN_ERR
            endif
            if (Grd_iref < 1 .or. Grd_iref > Grd_ni .or. &
                 Grd_jref < 1.or.Grd_jref > Grd_nj) then
               call msg(MSG_ERROR,'(dyn_grid) Verify Grd_iref, Grd_jref (out of range [1:Grd_ni], [1:Grd_nj]) ')
               F_istat = RMN_ERR
            endif
            if (Grd_x0 < 0.) Grd_x0 = Grd_x0 + 360.
            if (Grd_xl < 0.) Grd_xl = Grd_xl + 360.
            if (Grd_x0 < 0. .or. Grd_y0 < -90. .or. &
                 Grd_xl > 360. .or. Grd_yl > 90.) then
               write(tmp_S,'(4f10.3)') Grd_x0,Grd_y0,Grd_xl,Grd_yl
               call msg(MSG_ERROR,'(dyn_grid) Wrong grid config, verify grid_cfgs; x0,y0,x1,y1 = '//trim(tmp_S))
                F_istat = RMN_ERR
            endif
         case default
            call msg(MSG_ERROR,'(dyn_grid) Unrecognize Grd_typ_S in grid_cfgs: '//trim(Grd_typ_S))
            F_istat = RMN_ERR
         end select SEL_LTYPE

      end select SEL_GorL

      if (nint(360./max(tiny(1.),Grd_dxmax)) > Grd_ni+1 .or. &
          nint(180./max(tiny(1.),Grd_dymax)) > Grd_nj+1) then
         call msg(MSG_ERROR,'(dyn_grid) Inconsistent Grd_ni, Grd_nj, Grd_dxmax & Grd_dymax values, verify grid_cfgs')
         F_istat = RMN_ERR
      endif

      if (.not.RMN_IS_OK(F_istat)) return

      msgUnit = msg_getUnit(MSG_INFO)

      allocate(&
           m_xgi_8(Grd_ni,1), &
           m_ygi_8(1,Grd_nj), &
           xgi(1-hx:Grd_ni+hx,1), &
           ygi(1,1-hy:Grd_nj+hy), &
           stat=istat)

      x0_8 = dble(Grd_x0)
      y0_8 = dble(Grd_y0)
      xl_8 = dble(Grd_xl)
      yl_8 = dble(Grd_yl)
      !# inout: Grd_dx, Grd_dy
      !# out  : m_xgi_8, m_ygi_8,Grd_left,Grd_belo,G_isuniform_L
      call set_gemHgrid3(m_xgi_8, m_ygi_8, Grd_ni, Grd_nj, Grd_dx, Grd_dy, & 
           x0_8, xl_8, Grd_left, y0_8, yl_8, Grd_belo, &
           Grd_nila, Grd_njla, Grd_dxmax, Grd_dymax,           &
           Grd_yy_L,Grd_gauss_L, G_islam_L, G_isuniform_L, &
           ierx, iery, (msgUnit >= 0))

      F_periodx = .not.G_islam_L
      F_periody = .false.

      xgi(1:Grd_ni,:) = m_xgi_8 ; ygi(:,1:Grd_nj) = m_ygi_8
      if (hx > 0) then
         if (F_periodx) then
            xgi(1-hx:0,:) = m_xgi_8(Grd_ni-hx+1:Grd_ni,:) - 360.
            xgi(Grd_ni+1:Grd_ni+hx,:) = m_xgi_8(1:1+hx-1,:) + 360.
         else
            call msg(MSG_ERROR,'(dyn_grid_init) non periodic grid with halo-x not yet implemented')
            F_istat = RMN_ERR
         endif
      endif
      if (hy > 0) then
         F_istat = RMN_ERR
         call msg(MSG_ERROR,'(dyn_grid_init) halyy >0 yet implemented')
      endif
      
      if (.not.RMN_IS_OK(F_istat)) then
         deallocate(xgi,ygi,stat=istat)
         return
      endif

      !TODO-later: check if ezscint take deg or rad (set_gemHgrid returns deg)

      call cxgaig('E',ig1,ig2,ig3,ig4,Grd_xlat1,Grd_xlon1,Grd_xlat2,Grd_xlon2)
      G_grid_id = ezgdef_fmem(Grd_ni+2*hx,Grd_nj+2*hy,'Z','E',ig1,ig2,ig3,ig4, xgi,ygi)

      deallocate(xgi,ygi,stat=istat)

      F_halox = hx
      F_haloy = hy
      F_ni = Grd_ni
      F_nj = Grd_nj
      F_grid_id = G_grid_id

!!$      print *,'(dyn_grid_init)',F_istat,F_ni,F_nj,F_halox,F_haloy,F_periodx,F_periody,F_grid_id ; call flush(6)
      call msg(MSG_DEBUG,'[END] dyn_grid_init')
      !---------------------------------------------------------------------
      return
   end function dyn_grid_init


   !/@*
   function dyn_grid_post_init(F_imin,F_imax,F_jmin,F_jmax,F_ni,F_nj) result(F_istat)
      implicit none
      !@objective Check dims and Compute grid point positions
      !@arguments
      integer, intent(in) :: F_imin,F_imax,F_jmin,F_jmax !- DynTile dims
      integer, intent(in) :: F_ni,F_nj                   !- Computational Dims
      !@return
      integer :: F_istat
      !@author Stephane Chamberland, July 2008
      !@revisions
      !  2012-02, Stephane Chamberland: RPNPhy offline
      !@description
      !  
   !*@/
      real, parameter :: epsilon_4 = 1.e-5

      integer :: istat,i,j,itmp
      real    :: rtmp
      real, pointer, dimension(:,:) :: lat,lon
!!$      type(gmm_metadata) :: gmmmeta
!!$      type(gmm_layout)   :: layout2d(4)
      character(len=256) :: tmp_S
      !---------------------------------------------------------------------
      F_istat = RMN_ERR
      if (.not.m_init_L) return

      F_istat = RMN_OK
      if (m_init2_L) return
      m_init2_L = .true.

      call msg(MSG_DEBUG,'[BEGIN] dyn_grid_post_init')

!!$      if (Grd_typ_S == 'GY') then
!!$         !TODO-later: define YinYang grid communicators
!!$         call msg(MSG_ERROR,'(dyn_grid) GY grid not yet supported')
!!$         F_istat = RMN_ERR
!!$         return
!!$      endif

!!$         !TODO-later: move this to drv_grid_mod::grid_init  since this the same for every dyn
!!$         !- Compute derived quantities.. not sure it must be done here
!!$         layout2d = GMM_NULL_LAYOUTS
!!$         layout2d(1) = gmm_layout(F_imin,F_imax,DYN_HALOXY,DYN_HALOXY,F_ni)
!!$         layout2d(2) = gmm_layout(F_jmin,F_jmax,DYN_HALOXY,DYN_HALOXY,F_nj)
!!$         F_istat = min(gmmmeta_encode(gmmmeta,layout2d,GMM_NO_FLAGS),F_istat)
!!$         nullify(lat)
!!$         nullify(lon)
!!$         F_istat = min(gmm_create('lat',lat,gmmmeta),F_istat)
!!$         F_istat = min(gmm_create('lon',lon,gmmmeta),F_istat)
!!$         F_istat = min(dyn_lat_lon(lat,lon),F_istat)
!!$
!!$         F_istat = min(dyn_comm_xch_halo2(F_ni,2,lat,lon),F_istat)


      call msg(MSG_DEBUG,'[END] dyn_grid_post_init')
      !---------------------------------------------------------------------
      return
   end function dyn_grid_post_init


   !/@*
   function dyn_lat_lon(lat,lon) result(F_istat)
      implicit none
      !@objective 
      !@arguments
      real,pointer,intent(out) :: lat(:,:),lon(:,:)
      !@return
      integer :: F_istat
      !@author Stephane Chamberland, 2008-08
      !@revisions
      !  2012-02, Stephane Chamberland: RPNPhy offline
      !@description
   !*@/
      integer :: i,j
      !---------------------------------------------------------------------
      F_istat = RMN_ERR
      if (.not.m_init2_L) return
!!$      F_istat = RMN_OK
      call msg(MSG_ERROR,'(dyn_grid) dyn_lat_lon not yet implemented')
      !TODO-later: dyn_lat_lon = ezgrid_latlon(gridid, lat,lon)
      !---------------------------------------------------------------------
      return
   end function dyn_lat_lon


   !/@*
   function dyn_dxdy(F_dxdy,F_i0,F_j0,F_ni,F_nj) result(F_istat)
      implicit none
      !@objective 
      !@arguments
      integer,intent(in) :: F_i0,F_j0,F_ni,F_nj
      real,pointer,intent(out) :: F_dxdy(:,:)
      !@return
      integer :: F_istat
      !@author Stephane Chamberland, 2008-08
      !@revisions
      !  2012-02, Stephane Chamberland: RPNPhy offline
      !@description
   !*@/
      integer :: i,j,gi,gj,gj0,gi2,gj2,gimax,gjmax,gi2max,gj2max,offi,offj
      real(RDOUBLE) :: deg2rad_8,hxu_8,hyv_8,cy_8,cte2_8,rayt_8
      !---------------------------------------------------------------------
      F_istat = RMN_ERR
      if (.not.m_init2_L) return

      !TODO-later: check F_dxdy dims
      !TODO-later: for Y grid (collection of points) DXDY needs to be read from file

      F_istat = RMN_OK
      offi = F_i0-1 ; offj = F_j0-1
      rayt_8 = dble(rayt) !# From thermoconsts.inc
      deg2rad_8 = acos(-1.D0)/180.D0
      cte2_8 = 0.5D0 * deg2rad_8 * rayt_8
      cte2_8 = cte2_8 * cte2_8
      gimax = size(m_xgi_8,1) ; gjmax = size(m_ygi_8,2)
      gi2max = size(m_ygi_8,1) ; gj2max = size(m_xgi_8,2)
      do j = 1,F_nj
         gj0 = offj+j
         gj = max(2,min(gj0,gjmax-1))
         gj2 = min(gj,gj2max)
         do i = 1,F_ni
            gi = offi+i
            gi = max(2,min(gi,gimax-1))
            gi2 = min(gi,gi2max)
            hxu_8 = m_xgi_8(gi+1,gj2)-m_xgi_8(gi-1,gj2)
            hyv_8 = m_ygi_8(gi2,gj+1)-m_ygi_8(gi2,gj-1)
            cy_8 = cos(deg2rad_8 * m_ygi_8(gi2,gj0))
            F_dxdy(i,j) = cte2_8 * hxu_8*hyv_8 * cy_8
         end do
      end do
      !---------------------------------------------------------------------
      return
   end function dyn_dxdy


   !==== Private functions =================================================


end module dyn_grid_mod

