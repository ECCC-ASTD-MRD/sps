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
function dyn_output_callback(F_step,F_name_s,F_outname_s,F_data3d,F_lijk,F_uijk) result(F_istat)
   use gmmx_mod
   implicit none
   !@objective
   !@arguments
   integer,intent(in) :: F_step,F_lijk(3),F_uijk(3)
   character(len=*),intent(inout) :: F_name_s    !VN in GMMX
   character(len=*),intent(inout) :: F_outname_s !ON in GMMX
   real,intent(inout) :: F_data3d(F_lijk(1):F_uijk(1),F_lijk(2):F_uijk(2),F_lijk(3):F_uijk(3))
   !@return
   integer :: F_istat
   !@author Stephane Chamberland, 2012-01
   !@description
   !  The callback function is called twice by output_writestep
   !  1) input:   name_s=' ', outname_s/=' '
   !     output:  name_s, outname_s
   !     return:  istat = RMN_ERR, 0 ,1
   !              return 0 if next call to F_callback will NOT modify the field
   !              return 1 if next call to F_callback will modify the field
   !     ignored: data3d, lijk, uijk
   !     action:  callback can fill a gmmx var with values 
   !              then return the name_s/outname_s to find it
   !  2) input:   name_s/=' ', outname_s/=' ', data3d
   !     output:  data3d
   !     return:  istat = RMN_ERR, 0, 1
   !              return 0 if ok to convert units for output with vardict
   !              return 1 to skip unit conversion (var ready to write as is)
   !     ignored: 
   !     action:  callback can modify the data (change units...)
   !*@/
#include <arch_specific.hf>
#include <rmnlib_basics.hf>
#include <clib_interface_mu.hf>
#include <msg.h>
   include "thermoconsts.inc"
   character(len=4),parameter :: OUTLIST(5) = (/ &
        'p0','gz','tt','uu','vv'/)
   real,parameter :: PA2MB =  0.01
   real,parameter :: M2DAM =  0.1
   character(len=4) :: outname_S
   integer :: istat,k
   real,pointer :: mf(:,:,:)
   !----------------------------------------------------------------------
   F_istat = 0 !# RMN_OK
   outname_S = F_outname_s
   istat = clib_tolower(outname_S)
   if (F_name_s == ' ') then
      if (any(outname_S == OUTLIST)) F_istat = 1
      return !# Note: nothing to do on 1st call (mode 1)
   endif

   select case(outname_S)
   case('p0  ') !# convert from Pa to mb
      F_data3d = F_data3d * PA2MB
   case('gz  ') !# convert from m2/s2 AGL to DAM ASL
      F_istat = gmmx_data('MF',mf)
      if (.not.RMN_IS_OK(F_istat)) then
         call  msg(MSG_WARNING,'(dyn_output_callback) Cannot transform GZ, MF not avail: '//trim(F_name_S)//' (ON='//trim(outname_S)//')')
         return
      endif
      do k=F_lijk(3),F_uijk(3)
         F_data3d(:,:,k) =  M2DAM * (mf(:,:,1) + (F_data3d(:,:,k)/ GRAV))
      enddo
   case('tt  ') !# convert from K to C
      F_data3d = F_data3d - TCDK
   !case('hu') !# KG/KG
   !case('hr') !# %
   case('uu  ') !# convert from m/s to kt
      F_data3d = F_data3d / KNAMS
   case('vv  ') !# convert from m/s to kt
      F_data3d = F_data3d / KNAMS
      !case('ww') !# Pa/s
   case default
      return
   end select
   call msg(MSG_INFOPLUS,'(dyn_output_callback) '//trim(outname_S))
   !----------------------------------------------------------------------
   return
end function dyn_output_callback

