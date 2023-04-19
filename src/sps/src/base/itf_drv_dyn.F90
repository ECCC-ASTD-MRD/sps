
!/@*
function dyn_grid_init(F_ni,F_nj,F_halox,F_haloy,F_periodx,F_periody,F_grid_id) result(F_istat)
   use dyn_grid_mod, only: local_grid_init => dyn_grid_init
   implicit none
   !@objective Provide grid size info for the dyn grid/tile
   !@arguments
   integer,intent(out) :: F_ni,F_nj           !- Dyn Tile Grid dims
   integer,intent(out) :: F_halox,F_haloy     !- Dyn Tile Halo Dims
   logical,intent(out) :: F_periodx,F_periody !- Dyn Grid Periodicity
   integer,intent(out) :: F_grid_id           !- ezscing grid id
   !@return
   integer :: F_istat
   !*@/
   !---------------------------------------------------------------------
   F_istat = local_grid_init(F_ni,F_nj,F_halox,F_haloy,F_periodx,F_periody,F_grid_id)
   !---------------------------------------------------------------------
   return
end function dyn_grid_init

!/@*
function dyn_grid_post_init(F_imin,F_imax,F_jmin,F_jmax,F_ni,F_nj) result(F_istat)
   use dyn_grid_mod, only: local_grid_post_init => dyn_grid_post_init
   implicit none
   !@objective Check dims and Compute grid point positions
   !@arguments
   integer,intent(in) :: F_imin,F_imax,F_jmin,F_jmax !- DynTile dims
   integer,intent(in) :: F_ni,F_nj                   !- Computational Dims
   !@return
   integer :: F_istat
   !*@/
   !---------------------------------------------------------------------
   F_istat = local_grid_post_init(F_imin,F_imax,F_jmin,F_jmax,F_ni,F_nj)
   !---------------------------------------------------------------------
   return
end function dyn_grid_post_init

!/@*
function dyn_dxdy(F_dxdy,F_i0,F_j0,F_ni,F_nj) result(F_istat)
   use dyn_grid_mod, only: local_dxdy => dyn_dxdy
   implicit none
   !@objective 
   !@arguments
   integer,intent(in) :: F_i0,F_j0,F_ni,F_nj
   real,pointer,intent(inout) :: F_dxdy(:,:)
   !@return
   integer :: F_istat
   !*@/
   !---------------------------------------------------------------------
   F_istat = local_dxdy(F_dxdy,F_i0,F_j0,F_ni,F_nj)
   !---------------------------------------------------------------------
   return
end function dyn_dxdy


!/@*
function dyn_levels_init(F_nk,F_vcoor,F_stag_L,F_surf_idx) result(F_istat)
   use vGrid_Descriptors
   use dyn_levels_mod, only: local_levels_init => dyn_levels_init
   implicit none
   !@objective 
   !@arguments
   integer,intent(out) :: F_nk,F_surf_idx
   type(vgrid_descriptor),intent(out) :: F_vcoor
   logical,intent(out) :: F_stag_L
   !@return
   integer :: F_istat
   !*@/
   !---------------------------------------------------------------------
   F_istat = local_levels_init(F_nk,F_vcoor,F_stag_L,F_surf_idx)
   !---------------------------------------------------------------------
   return
end function dyn_levels_init
