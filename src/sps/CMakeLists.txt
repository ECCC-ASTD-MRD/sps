message(STATUS "(EC) Generating spsdyn libraries Makefile")

find_package(MPI)
if (MPI_FOUND)
   set(CMAKE_Fortran_COMPILER ${MPI_Fortran_COMPILER})
endif()

file(GLOB F_FILES src/base/*.F90)

set(CMAKE_Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/modules )

add_library(spsdyn STATIC ${F_FILES})

target_include_directories(spsdyn PRIVATE
   include
   ${tdpack_INCLUDE_DIRS}
   ${vgrid_INCLUDE_DIRS}
   ${rmn_INCLUDE_DIRS}
   ${rpncomm_INCLUDE_DIRS}
   ${rpncomm_GEN_INCLUDE_DIR}
   ${modelutils_INCLUDE_DIRS}
   ${modelutils_MODULES_DIR}
   ${phy_INCLUDE_DIRS}
   ${phy_MODULES_DIR}
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
   ${phy_LIBRARIES}
   ${cpl_LIBRARIES}
   ${chm_LIBRARIES}
   modelutils
   modelutils_tmg_stubs
   modelutils_ov_ifort
   vgrid
   tdpack
   rpncomm
   rmn
   ${LAPACK_LIBRARIES}
   ${BLAS_LIBRARIES}
)

add_dependencies(mainspsdm spsdyn ${phy_SRC} modelutils ${vgrid_SRC} ${rpncomm_SRC} ${rmn_SRC})

install(TARGETS mainspsdm RUNTIME DESTINATION bin)
