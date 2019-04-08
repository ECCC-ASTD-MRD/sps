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
function yyg_checkrot2(Grd_xlat1,Grd_xlon1,Grd_xlat2,Grd_xlon2) result(F_istat)
   implicit none
   !@objective Compute Yang grid rotation form Yin grid ones
   !@arguments
   real,intent(in) :: Grd_xlat1,Grd_xlon1,Grd_xlat2,Grd_xlon2
   !@author V. Lee/A. Qaddouri - April 2011
   !@revision
   ! v4_40 - Qaddouri/Lee     - initial version
   ! v4_50 - Desgagne M.      - only retain test on grid rotation
   !@return
   integer :: F_istat
!*@/
#include <arch_specific.hf>
#include <rmnlib_basics.hf>
#include <msg.h>
   !-------------------------------------------------------------------
   F_istat = RMN_OK

   if (Grd_xlat1 < 0. .and. Grd_xlat2 < 0. .and. Grd_xlon2 > Grd_xlon1) then
      call msg(MSG_ERROR,'(yyg_checkrot) Grd_xlat1,Grdxlat2 < 0.0 and Grd_xlon2 > Grd_xlon1')
      F_istat = RMN_ERR
   else if (Grd_xlat1 >= 0. .and. Grd_xlat2 >= 0. .and. Grd_xlon1 > Grd_xlon2) then
      call msg(MSG_ERROR,'(yyg_checkrot) Grd_xlat1,Grd_xlat2 >= 0.0 and Grd_xlon1 > Grd_xlon2')
      F_istat = RMN_ERR
   endif
   !-------------------------------------------------------------------
   return
end function yyg_checkrot2
