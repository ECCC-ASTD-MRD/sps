SHELL = /bin/bash

# Makefile for Environment Canada systems
# Make sure you update the appropriate git submodules, according to what you want to build

default: build

MAKEFLAGS += --no-print-directory

# Using installed RPN libraries (rmn, vgrid, rpncomm, tdpack)
cmake:
	( cd build-${SPS_ARCH} && cd `/bin/pwd` && cmake -DWITH_SYSTEM_RPN=TRUE ${sps_DIR} )

# Compiling everything: you need to update rpn-si libraries (rmn, vgrid, rpncomm, tdpack) submodules to do this
cmake-all:
	( cd build-${SPS_ARCH} && cd `/bin/pwd` && cmake -DWITH_SYSTEM_RPN=FALSE ${sps_DIR} )

# with CMAKE_BUILD_TYPE=Debug
cmake-debug:
	( cd build-${SPS_ARCH} && cd `/bin/pwd` && cmake -DCMAKE_BUILD_TYPE=Debug -DWITH_SYSTEM_RPN=TRUE $${sps_DIR} )

# Extra debug (see extra checks defined in cmake_rpn compiler presets and in CMakeLists.txt)
cmake-debug-extra:
	( cd build-${SPS_ARCH} && cd `/bin/pwd` && cmake -DCMAKE_BUILD_TYPE=Debug -DWITH_SYSTEM_RPN=TRUE -DEXTRA_CHECKS=ON ${sps_DIR} )

.PHONY: build
build:
	( cd build-${SPS_ARCH} && cd `/bin/pwd` && $(MAKE) )

.PHONY: work
work: 
	( cd build-${SPS_ARCH} && cd `/bin/pwd` && $(MAKE) work )

package: 
	( cd build-${SPS_ARCH} && cd `/bin/pwd` && $(MAKE) package )

# make clean in build directory, to remove compiler and linker generated files
buildclean:
	( cd build-${SPS_ARCH} && cd `/bin/pwd` && $(MAKE) clean )

# Delete the build and work directories
distclean:
	. ./.clean_all


