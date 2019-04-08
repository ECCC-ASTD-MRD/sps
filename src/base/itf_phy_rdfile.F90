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
subroutine itf_phy_rdfile2(F_fichier_S,F_read_cb,F_messg_s,F_mode)
   use iso_c_binding
   implicit none
   !@objective Reading a file for the physics package 
   !@arguments
   character(len=*),intent(in) :: F_fichier_S !# file name of input file
   character(len=*) :: F_messg_s
   integer :: F_mode
   external :: F_read_cb !# read call back routine (from physics)
   !@author M. Desgagne, Spring 2008
   !@revisions
   !2012-02, Stephane Chamberland: Extract from GEM (no gem's cdk)
   !*@/
#include <arch_specific.hf>
#include <rmnlib_basics.hf>
#include <clib_interface_mu.hf>
#include <WhiteBoard.hf>
#include <msg.h>
   include "rpn_comm.inc"
   integer,parameter :: MAX_NDIM = 1000
   integer,parameter :: MODE_ALL_PE = 1
   integer,parameter :: MODE_ALL_PE_LOCAL = 2
   integer,parameter :: MODE_P0_BCAST = 3

   integer, save :: ptopo_myproc = -1

   integer ::  istat,ierr

   character(len=RMN_PATH_LEN) :: filename_S,tmp_S,Path_input_S
   integer :: fileid,ilir,inbr
   integer :: dim(MAX_NDIM)
   integer :: bufnml(1000000)
   real,allocatable :: rbuf(:)
   !---------------------------------------------------------------------
   if (ptopo_myproc < 0) call rpn_comm_rank(RPN_COMM_GRID,ptopo_myproc,istat)
   istat = wb_get('path/input',Path_input_S)
   if (.not.RMN_IS_OK(istat)) istat = clib_getcwd(Path_input_S)

   istat = 0
   tmp_S = ''
   filename_S = trim(Path_input_S)//'/'//trim(F_fichier_S)

   IF_MASTER: if (Ptopo_myproc == RPN_COMM_MASTER) then
      ierr = clib_isfile(filename_S)
      if (RMN_IS_OK(ierr)) then
         ilir = wkoffit(filename_S)
         if (any(ilir == (/1,2,33,34/))) then
            write(tmp_S,'(a,i1,a)') 'READING '//trim(F_messg_s)//' FILE in MODE ',F_mode,' from:'//trim(filename_S)
            call msg(MSG_INFO,tmp_S)
         else
            tmp_S = "File RPNFST Format: "//trim(filename_S)
            istat = -1
         endif
      else
         tmp_S = "File not Found: "//trim(filename_S)
         istat = -1
      endif
   endif IF_MASTER
   call handle_error(istat,'itf_phy_rdfile',tmp_S)

   select case(F_mode)

   case(MODE_ALL_PE)

      if (Ptopo_myproc > 0) inbr = fstopc('MSGLVL','SYSTEM',RMN_OPT_SET)
      fileid    = 0
      ilir   = fnom(fileid,filename_S,'STD+RND+OLD+R/O',0)
      ilir   = fstouv(fileid,'RND')
      istat = 200
      call F_read_cb(fileid,rbuf,dim,istat)
      if (RMN_IS_OK(istat)) then
         allocate(rbuf(dim(2)),stat=ierr)
         istat = 300
         call F_read_cb(fileid,rbuf,dim,istat)
         deallocate(rbuf,stat=ierr) 
      endif
      inbr = fstfrm(fileid)
      inbr = fclos(fileid)

   case(MODE_ALL_PE_LOCAL)

      if (Ptopo_myproc == RPN_COMM_MASTER) then
         call array_from_file(bufnml,size(bufnml),filename_S)
      else
         inbr = fstopc('MSGLVL','SYSTEM',RMN_OPT_SET)
      endif
      call rpn_comm_bcast(bufnml,size(bufnml),RPN_COMM_INTEGER,RPN_COMM_MASTER,RPN_COMM_GRID,ierr )
      filename_S = trim(F_fichier_S)
      call array_to_file(bufnml,size(bufnml),filename_S)

      fileid  = 0
      ilir = fnom(fileid,filename_S,'STD+RND+OLD+R/O',0)
      ilir = fstouv(fileid,'RND')
      istat = 200
      call F_read_cb(fileid,rbuf,dim,istat)
      if (RMN_IS_OK(istat)) then
         allocate(rbuf(dim(2)),stat=ierr)
         istat = 300
         call F_read_cb(fileid,rbuf,dim,istat)
         deallocate(rbuf,stat=ierr) 
      endif
      inbr = fstfrm(fileid)
      inbr = fclos(fileid)    

   case(MODE_P0_BCAST)

      istat = 0
      if (Ptopo_myproc == RPN_COMM_MASTER) then
         fileid  = 0
         ilir = fnom(fileid,filename_S,'STD+RND+OLD+R/O',0)
         ilir = fstouv(fileid,'RND')

         istat = 200
         call F_read_cb(fileid,rbuf,dim,istat)
         if (.not.RMN_IS_OK(istat)) goto 9977
         allocate(rbuf(dim(2)),stat=ierr)
         istat = 250
         call F_read_cb(fileid,rbuf,dim,istat)
         inbr = fstfrm(fileid)
         inbr = fclos(fileid)    
      endif

9977  call handle_error(istat,'itf_phy_rdfile','itf_phy_rdfile')
      call rpn_comm_bcast(dim,MAX_NDIM,RPN_COMM_INTEGER,RPN_COMM_MASTER,RPN_COMM_GRID,ierr)
      if (Ptopo_myproc > 0) allocate(rbuf(dim(2)),stat=ierr)
      call rpn_comm_bcast(rbuf,dim(2),RPN_COMM_REAL,RPN_COMM_MASTER,RPN_COMM_GRID,ierr)
      istat = 400
      call F_read_cb(fileid,rbuf,dim,istat)
      deallocate(rbuf,stat=ierr) 

   case DEFAULT

      call msg(MSG_WARNING,'itf_phy_rdfile: invalid mode, nothing done')

   end select

   call handle_error(istat,'itf_phy_rdfile','')
   inbr = fstopc('MSGLVL','INFORM',RMN_OPT_SET)
   !---------------------------------------------------------------------
   return
end subroutine itf_phy_rdfile2
!!$
!!$
!!$!/@*
!!$subroutine itf_phy_rdfile(F_fichier_S,F_read_cb,F_messg_s,F_mode)
!!$   implicit none
!!$   !@objective Reading a file for the physics package 
!!$   !@arguments
!!$   character(len=*),intent(in) :: F_fichier_S !# file name of input file
!!$   character(len=*) :: F_messg_s
!!$   integer :: F_mode
!!$   external :: F_read_cb !# read call back routine (from physics)
!!$   !@author M. Desgagne, Spring 2008
!!$   !*@/
!!$#include <arch_specific.hf>
!!$#include <rmnlib_basics.hf>
!!$#include <WhiteBoard.hf>
!!$#include "path.cdk"
!!$   integer :: istat
!!$   !-----------------------------------------------------------------
!!$   istat = wb_put('path/input',Path_input_S,WB_REWRITE_MANY)
!!$   call itf_phy_rdfile2(F_fichier_S,F_read_cb,F_messg_s,F_mode)
!!$   !-----------------------------------------------------------------
!!$   return
!!$end subroutine itf_phy_rdfile
