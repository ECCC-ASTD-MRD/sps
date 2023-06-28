message(STATUS "(EC) Generating spsdyn libraries Makefile")

find_package(MPI)
if (MPI_FOUND)
   set(CMAKE_Fortran_COMPILER ${MPI_Fortran_COMPILER})
   set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} ${MPI_COMPILER_FLAGS}")
endif()

file(GLOB F_FILES src/base/*.F90)

set(CMAKE_Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/modules )

add_library(spsdyn STATIC ${F_FILES})

target_include_directories(spsdyn PRIVATE
   include
)
target_link_libraries(spsdyn PRIVATE
   modelutils
   modelutils_tmg_stubs
   modelutils_ov_ifort
   ${phy_LIBRARIES}
   ${cpl_LIBRARIES}
   ${chm_LIBRARIES}
)

if ("${CMAKE_Fortran_COMPILER_ID}" STREQUAL "GNU")
  if (EXTRA_CHECKS AND "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    target_compile_options(spsdyn PRIVATE "$<$<AND:$<CONFIG:Debug>,$<COMPILE_LANGUAGE:Fortran>>:-fcheck=bounds>" )
    message(STATUS "(EC) Extra debug flags for spsdyn: -fcheck=bounds")
  endif()
endif()

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/include/sps_version.in ${CMAKE_CURRENT_SOURCE_DIR}/include/sps_version.inc @ONLY)

message(STATUS "(EC) Generating mainspsdm Makefile")

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/src/main/mainspsdm.in ${CMAKE_CURRENT_SOURCE_DIR}/src/main/mainspsdm.F90)

add_executable(mainspsdm src/main/mainspsdm.F90)

target_link_libraries(mainspsdm
   spsdyn
   vgrid::vgrid
   tdpack::tdpack
   rpncomm::rpncomm
   rmn::rmn-ompi
   OpenMP::OpenMP_Fortran
   MPI::MPI_Fortran
   ${LAPACK_LIBRARIES}
   ${BLAS_LIBRARIES}
)

target_link_libraries(modelutils PRIVATE modelutils_tmg_stubs)
target_link_libraries(rpnphy PRIVATE modelutils_ov_ifort)

install(TARGETS mainspsdm RUNTIME DESTINATION bin)
