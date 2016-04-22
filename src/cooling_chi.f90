!=======================================================================
!> @file cooling_chi.f90
!> @brief Cooling module with CHIANTI generated cooling curves
!> @author Alejandro Esquivel
!> @date 2/Nov/2014

! Copyright (c) 2014 A. Esquivel, M. Schneiter, C. Villareal D'Angelo
!
! This file is part of Guacho-3D.
!
! Guacho-3D is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see http://www.gnu.org/licenses/.
!=======================================================================

!> @brief Cooling module with CHIANTI generated cooling curves
!> @details Cooling module with CHIANTI generated cooling curves
!> @n The location of the tables is assumed to be in 
!! src/CHIANTIlib/coolingCHIANTI.tab

module cooling_chi

  implicit none
  real (kind=8), allocatable :: cooltab_chianti(:,:)

contains


!> @brief Initializes the DMC cooling
!> @details Declares variables and reads table

subroutine init_cooling_chianti()

  implicit none

  allocate(cooltab_chianti(2,41))
  call read_table_chianti()

end subroutine init_cooling_chianti

!=======================================================================

!> @brief Reads the cooling curve table
!> @details Reads the cooling curve table generated by CHUANTI,
!! the location is assumed in /src/CHIANTIlib/coolingCHIANTI.tab
 
subroutine read_table_chianti()

  use parameters, only : workdir, master
  use globals, only : rank
  implicit none
#ifdef MPIP
  include "mpif.h"
#endif
  integer :: i, err
  real (kind=8) :: a, b

  if(rank == master) then
     open(unit=10,file= trim(workdir)//'/src/CHIANTIlib/coolingCHIANTI.tab',status='old')
     do i=1,41
        read(10,*) a, b
        cooltab_chianti(1,i)=a
        cooltab_chianti(2,i)=b
     end do
     close(unit=10)
  endif
#ifdef MPIP
  call mpi_bcast(cooltab_chianti,82,mpi_double_precision,0,mpi_comm_world,err)
#endif

end subroutine read_table_chianti

!=======================================================================

!> @brief Returns the cooling coefficient interpolating the table
!> @param real [in] T : Temperature K

function coolchi(T)

  implicit none 
  real , intent(in) :: T
  integer           :: if1
  real (kind=8)     :: coolchi, T0, T1, C0, C1

  if(T.gt.1e8) then
    coolchi=0.21D-26*Sqrt(dble(T))
  else
    if1=int(log10(T)*10)-39
    T0=cooltab_chianti(1,if1)
    c0=cooltab_chianti(2,if1)
    T1=cooltab_chianti(1,if1+1)
    c1=cooltab_chianti(2,if1+1)
    coolchi=(c1-c0)*(dble(T)-T0)/(T1-T0)+c0
  end if

end function coolchi

!=======================================================================

!> @brief High level wrapper to apply cooling with CHIANTI tables
!> @details High level wrapper to apply cooling with CHIANTI tables
!> @n cooling is applied in the entire domain and updates both the 
!! conserved and primitive variables

subroutine coolingchi()

  use parameters, only : nx, ny, nz, cv, Psc, tsc
  use globals, only : u, primit, dt_CFL
  use hydro_core, only : u2prim
  implicit none
  real                 :: T ,Eth0, dens
  real, parameter      :: Tmin=10000.
  real (kind=8)        :: ALOSS, Ce
  integer              :: i, j, k
  real :: dt_seconds

  dt_seconds = dt_CFL*tsc

  do k=1,nz
     do j=1,ny
        do i=1,nx

           !   get the primitives (and T)
           call u2prim(u(:,i,j,k),primit(:,i,j,k),T)

           if(T > Tmin) then

              Eth0=cv*primit(5,i,j,k)

              Aloss=coolchi(T)
              dens=primit(1,i,j,k)
              Ce=(Aloss*dble(dens)**2)/(Eth0*Psc)  ! cgs

              !  apply cooling to primitive and conserved variables
              primit(5,i,j,k)=primit(5,i,j,k)*exp(-ce*dt_seconds)

              u(5,i,j,k)=u(5,i,j,k)-Eth0+cv*primit(5,i,j,k)

           end if

        end do
     end do
  end do

end subroutine coolingchi

!======================================================================

end module cooling_chi

!========================================================================
