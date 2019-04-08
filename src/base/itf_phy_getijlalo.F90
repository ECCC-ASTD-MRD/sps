!---------------------------------- LICENCE BEGIN -------------------------------
! GEM - Library of kernel routines for the GEM numerical atmospheric model
! Copyright (C) 1990-2010 - Division de Recherche en Prevision Numerique
!                       Environnement Canada
! This library is free software; you can redistribute it and/or modify it
! under the terms of the GNU Lesser General Public License as published by
! the Free Software Foundation, version 2.1 of the License. This library is
! distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
! without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
! PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
! You should have received a copy of the GNU Lesser General Public License
! along with this library; if not, write to the Free Software Foundation, Inc.,
! 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
!---------------------------------- LICENCE END ---------------------------------
!/@*
subroutine itf_phy_getijlalo (F_ig,F_jg,F_lat,F_lon,F_il,F_jl,F_MISSING,F_offset)
   use ezgrid_mod
   use hgrid_wb
   implicit none
#include <arch_specific.hf>
   !@arguments
   integer,intent(inout) :: F_ig,F_jg
   real,   intent(inout) :: F_lat,F_lon
   integer,intent(out)   :: F_il,F_jl
   integer,intent(in)    :: F_MISSING,F_offset
   !*@/
#include <rmnlib_basics.hf>
   logical,save :: init_L = .false.
   integer,save :: grid_id=0,l_i0,l_j0,l_ni,l_nj,G_ni,G_nj
   real,pointer,dimension(:,:),save :: latg,long

   integer :: istat,G_i0,G_j0,numi,numj,i,j
   real(RDOUBLE) :: xyz1(3),xyz2(3)
   real :: lat,lon,difmin,c
   !     ---------------------------------------------------------------
   if (.not.init_L) then
      init_L = .true.
      istat = hgrid_wb_get('full',grid_id,G_i0,G_j0,G_ni,G_nj)
      istat = hgrid_wb_get('local#',grid_id,l_i0,l_j0,l_ni,l_nj)
      nullify(latg,long)
      istat = ezgrid_latlon(grid_id,latg,long,.false.,EZGRID_0_360)
   endif

   if ((F_ig.eq.F_MISSING).or.(F_jg.eq.F_MISSING)) then

      
      lat = F_lat
      lon = amod(F_lon+360.0,360.0)
      call llacar(xyz1,lon,lat,1,1)
      difmin= 9999999.
      numi= 1
      numj= 1

      do j= 1, G_nj
         do i= 1, G_ni
            call llacar(xyz2,long(i,j),latg(i,j),1,1)
            xyz2(1) = xyz1(1)-xyz2(1)
            xyz2(2) = xyz1(2)-xyz2(2)
            xyz2(3) = xyz1(3)-xyz2(3)
            c = sqrt( xyz2(1)**2 + xyz2(2)**2 + xyz2(3)**2 ) 
            if ( c .lt. difmin ) then
               difmin= c
               numi  = i
               numj  = j
            endif
         enddo
      enddo

   else

      numi= min(G_ni,max(1,F_ig))
      numj= min(G_nj,max(1,F_jg))

   endif

   F_ig = numi - F_offset
   F_jg = numj - F_offset
   F_il = numi - l_i0 + 1
   F_jl = numj - l_j0 + 1
   F_lat= latg(numi,numj)
   F_lon= long(numi,numj)

   if ( (F_il.lt.1).or.(F_il.gt.l_ni) .or. &
        (F_jl.lt.1).or.(F_jl.gt.l_nj) ) then
      F_il= F_MISSING
      F_jl= F_MISSING
   endif
   !     ---------------------------------------------------------------
   return
end subroutine itf_phy_getijlalo

