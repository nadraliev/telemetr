      subroutine trimle1(tutm,az,itower,ntower,coor,sd,kappa,vc,
     1   ijob,ierr)
      implicit double precision (a-h,o-z)
      integer itwo
      parameter (itwo=2)
      double precision tutm(itwo,ntower),az(ntower),coor(itwo)
      double precision sd,vc(itwo,itwo)
      double precision a(itwo,itwo),b(itwo),z(itwo),rcond,
     1   si,sistar,ci,cistar,di,zi,mui
      double precision cbar, kappa, kapinv
      integer itower(ntower),ipvt(itwo),iterno,ijob,ierr
      
      double precision pi
      logical inital,convrg

      pi=datan(1.d0)*(4.d0)
      
c
c
c   calling arguments
c
c   variable   contents
c   tutm       true utm coordinates of tower locations
c   az         bearing read from each of these towers
c   itower     indices of the towers to use
c   ntower     number of towers from which bearings were recorded
c   coor       estimates of x and y coordinates (output)
c   kappa      depending on ijob, an estimate of kappa
c   vc         variance-covariance matrix of location estimates
c   ijob       if 0, kappa is estimated, otherwise the value of
c              kappa on input is used for estimation of coor
c   ierr       error return
c               0 - no errors, coor, vc, and possibly kappa returned
c               1 - iteration failed to converge, zeros returned for
c                   coor, vc, and possibly kappa
c               2 - singular system, zeros returned for coor, vc, and
c                   possibly kappa.
c               3 - coor probably okay, but kappa and vc wrong.
c               4 - coor and kappa probably okay, but vc suspect.
c
c
c   missing values for any of the estimated parameters are
c   indicated by zeros on return.
c
c-----------------------------------------------------------------------
c$$$      do i=1,ntower
c$$$         print *,i,tutm(1,itower(i)),tutm(2,itower(i))
c$$$      end do
c$$$      do i=1,ntower
c$$$         write(*,'(f10.6)')az(itower(i))
c$$$      end do
c$$$      do i = 1,ntower
c$$$         print *,itower(i)
c$$$      end do
c$$$      print *,coor
c$$$      print *,'sd ',sd
c$$$      print *,ijob
c$$$      print *,ierr
c
c   set kappa from sd
c
      if (ijob.ne.0) then
         kappa=exp((sd*pi/180.d0)**2*(-0.5d0))
         kappa=1.d0/(2.d0*(1.d0-kappa)+(1.-kappa)**2*(0.48794d0
     1      - 0.82905d0*kappa - 1.3915*kappa**2)/kappa)
      else
         kappa=0.d0
      endif

c
c   initial coor and vc to missing values
c
      do 10 i=1,itwo
         coor(i)=0.d0
         do 10 j=1,itwo
 10         vc(j,i)=0.d0
      iterno=0
      ierr=1
      convrg=.false.
      inital=.true.
 12   do 15 i=1,itwo
         b(i)=0.d0
         do 15 j=1,itwo
 15         a(i,j)=0.d0
      do 20 i=1,ntower
         si=dsin(az(itower(i)))
         ci=dcos(az(itower(i)))
         zi=si*tutm(1,itower(i))-ci*tutm(2,itower(i))
         if (inital) then
            sistar=si
            cistar=ci
         else
            di=sqrt((coor(1)-tutm(1,itower(i)))**2+
     1         (coor(2)-tutm(2,itower(i)))**2)
            sistar=(coor(2)-tutm(2,itower(i)))/(di**3)
            cistar=(coor(1)-tutm(1,itower(i)))/(di**3)
         endif
         a(1,1)=a(1,1)+si*sistar
         a(2,2)=a(2,2)+ci*cistar
         a(1,2)=a(1,2)-ci*sistar
         a(2,1)=a(2,1)-si*cistar
         b(1)=b(1)+sistar*zi
         b(2)=b(2)-cistar*zi
 20   continue
c
c   calculate (x,y) for this iteration
c
      call dgeco(a,itwo,itwo,ipvt,rcond,z)
      if ((1.d0+rcond).eq.1.d0) then
         coor(1)=0.d0
         coor(2)=0.d0
         ierr=2
         if (ijob.eq.0) kappa=0.d0
         return
      endif
      call dgesl(a,2,2,ipvt,b,0)
c     b(2)=(a(1,1)*b(2)-a(2,1)*b(1))/(a(1,1)*a(2,2)-a(2,1)*a(1,2))
c     b(1)=(b(1)-a(1,2)*b(2))/a(1,1)
      if (inital) then
         inital=.false.
      else
c
c      check for convergence
c
         if (abs(b(1)-coor(1))/b(1) .lt. 1.d-8
     1      .and. abs(b(2)-coor(2))/b(2) .lt. 1.d-8) then
            convrg=.true.
         endif
      endif
      coor(1)=b(1)
      coor(2)=b(2)
      iterno=iterno+1
      if (.not.convrg .and. iterno.lt.101) go to 12
c
c   convergence achieved -- calculate variance-covariance matrix
c
      ierr=0
      cbar=0.d0
      do 25 i=1,ntower
         si=dsin(az(itower(i)))
         ci=dcos(az(itower(i)))
         di=dsqrt((coor(1)-tutm(1,itower(i)))**2+
     1           (coor(2)-tutm(2,itower(i)))**2)
         sistar=(coor(2)-tutm(2,itower(i)))/(di**3)
         cistar=(coor(1)-tutm(1,itower(i)))/(di**3)
         vc(1,1)=vc(1,1)+si*sistar
         vc(1,2)=vc(1,2)+sistar*ci+cistar*si
         vc(2,2)=vc(2,2)+cistar*ci
         if (ijob.eq.0) then
            mui=atan2(coor(2)-tutm(2,itower(i)),coor(1)-
     1         tutm(1,itower(i)))
            cbar=cbar+cos(az(itower(i))-mui)
         endif
 25      continue
      if (ijob.eq.0) then
         cbar=cbar/dble(ntower)
         kapinv=(2.d0*(1.d0-cbar)+((1.d0-cbar))**2*
     1      (.48794d0-.82905d0*cbar-1.3915d0*cbar*cbar)/cbar)
         if (kapinv.gt.0.d0) then
            kappa=1.d0/kapinv
         else
            ierr=3
            kappa=500.d0
         endif
      endif
      vc(1,2)=vc(1,2)*(-0.5)
      vc(2,1)=vc(1,2)
      call dgeco(vc,itwo,itwo,ipvt,rcond,z)
      if ((1.d0+rcond).eq.1.d0) then
         vc(1,1)=0.d0
         vc(1,2)=0.d0
         vc(2,1)=0.d0
         vc(2,2)=0.d0
         ierr=4
         print *,' ierr 4'
         if (ijob.eq.0) kappa=0.d0
         return
      endif
      call dgedi(vc,2,2,ipvt,rcond,z,1)
      Print *, 'cbar'
      Print "(f20.12)", cbar
      Print *, 'kapinv'
      Print "(f20.12)", kapinv
      Print *, 'kappa'
      Print "(f20.12)", kappa
      Print *, 'ierr'
      Print "(i6)", ierr
      Print *, 'vc'
      Print "(f20.12)", vc(1,1)
      Print "(f20.12)", vc(1,2)
      Print "(f20.12)", vc(2,1)
      Print "(f20.12)", vc(2,2)
      vc(1,2)=vc(1,2)/kappa
      vc(2,1)=vc(1,2)
      vc(1,1)=vc(1,1)/kappa
      vc(2,2)=vc(2,2)/kappa
      Print *, 'vc after'
      Print "(f20.12)", vc(1,1)
      Print "(f20.12)", vc(1,2)
      Print "(f20.12)", vc(2,1)
      Print "(f20.12)", vc(2,2)
      return
      end
