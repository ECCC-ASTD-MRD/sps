!**s/r
!
      subroutine sps_yyencode
      implicit none
!
!author   M.Desgagne   -   Spring 2012
!revision B. Bilodeau  -   Winter 2014
!                          Make sure that, after running consecutively yyencode and yydecode,
!                          the grid descriptors that are produced are identical to those 
!                          of the original yin and yang files
!
      integer fnom,fstouv,fstinf,fstinl,fstprm,fstluk,exdb,exfin, &
              fstecr,fstfrm,fclos,fstopl,fstsel,fstlis
      external fnom,fstouv,fstinf,fstinl,fstprm,fstluk,exdb,exfin, &
               fstecr,fstfrm,fclos,fstopl,fstsel,fstlis

      CHARACTER*1024 LISTEc(3), DEF(3), VAL(3)
      INTEGER NPOS
      DATA LISTEc /'yin.'   , 'yan.' , 'o.'    /
      DATA VAL    /'/null'  , '/null', '/null' /
      DATA DEF    /'/null'  , '/null', '/null' /

      character*1    familly_uencode_S
      character*2    typ_S, grd_S
      character*4    var_S
      character*12   lab_S, lste_S(2)
      character*1024 def1_S(2), def2_S(2), yin_S,yan_S,out_S

      integer dte, det, ipas, p1, p2, p3, g1, g2, g3, g4, bit, &
              dty, swa, lng, dlf, ubc, ex1, ex2, ex3,ip1,ip2,ip3

      integer iun1,iun2,iun3,maxni,maxnj,i,n,datev,niyy,vesion_uencode
      integer nlis,lislon, key, ni1,nj1,nk1,ni,nj,err,sindx_yin,sindx
      parameter (nlis = 1024)
      integer liste(nlis), niv(nlis)

      real  xlat1,xlon1, xlat2,xlon2
      REAL, DIMENSION(:),allocatable :: champ, yy
      real*8 nhours
!
!-------------------------------------------------------------------
!
      err = exdb ('SPS_YYENCODE','1.0', 'NON')
      NPOS = 1
      CALL CCARD(LISTEc,DEF,VAL,3,NPOS)
      yin_S = val(1)
      yan_S = val(2)
      out_S = val(3)

      iun1 = 0 ; iun2 = 0 ; iun3 = 0

      if (fnom(iun1,yin_S,'RND+OLD',0).ge.0) then
         if (fstouv(iun1,'RND').lt.0) then
             write (6,8001) yin_S
            stop
         endif
      else
         write (6,8000) yin_S
         stop
      ENDIF
      if (fnom(iun2,yan_S,'RND+OLD',0).ge.0) then
         if (fstouv(iun2,'RND').lt.0) then
             write (6,8001) yan_S
            stop
         endif
      else
         write (6,8000) yan_S
         stop
      ENDIF
      if (fnom(iun3,out_S,'RND',0).ge.0) then
         if (fstouv(iun3,'RND').lt.0) then
             write (6,8001) out_S
            stop
         endif
      else
         write (6,8000) out_S
         stop
      ENDIF

      err= fstinl (iun1,ni1,nj1,nk1,-1,' ',-1,-1,-1,' ',' ',&
                                         liste,lislon,nlis)
      maxni=0 ; maxnj=0
      do i=1,lislon
         err= fstprm (liste(i), dte, det, ipas, ni, nj, nk1, bit , &
                  dty, p1, p2, p3, typ_S, var_S, lab_S, grd_S, g1, &
                  g2, g3, g4, swa, lng, dlf, ubc, ex1, ex2, ex3)
         maxni= max(maxni,ni)
         maxnj= max(maxni,nj)
      end do

      if (lislon.lt.1) then
         write(6,'(/3x,"NOTHING to DO -- QUIT"/)')
         stop
      endif

      allocate (champ(maxni*2*maxni))

      do i=1,lislon
         err= fstprm (liste(i), dte, det, ipas, ni, nj, nk1, bit , &
                  dty, p1, p2, p3, typ_S, var_S, lab_S, grd_S, g1, &
                  g2, g3, g4, swa, lng, dlf, ubc, ex1, ex2, ex3)

         nhours = det * ipas / 3600.d0
         datev  = -1
         if (dte .gt. 0) call incdatr (datev, dte, nhours)

         key= FSTINF(iun2, NI1, NJ1, NK1, datev, ' ', p1, p2, p3, typ_S, var_S)
	
         if (var_S.eq.'!!' .or. var_S.eq.'>>' .or. var_S.eq.'^^') then
            if (var_S.eq.'!!') then
               p3  = 44
               err = fstluk(champ,liste(i),ni1,nj1,nk1)
               err = FSTECR(champ, champ, -bit, iun3, dte, det, ipas, ni1, nj1, &
                                   nk1, p1, p2, p3, typ_S, var_S, lab_S, grd_S, &
                                                   g1, g2, g3, g4, dty, .true.)
            endif
         else
            if (key.lt.0) then
               write(6,'(/3x,"Corresponding YAN variable: ",a," NOT FOUND - ABORT"/)') var_S
               stop
            endif
!BIL        g3 = 1                            ! points de masse
            g3 = 0                            ! points de masse
            if (trim(var_S) == 'UT1')  g3 = 2 ! points U
            if (trim(var_S) == 'VT1')  g3 = 3 ! points V
            err = fstluk(champ,liste(i),ni1,nj1,nk1)
            err = fstluk(champ(ni1*nj1+1),key,ni1,nj1,nk1)
            err = FSTECR(champ, champ, -bit, iun3, dte, det, ipas, ni1, 2*nj1, &
                                    nk1, p1, p2, p3, typ_S, var_S, lab_S, 'U', &
                                                   g1, g2, g3, g4, dty, .true.)
!BIL                                               g1, g2, g3, 1, dty, .true.)
         endif

      end do

      err= fstinl (iun1,ni,nj1,nk1,-1,' ',-1,-1,-1,' ','>>',&
                                           liste,lislon,nlis)
      if (lislon.eq.0) then
         write(6,'(/3x,"YIN positionnal parameters >> not available - ABORT"/)')
         stop
      endif

      key = liste(1)
      
      err= fstinl (iun1,ni1,nj,nk1,-1,' ',-1,-1,-1,' ','^^',&
                                           liste,lislon,nlis)
      if (lislon.eq.0) then
         write(6,'(/3x,"YIN positionnal parameters ^^ not available - ABORT"/)')
         stop
      endif
      
      if ((key.lt.0).or.(liste(1).lt.0)) then
         write(6,'(/3x,"YIN positionnal parameters not available - ABORT"/)')
         stop
      endif
      
      err= fstprm ( key, dte, det, ipas, ni1, nj1, nk1, bit           , &
                    dty, ip1, ip2, ip3, typ_S, var_S, lab_S, grd_S, g1, &
                     g2, g3, g4, swa, lng, dlf, ubc, ex1, ex2, ex3 )

      call cigaxg ( 'E', xlat1,xlon1, xlat2,xlon2, g1,g2,g3,g4 )

      niyy=5+2*(10+ni+nj)
      allocate (yy(niyy))
      
      vesion_uencode    = 1
      familly_uencode_S = 'F'

      yy(1 ) = iachar(familly_uencode_S)
      yy(2 ) = vesion_uencode
      yy(3 ) = 2 ! 2 grids (Yin & Yang)
      yy(4 ) = 1 ! the 2 grids have same resolution
      yy(5 ) = 1 ! the 2 grids have same area extension on the sphere

      !YIN
      sindx  = 6
      yy(sindx  ) = ni
      yy(sindx+1) = nj
      yy(sindx+6) = xlat1
      yy(sindx+7) = xlon1
      yy(sindx+8) = xlat2
      yy(sindx+9) = xlon2
      err = fstluk(yy(sindx+10   ),key     ,ni1,nj1,nk1)
      err = fstluk(yy(sindx+10+ni),liste(1),ni1,nj1,nk1)
      yy(sindx+2) = yy(sindx+10      )
      yy(sindx+3) = yy(sindx+ 9+ni   )
      yy(sindx+4) = yy(sindx+10+ni   )
      yy(sindx+5) = yy(sindx+ 9+ni+nj)
      sindx_yin= sindx

      !YAN
      err= fstinl (iun2,ni,nj1,nk1,-1,' ',-1,-1,-1,' ','>>',&
                                           liste,lislon,nlis)
      if (lislon.eq.0) then
         write(6,'(/3x,"YAN positionnal parameters >> not available - ABORT"/)')
         stop
      endif

      err= fstprm (liste(1), dte, det, ipas, ni1, nj1, nk1, bit , &
              dty, p1, p2, p3, typ_S, var_S, lab_S, grd_S, g1   , &
               g2, g3, g4, swa, lng, dlf, ubc, ex1, ex2, ex3 )

      call cigaxg ( 'E', xlat1,xlon1, xlat2,xlon2, g1,g2,g3,g4 )

      sindx   = sindx+10+ni+nj
      yy(sindx  ) = ni
      yy(sindx+1) = nj
      yy(sindx+2) = yy(sindx_yin+10      )
      yy(sindx+3) = yy(sindx_yin+ 9+ni   )
      yy(sindx+4) = yy(sindx_yin+10+ni   )
      yy(sindx+5) = yy(sindx_yin+ 9+ni+nj)
      yy(sindx+6) = xlat1
      yy(sindx+7) = xlon1
      yy(sindx+8) = xlat2
      yy(sindx+9) = xlon2
      yy(sindx+10    :sindx+9+ni  )= yy(sindx_yin+10   :sindx_yin+9+ni   )
      yy(sindx+10+ni:sindx+9+ni+nj)= yy(sindx_yin+10+ni:sindx_yin+9+ni+nj)

!BIL  p3 = 1
      p3 = 0
      err = FSTECR(yy, yy, -32, iun3, 0, 0, 0, niyy, 1, 1  , &
                   ip1, ip2,  p3, 'X', '^>', 'YYG_UE_GEMV4', &
                   familly_uencode_S, vesion_uencode,0,0,0, 5, .true.)
      err = fstfrm(iun3)

      err = exfin ('SPS_YYENCODE','1.0', 'OK')

 8000 format (/' Unable to fnom: '  ,a/)
 8001 format (/' Unable to fstouv: ',a/)

      return
      end
