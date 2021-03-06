!#define cluster
include "../lib/utility.f90"
include "../largeN/mbroyden.f90"
include "../lib/serde.f90"
include "../lib/fft.f90"
module global
	use M_const
	real(8), parameter :: onepi=1d0/pi,halfpi=onepi*0.5d0,&
		n_f=1._wp/2._wp,n_c=1._wp/2._wp
	integer, parameter :: nadd(3)=[500,0,0],n=(sum(nadd))*2,&
		D=2,&
		Ns=1,&
		Nc=1,&
		nk=2*3*4,&
		dNs=Nc,&
		nkD=nk**D
	logical :: is_real=.false.,is_normal_mat=.false.,is_SE=.false.,&
		is_CDMFT=.true.,is_dF4_iter=.false.,is_dual_pureDCA=.true.,fix_cp=.true.,split_cp=.true.
	integer :: sdiagram(2)=& ! -1: infinite; 0 none
		[1,-1]
	integer :: ddiagram(2)=&
		[0,0]
	real(8) :: U=nan,t=1d0,bcut(2)=[-15d0,15d0],omega(n),Tk,beta,et=2d-1,Res(n)
	real(8) :: &
		!a(D,D)=[1.0_wp,0.0_wp,0.0_wp,1.0_wp],scell(D,D)=[1._wp,1._wp,-1._wp,1._wp]*1._wp,clust(D,D)=[1._wp,1._wp,-1._wp,1._wp]*1._wp,rc0(D)=[0._wp,0._wp]!N=2
		a(D,D)=[1.0_wp,0.0_wp,0.0_wp,1.0_wp],scell(D,D)=[1._wp,0._wp,0._wp,1._wp]*1._wp,clust(D,D)=[1._wp,0._wp,0._wp,1._wp]*1._wp,rc0(D)=[0._wp,0._wp]!N=1
		!a(D,D)=[1.0_wp,0.0_wp,0.0_wp,1.0_wp],scell(D,D)=[1._wp,0._wp,0._wp,1._wp]*2._wp,clust(D,D)=[1._wp,0._wp,0._wp,1._wp]*2._wp,rc0(D)=[0._wp,0._wp]!N=4
		!a(D,D)=[1.0_wp,0.0_wp,0.0_wp,1.0_wp],scell(D,D)=[1._wp,1._wp,-1._wp,1._wp]*1._wp,clust(D,D)=[1._wp,0._wp,0._wp,1._wp]*2._wp
		!a(D,D)=[1.0_wp,0.0_wp,0.0_wp,1.0_wp],scell(D,D)=[1.0_wp,0.0_wp,0.0_wp,1.0_wp]*1._wp,clust(D,D)=[1.0_wp,0.0_wp,0.0_wp,1.0_wp]*1._wp,rc0(D)=[0._wp,0._wp]
		!a(D,D)=[1.0_wp,0.0_wp,0.0_wp,1.0_wp],scell(D,D)=[2.0_wp,0.0_wp,0.0_wp,2.0_wp],clust(D,D)=[2.0_wp,0.0_wp,0.0_wp,2.0_wp],rc0(D)=[0._wp,0._wp]!N=4
		!a(D,D)=[1.0_wp,0.0_wp,0.0_wp,1.0_wp],scell(D,D)=[1.0_wp,0.0_wp,0.0_wp,1.0_wp]*1._wp,clust(D,D)=[1.0_wp,1.0_wp,-1.0_wp,1.0_wp]*1._wp
end module
#include "./DMFT_mod_new.f90"
program main
	use M_DMFT
	implicit none
	integer :: j,i,jk,ii,ik,iw,id_,tmp(Ns),ord(nkD*Nc),iQ
	real(8) :: ff_(n),dTk,k1(D),k2(D),ek_tmp(nkD*Nc),et_,mg,val,dr(D),vl
	logical :: flag
	character(10) :: hostname
	compute => compute_
	i=hostnm(hostname)
	write(*,*)hostname

	call omp_set_nested(.false.)
	call omp_set_dynamic(.false.)
	call mkl_set_dynamic(0)

	!call omp_set_num_threads(mkl_get_max_threads())
	!call omp_set_num_threads(12)
	call mkl_set_num_threads(1)
	!call init_random_seed()
	call random_seed()
	if(this_image()==1) then
		open(unit=out_w,File="../data/fk_omega.dat")
		open(unit=out_T,File="../data/fk_order.dat")
		open(unit=out_lattice,file="../data/fk_lattice.dat")
		open(unit=out_pattern,File="../data/fk_pattern.dat")
		open(unit=out_kc,File="../data/fk_kc.dat")
		open(unit=out_k,File="../data/fk_k.dat")
		open(unit=out_r,File="../data/fk_r.dat")
		open(unit=out_check,File="../data/fk_check.dat")
	endif
	open(unit=inout_save,File="../data/fk_save.dat",status='old',access='stream',form='unformatted')

	U=14._wp
	self%mu=U*0.5_wp
	self%Ef=0._wp
	flag=.true.
	Tk=NAN

	null=compute(lattice); null=compute(omega_grid)
	do i=1,Nc
#ifdef cluster
		do j=1,Nc
			if(i==j) then
				self%Delta(1:n,i,j)=cmplx(0._wp,-1e-1_wp,kind=wp)
			else
				self%Delta(1:n,i,j)=cmplx(0._wp,0._wp,kind=wp)
			endif
		enddo
#else
		self%Delta(1:n,i)=cmplx(0._wp,-1e-1_wp,kind=wp)
		!self%Delta(1:n,i)=1._wp/(img*omega)
#endif
	enddo
	self%dSEc=cmplx(0._wp,0._wp,kind=wp)

	niter(SC_DMFT)=250; iter_err(SC_DMFT)=1e-6_wp; iter_rate(SC_DMFT)=0.1_wp
	niter(SC_dDMFT)=150; iter_err(SC_dDMFT)=5e-5_wp; iter_rate(SC_dDMFT)=0.1_wp
	niter(SC_cp)=500; iter_err(SC_cp)=1e-5_wp; iter_rate(SC_cp)=0.3_wp
	scheme=dDMFT
	call gen_graph(scheme)
	call self%io([out_lattice],[out_lattice])

	! initial
	!flag=.false.
	!read(inout_save)Tk,U,self%Delta,self%dSEc,self%mu,self%Ef
	!write(*,*)this_image(),Tk,self%Ef

	if(Nc>1) then
	!if(.false.) then
		Tk=0.5_wp
		do
			if(Tk<0.05_wp) then
				!Tk=0.05_wp
				Tk=Tk*2._wp
				exit
			endif
			if(flag.and.any(scheme==[dDMFT,dDMFT_all])) then
				call gen_graph(dDMFT_simp)
				self%conv=evaluate(nodes=[dSEc,Delta,inc],updated_nodes=[dSEc,Delta,Ef,mu,PMT])
				flag=.false.
				call gen_graph(scheme)
			endif
			if(any(scheme==[dDMFT_simp,dDMFT_simp_nc])) then
				call gen_graph(DMFT)
				self%conv=evaluate(nodes=[Delta,dSEc,inc],updated_nodes=[dSEc,Delta,Ef,mu,PMT])
				call gen_graph(scheme)
			endif
			self%conv=evaluate(nodes=[Delta,dSEc,inc],updated_nodes=[dSEc,Delta,Ef,mu,PMT])
			Tk=Tk/2._wp
		enddo
		!call self%self_consistent(0.1d0,[500,0],1d-5)
		!call set_Gfunction([set_fe])
		!call self%io([out_k,out_T,out_pattern],[out_k,out_T,out_pattern])
		if(Ns/=1) then
		!if(.false.) then
			do i=1,40
				if(this_image()==1) then
					write(*,*)"try: ",i
				endif
				!if(sum(abs(self%n_f-n_f))/Nc<5e-3_wp) then
				do iw=1,n
					call random_number(self%n_f(1:Ns))
					do j=1,Nc
						self%n_f(j)=self%n_f(mod(j-1,Ns)+1)
#ifdef cluster
						self%Delta(iw,j,j)=self%Delta(iw,j,j)+(self%n_f(j)-sum(self%n_f(1:Nc))/Nc)*0.01_wp*i*max(U/3._wp,1._wp)*1.5_wp
#else
						self%Delta(iw,j)=self%Delta(iw,j)+(self%n_f(j)-sum(self%n_f(1:Nc))/Nc)*0.01_wp*i*max(U/3._wp,1._wp)*1.5_wp
#endif
					enddo
				enddo
				!endif
				if(any(scheme==[dDMFT_simp,dDMFT_simp_nc])) then
					call gen_graph(DMFT)
					self%conv=evaluate(nodes=[Delta,dSEc,inc],updated_nodes=[dSEc,Delta,Ef,mu,PMT])
					call gen_graph(scheme)
				endif
				self%conv=evaluate(nodes=[Delta,dSEc,inc],updated_nodes=[dSEc,Delta,Ef,mu,PMT])
				if(sum(abs(self%n_f-sum(self%n_f)/Nc))/Nc<8e-3) then
				else
					exit
				endif
			enddo
			if(sum(abs(self%n_f-sum(self%n_f)/Nc))/Nc<8e-3) then
				if(this_image()==1) then
					write(*,*)"try again!"
				endif
				Tk=NAN
				!stop
			endif
		endif
	endif
	do i=1,-1,-2
		self%Sus=0._wp
		dTk=0.005_wp
		if(i==1.and.isnan(Tk)) then
			!if(i==1) then
			cycle
		endif
		if(i==1) then
			vl=sum(abs(self%n_f-sum(self%n_f)/Nc))/Nc
			if(isnan(Tk)) then
				Tk=0.05_wp
			endif
			Tk=Tk-dTk
		else
			vl=merge(maxval(real(self%Sus)),minval(real(self%Sus)),all(real(self%Sus)>=0._wp))
			if(isnan(Tk)) then
				Tk=0.2_wp
			else
				Tk=Tk+7._wp*dTk
			endif
			Tk=Tk+dTk
		endif
		do
			if(i==1) then
				if(vl<1e-4_wp) then
					exit
				endif
				if(abs(vl-sum(abs(self%n_f-sum(self%n_f)/Nc))/Nc)>0.015_wp) then
					dTk=max(dTk*0.5_wp,1e-4_wp)
				endif
				vl=sum(abs(self%n_f-sum(self%n_f)/Nc))/Nc
				Tk=Tk+dTk
			else
				vl=merge(maxval(real(self%Sus)),minval(real(self%Sus)),all(real(self%Sus)>=0._wp))
				if(vl<0._wp) then
					exit
				endif
				if(vl>0._wp) then
					dTk=min(max(1._wp/vl*0.04_wp,1e-4_wp),5e-3_wp)
				endif
				Tk=Tk-dTk
			endif

			if(any(scheme==[dDMFT_simp,dDMFT_simp_nc])) then
				call gen_graph(DMFT)
				self%conv=evaluate(nodes=[Delta,dSEc,inc],updated_nodes=[dSEc,Delta,Ef,mu,PMT])
				call gen_graph(scheme)
			endif

			if(.true.) then
			!if(i==-1) then
				self%conv=evaluate(nodes=[Sus,fs,fsd,inc,Delta],updated_nodes=[dSEc,Delta,Ef,mu,PMT])
				!self%conv=evaluate(nodes=[dGc,Delta],updated_nodes=[dSEc,Delta,Ef,mu,PMT])
			else
				self%conv=evaluate(nodes=[fsd,Delta],updated_nodes=[dSEc,Delta,Ef,mu,PMT])
			endif
			if(self%conv) then
				split_cp=.false.
				call gen_graph(scheme)
			else
				split_cp=.true.
				call gen_graph(scheme)
			endif
			call self%io([out_r,out_k,out_T,out_pattern],[out_r,out_k,out_T,out_pattern])
		enddo
	enddo
end program
