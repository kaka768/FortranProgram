!include "../lib/utility.f90"
include "../largeN/mbroyden.f90"
module M_DMFT
	use M_const
	use M_solution
	use M_matrix
	use M_utility
	use mkl_service
	use M_serde
	use M_fft
	implicit none
	real(8), parameter :: onepi=1d0/pi,halfpi=onepi*0.5d0,w0w1=0.25_wp
	integer, parameter :: nadd(3)=[600,100,100],n=(sum(nadd))*2,nk=256/8,D=2,nkD=nk**D
	real(8) :: U=nan,t=1d0,bcut=20d0,omega(n),Tk,beta,et=1d-1,mu
	complex(8) :: iomega(n)
	integer, parameter :: export_w=1,export_k=2,export_wk=3,set_omega=0,set_Ver=1,set_dSEk=2,set_dVerq=3,set_dSusq=4,set_GM=5,set_B=6,set_dGk0=7,set_Gk=8,set_Gi=9,set_Gl=10,set_SEl=11,set_Gkl=12,set_dGkl=13,set_ek=14,prime=20
	integer :: ipi
	logical, parameter :: is_real=.false.
	type(t_serde(D)) :: map
	type gf(D,nk)
		integer, len :: D,nk
		complex(8) :: r(nk**D)
		complex(8) :: k(nk**D)
	end type
	type gfs(n,D,nk)
		integer, len :: n,D,nk
		real(8) :: k(D,nk**D)
		real(8), allocatable :: uk(:,:)
		integer, allocatable :: uk2k(:,:)
		real(8) :: rhoc(n),B(nk**D),ek(nk**D)
		complex(8) :: Gl(n),Gkl(n),dGl(n),Delta(n),SEl(n),GM(n),Ver(n,n)
		type(gf(D,nk)) :: dVer(n),Gk(n),dGk(n),dG0(n),dSE(n),dSus(n)
		!complex(8) :: Sus(n,nk**D),dSus(n,nk**D),Gck(n,nk**D),Gci(n,nk**D),dSEc(n,nk**D),dGck(n,nk**D)
		logical :: conv
	contains
		procedure :: self_consistent
		procedure :: set_Gfunction
		procedure :: export
	end type
contains
	subroutine export(self,ut,flag)
		class(gfs(*,*,*)) :: self
		integer :: ut(:),flag(:)
		integer :: iw,k,ik
		do k=1,size(flag)
			select case(flag(k))
			case(export_w)
				write(ut(k),"(A)")"Tk omega rGl iGl rDelta iDelta rSEl iSEl rG iG"
				do iw=1,n
					write(ut(k),"(*(e29.20e3))")Tk,omega(iw),self%Gl(iw),self%Delta(iw),self%SEl(iw),sum(self%Gk(iw)%k)/nkD
				enddo
				write(ut(k),"(x/)")
			case(export_wk)
				write(ut(k),"(A)")"Tk omega rdG idG rG iG rdVer idVer"
				do iw=1,n
					write(ut(k),"(*(e29.20e3))")Tk,omega(iw),self%dGk(iw)%k(ipi),self%Gk(iw)%k(ipi),self%dVer(iw)%k(ipi)
				enddo
				write(ut(k),"(x/)")
			case(export_k)
				write(ut(k),"(A)")"Tk k rSus iSus B"
				do ik=1,nkD
					write(ut(k),"(*(e29.20e3))")Tk,self%k(:,ik),self%B(ik)
				enddo
				write(ut(k),"(x/)")
			end select
		end do
	end subroutine
	subroutine set_Gfunction(self,flag)
		class(gfs(*,*,*)) :: self
		integer :: flag(:),iw,jw,ik,l,i
		complex(wp) :: phi(n,nkD)
		do l=1,size(flag)
			select case(flag(l))
			case(set_omega)
				if(is_real) then
					! real frequency
					call set_grid(omega(n/2+1:),[reset,add_linear,add_linear,add_linear],from=[0d0,max(U/2d0-5d0,0d0),1.5d0],to=[bcut,min(U/2d0+5d0,bcut),3d0],n=[nadd])
					omega(1:n/2)=-omega(n:n/2+1:-1)
					iomega=cmplx(omega,et,kind=8)
				else
					! matsubara frequency
					call set_grid(omega(n/2+1:),[reset,add_linear],from=[0d0],to=[n/2*2d0*pi*Tk],n=[n/2])
					!call set_grid(inu(m/2+1:),[reset,add_linear,add_linear],from=[0d0,m/4*2d0*pi*Tk],to=[m/4*2d0*pi*Tk,m/2*2d0*pi*Tk*16],n=[m/4,m/4])
					omega(1:n/2)=-omega(n:n/2+1:-1)+2d0*pi*Tk
					omega=omega-pi*Tk
					iomega=cmplx(0d0,omega,kind=8)
				endif
			case(set_Ver)
				do iw=1,n
					do jw=1,n
						if(iw==jw) then
							self%Ver(iw,jw)=0d0
						else
							self%Ver(iw,jw)=w0w1*U**2*self%GM(iw)*self%GM(jw)
						endif
					enddo
				enddo
			case(set_dVerq)
				!$OMP PARALLEL DO
				do ik=1,size(self%k,2)
					phi(:,ik)=w0w1*U**2*self%GM(:)/(1d0+w0w1*U**2*self%GM(:)**2*self%dSus(:)%k(ik))
					self%dVer(:)%k(ik)=phi(:,ik)*(self%B(ik)*self%GM(:)-phi(:,ik)*self%GM(:)**2*self%dSus(:)%k(ik))/(1._wp-self%B(ik))
					!self%dVer(:)%k(ik)=phi(:,ik)*(self%B(ik)*self%GM(:)-phi(:,ik)*self%GM(:)**2*self%dSus(:)%k(ik))/(sign(1._wp,1._wp-self%B(ik))*max(abs(1._wp-self%B(ik)),1e-6_wp))
				enddo
				!$OMP END PARALLEL DO
			case(set_dSusq)
				!$OMP PARALLEL DO
				do ik=1,size(self%uk,2)
					do i=2,self%uk2k(ik,0)
						self%dGk(:)%k(self%uk2k(ik,i))=self%dGk(:)%k(self%uk2k(ik,1))
					enddo
				enddo
				!$OMP END PARALLEL DO

				!$OMP PARALLEL DO
				do iw=1,n
					call mfft(self%dGk(iw)%k(1:nkD),1,map%shap,self%dGk(iw)%r(1:nkD),1d0/product(map%shap))
					!self%dSus(iw)%r=-self%dGk(iw)%r**2
					call mfft(self%dGk(iw)%k(1:nkD),-1,map%shap,self%dSus(iw)%r(1:nkD),1d0/product(map%shap))
					self%dSus(iw)%r=-self%dGk(iw)%r*self%dSus(iw)%r
					call mfft(self%dSus(iw)%r(1:nkD),-1,map%shap,self%dSus(iw)%k(1:nkD))
				enddo
				!$OMP END PARALLEL DO
			case(set_GM)
				!self%GM=1d0/(self%Gl**2*(iomega%re-self%Delta+mu)*(iomega%re-self%Delta+mu-U))
				self%GM=1d0/(self%Gl**2*(iomega-self%Delta+mu)*(iomega-self%Delta+mu-U))
			case(set_B)
				!ik=ipi
				do ik=1,size(self%k,2)
					phi(:,ik)=w0w1*U**2*self%GM(:)/(1d0+w0w1*U**2*self%GM(:)**2*self%dSus(:)%k(ik))
					if(is_real) then
						self%B(ik)=integrate(omega,A=-imag(phi(:,ik)*self%GM*self%dSus(:)%k(ik))*ff(beta*iomega%re)/pi)/Tk
					else
						self%B(ik)=sum(phi(:,ik)*self%GM*self%dSus(:)%k(ik))
					endif
				enddo
			case(set_dSEk)
				do iw=1,n
					!call mfft(self%dVer(iw)%k(1:nkD),1,map%shap,self%dVer(iw)%r(1:nkD),1d0/product(map%shap))
					call mfft(self%dVer(iw)%k(1:nkD),-1,map%shap,self%dSE(iw)%r(1:nkD),1d0/product(map%shap))
					call mfft(self%dGk(iw)%k(1:nkD),1,map%shap,self%dGk(iw)%r(1:nkD),1d0/product(map%shap))
					!self%dSE(iw)%r=self%dVer(iw)%r*self%dGk(iw)%r
					self%dSE(iw)%r=self%dSE(iw)%r*self%dGk(iw)%r
					call mfft(self%dSE(iw)%r(1:nkD),-1,map%shap,self%dSE(iw)%k(1:nkD))
				enddo
			case(set_dGk0)
				do ik=1,size(self%uk,2)
					self%dG0(:)%k(self%uk2k(ik,1))=(self%Gk(:)%k(self%uk2k(ik,1))-self%Gl(:))
				enddo
			case(set_dGk0+prime)
				do ik=1,size(self%uk,2)
					self%dG0(:)%k(self%uk2k(ik,1))=-1._wp/(1._wp/(self%Gl(:)**2*(self%Delta(:)-self%ek(self%uk2k(ik,1))))+1._wp/self%Gl(:))
				enddo
			case(set_Gk)
				!$OMP PARALLEL DO
				do ik=1,size(self%uk,2)
					self%Gk(:)%k(self%uk2k(ik,1))=1d0/(iomega(:)-self%ek(self%uk2k(ik,1))-self%SEl(:))
				enddo
				!$OMP END PARALLEL DO
			case(set_Gk+prime)
				!$OMP PARALLEL DO
				do ik=1,size(self%uk,2)
					self%Gk(:)%k(self%uk2k(ik,1))=1d0/(self%Delta(:)-self%ek(self%uk2k(ik,1)))+1d0/((self%Delta(:)-self%ek(self%uk2k(ik,1)))*self%Gl(:))**2*self%dGk(:)%k(self%uk2k(ik,1))
				enddo
				!$OMP END PARALLEL DO
			case(set_Gl)
				self%Gl=0.5d0/(iomega-self%Delta+mu)+0.5d0/(iomega-self%Delta+mu-U)
			case(set_SEl)
				self%SEl=iomega-self%Delta-1d0/self%Gl
			case(set_Gkl)
				!$OMP PARALLEL DO
				do iw=1,n
					self%Gkl(iw)=0d0
					do ik=1,size(self%uk,2)
						self%Gkl(iw)=self%Gkl(iw)+self%uk2k(ik,0)*self%Gk(iw)%k(self%uk2k(ik,1))
					enddo
				enddo
				!$OMP END PARALLEL DO
				self%Gkl=self%Gkl/real(nkD,kind=8)
			case(set_dGkl)
				!$OMP PARALLEL DO
				do iw=1,n
					self%dGl(iw)=0d0
					!do ik=1,nkD
					!self%Gl(j)=self%Gl(j)+(1d0/(iomega(j)%re-ek(ik)-self%SEl(j)))
					!enddo
					do ik=1,size(self%uk,2)
						self%dGl(iw)=self%dGl(iw)+self%uk2k(ik,0)*self%dGk(iw)%k(self%uk2k(ik,1))
					enddo
				enddo
				!$OMP END PARALLEL DO
				self%dGl=self%dGl/real(nkD,kind=8)
			case(set_ek)
				!$OMP PARALLEL DO
				do ik=1,size(self%k,2)
					self%ek(ik)=0._wp
					do i=1,D
						self%ek(ik)=self%ek(ik)+2d0*t*cos(self%k(i,ik))
					enddo
				enddo
				!$OMP END PARALLEL DO
			end select
		enddo
	end subroutine
	subroutine self_consistent(self,rate,niter,tol)
		class(gfs(*,*,*)) :: self
		real(8) :: rate,tol
		integer :: niter(2)
		integer :: i,i1,i2,ik,iw,nx
		complex(8) :: x(self%n*nkD),x_(size(x))
		complex(8) :: tmp(n)
		mu=0.5d0*U
		if(.not.is_real) call self%set_Gfunction([set_omega])
		call mbroyden(0,x,x_,rate,40,id=2)
		do i1=1,niter(1)
			if(is_real) call set_realpart(iomega%re,self%Delta)
			call self%set_Gfunction([set_Gl,set_GM,set_dGk0])

			!dual fermion
			nx=self%n*nkD
			do ik=1,nkD
				self%dGk(:)%k(ik)=self%dG0(:)%k(ik)
				x((ik-1)*n+1:ik*n)=self%dGk(:)%k(ik)
			enddo
			!do i2=1,niter(2)
				!call self%export([50],[export_wk])
				!call self%set_Gfunction([set_dSusq,set_B,set_dVerq,set_dSEk])
				!!exit
				!do ik=1,nkD
					!x_((ik-1)*n+1:ik*n)=1._wp/(1._wp/self%dG0(:)%k(ik)-self%dSE(:)%k(ik))
				!enddo
				!write(*,"(i3,*(es14.4))")i2,maxval(abs(x(1:nx)-x_(1:nx))),Tk,self%B(ipi)
				!if(all(abs(x(1:nx)-x_(1:nx))<tol).or.i2==niter(2)) then
					!exit
				!else
					!!x=x_*rate+x*(1._wp-rate)
					!call mbroyden(i2,x(1:nx),x_(1:nx),id=2)
				!endif
				!do ik=1,nkD
					!if(is_real) call set_realpart(iomega%re,x((ik-1)*n+1:ik*n))
					!self%dGk(:)%k(ik)=x((ik-1)*n+1:ik*n)
				!enddo
			!enddo

			call self%set_Gfunction([set_Gk+prime,set_Gkl,set_dGkl])
			!call self%set_Gfunction([set_SEl,set_Gk,set_Gkl])
			nx=self%n
			x(1:nx)=self%Delta
			!x_(1:nx)=iomega-1d0/self%Gkl-self%SEl
			x_(1:nx)=self%Delta+rate*self%dGl/(self%Gkl*self%Gl)
			if(is_real) then
				x(1:nx)%re=0._wp
				x_(1:nx)%re=0._wp
			endif
			write(*,"(i3,*(es14.4))")i1,maxval(abs(x(1:nx)-x_(1:nx)))
			if(all(abs(x(1:nx)-x_(1:nx))<tol).or.i1==niter(1)) then
				self%conv=(i1/=niter(1))
				exit
			else
				!x(1:nx)=(1._wp-rate)*x(1:nx)+rate*x_(1:nx)
				!call mbroyden(i1,x(1:nx),x_(1:nx),id=1)
			endif
			self%Delta=x(1:nx)
			call self%export([10],[export_w])
		enddo
		call self%set_Gfunction([set_dSusq,set_B])
		call mbroyden(huge(1),x,x_)
	end subroutine
	subroutine set_realpart(omega,G)
		real(8) :: omega(:)
		complex(8) :: G(:)
		real(8) ::dx
		integer :: i,j,dn(2)
		G(1)%re=0d0
		G(n)%re=0d0
		do i=2,n-1
			G(i)%re=2d0*G(i)%im*log((omega(n)-omega(i))/(omega(i)-omega(1)))
		enddo
		do j=1,n
			dn=[min(n,j+1),max(1,j-1)]
			dx=omega(dn(1))-omega(dn(2))
			G(j)%re=G(j)%re+G(dn(1))%im-G(dn(2))%im
			do i=1,n
				if(j/=i) then
					G(i)%re=G(i)%re+(G(j)%im-G(i)%im)/(omega(j)-omega(i))*dx
				endif
			enddo
		enddo
		do i=1,n
			G(i)%re=G(i)%re*halfpi
		enddo
	end subroutine
	subroutine into_sym(k)
		real(8) :: k(:)
		integer :: i,j
		real(8) :: tmp
		k=abs(k-pi)
		do i=1,D
			do j=i+1,D
				if(k(i)<k(j)) then
					tmp=k(i)
					k(i)=k(j)
					k(j)=tmp
				endif
			enddo
		enddo
	end subroutine
	subroutine get_uk(k,uk,uk2k)
		real(8) :: k(:,:)
		real(8), allocatable :: uk(:,:)
		integer, allocatable :: uk2k(:,:)
		real(8) :: tmp(1:size(k,1),size(k,2))
		integer :: n,i,j
		integer :: ord(size(k,2))
		integer, allocatable :: c(:)
		do i=1,size(k,2)
			tmp(1:,i)=k(:,i)
			call into_sym(tmp(1:,i))
		enddo
		ord=[1:size(k,2)]
		call qsort(tmp(:,:),ord)
		tmp(:,:)=tmp(:,ord)
		call collect(tmp,c)
		allocate(uk(1:D,size(c)-1))
		uk(1:D,:)=tmp(:,c(1:size(c)-1))
		!uk(0,:)=real(c(2:)-c(1:size(c)-1),kind=8)
		allocate(uk2k(size(uk,2),0:maxval(c(2:)-c(1:size(c)-1))))
		uk2k(:,0)=c(2:)-c(1:size(c)-1)
		do i=1,size(uk,2)
			uk2k(i,1:c(i+1)-c(i))=ord(c(i):c(i+1)-1)
		enddo
		
		write(*,*)sum(uk2k(:,0))==nkD
	end subroutine
end module
include "../lib/serde.f90"
include "../lib/fft.f90"
program main
	use M_DMFT
	implicit none
	type(gfs(n,D,nk)) :: phy
	integer :: j,i,ik,jk,iT,iU
	real(8) :: ff_(n),dTk

	call omp_set_nested(.false.)
	call omp_set_dynamic(.false.)
	call mkl_set_dynamic(0)

	call mkl_set_num_threads(1)
	!call omp_set_num_threads(mkl_get_max_threads())
	call omp_set_num_threads(4)

	open(unit=10,File="../data/fk.dat")
	open(unit=20,file="../data/fk_init.dat")
	open(unit=30,File="../data/fk_q.dat")
	open(unit=40,File="../data/fk_phase.dat")
	open(unit=50,File="../data/fk_dG.dat")
	!call add_omega(omega(1:nl*nlog*2+sum(nadd(1:2))*4),4d0,0.5d0,nadd(2))
	map%shap=[(nk,i=1,D)]
	ipi=0
	!!$OMP PARALLEL DO
	do ik=1,size(phy%k,2)
		phy%k(:,ik)=2d0*pi*(map%get_idx(ik,[1:D])-1)/nk
		if(sum(abs(phy%k(:,ik)-pi))<1d-8) then
			if(ipi==0) then
				ipi=ik
			else
				stop "err"
			endif
		endif
	enddo
	!!$OMP END PARALLEL DO
	write(*,*)"stating get unique k point...."
	call get_uk(phy%k,phy%uk,phy%uk2k)
	write(*,*)"finished get unique k point",size(phy%k,2)/size(phy%uk,2)
	!do i=1,size(phy%uk,2)
		!write(*,*)phy%uk(:,i)
		!read(*,*)
	!enddo
	!do i=1,n
		!read(20,"(2(e28.20))")phy%Delta(i)
	!enddo
	write(40,"(A)")"U T"
	if(next(Tk,0d0,1d-1,1d-4)) then
	endif
	phy%Delta=0d0
	call phy%set_Gfunction([set_ek])
	do 
		U=for_in([5d0],id=1)
		if(isnan(U)) exit
		Tk=2.1d-1
		if(is_real) then
			call phy%set_Gfunction([set_omega])
		endif
		do 
			beta=1._wp/Tk

			call phy%self_consistent(0.1d0,[3000,1],1d-6)
			write(*,*)Tk,phy%B(ipi)
			!stop
			if(next(Tk,phy%B(ipi)-1d0)) then
				write(40,"(*(e29.20e3))")U,Tk
				exit
			endif
		enddo
	enddo
end program
