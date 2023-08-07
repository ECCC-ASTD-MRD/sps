# Note to CMC users

Please use the official repository. This repo is configured for external users.

# Instructions in a nutshell

**See below for extended instructions.**

## Requirements

To compile and run SPS, you will need:
- Fortran and C compilers
- An MPI implementation such as OpenMPI (with development package),
- OpenMP support (optional)
- (BLAS,LAPACK) or equivalent mathematical/scientific library (ie: MKL), with development package,
- basic Unix utilities such as cmake (version 3.20 minimum), bash, sed, etc.

```
# clone everything, including libraries and tools included as git submodules
git clone --branch 6.2 --recursive https://github.com/ECCC-ASTD-MRD/sps.git
cd sps

# If you cloned without the --recursive option above, update submodules:
git submodule update --init --recursive

# Download the data files required to run SPS (around 3 GB)
./download-dbase.sh .

# Important: in order to set environment variables needed to run SPS, use the
# following setup file, after setting up your compiler environment:
. ./.common_setup gnu
# or
. ./.common_setup intel
	
# Method 1 - Create a build directory
# The build directory has very little value in itself and can be placed
# outside the project directory
mkdir -p build
cd build
# default compiler is gnu
cmake ..
# Create an execution environment for SPS
make -j work

# Method 2 - Alternatively, you can use a script that will create a build
# and work directory named after the computer operating system and the
# compiler suite used, without having to create a build directory as
# mentioned in Method 1 above.  In that case, you can then use the cado
# script, using the commands cado cmake and cado work -j directly, without
# having to move to the build directory:
# in the main directory:
. ./.initial_setup
cado cmake
cado work -j

# Either with Method 1 or 2, you should now have a work directory in the
# main directory of sps, created with a name in the form of: 
# work-[OS_NAME]-[COMPILER_NAME]
cd work-[OS_NAME]-[COMPILER_NAME]
or 
cd $SPS_WORK

# Run the model, for example:
sps.sh --dircfg configurations/SPS_cfgs --ptopo 2x2x1 --inorder

# To see or list the records in the output files, use either of our tools, 
# voir, fststat, SPI or xrec, available in other repositories:

voir -iment RUNMOD/output/cfg_0000/ ...
fststat -fst RUNMOD/output/cfg_0000/ ...
```

voir and fststat are available here:
https://github.com/ECCC-ASTD-MRD/fst-tools

[SPI](https://github.com/ECCC-ASTD-MRD/SPI) can be used to view the output
files.

2D fields can also be displayed with
[xrec](https://github.com/ECCC-ASTD-MRD/xrec)

-----------------------------------------------------------------
# Extended instructions:

## Requirements

To compile and run SPS, you will need:
- Fortran and C compilers
- An MPI implementation such as OpenMPI (with development package),
- OpenMP support (optional)
- (BLAS,LAPACK) or equivalent mathematical/scientific library (ie: MKL), with development package,
- basic Unix utilities such as cmake (version 3.20 minimum), bash, sed, etc.

## Data for examples

After having cloned or downloaded the git tar file of SPS from
[github.com](https://github.com/ECCC-ASTD-MRD/sps), execute the script named
**download-dbase.sh** or download and untar the data archive with the following
link:
[http://collaboration.cmc.ec.gc.ca/science/outgoing/goas/sps_dbase.tar.gz](http://collaboration.cmc.ec.gc.ca/science/outgoing/goas/sps_dbase.tar.gz)

## Compiler specifics

### GNU compiler suite
- By default SPS is configured to use gfortran and gcc compilers, and OpenMPI
- Changes to the C and Fortran flags can be done in the  **CMakeLists.txt**
  file, under the section **# Adding specific flags for SPS**.
- You can also check  the C and Fortran flags in **cmake_rpn/modules/ec_compiler_presets/default/Linux-x86_64/gnu.cmake**
- Make sure the compilers and libraries paths are set in the appropriate
  environment variables (PATH and LD_LIBRARY_PATH).  Here are some examples
  of commands, which you will need to adapt for your setup:
  - On Ubuntu:
  
```
    export PATH=/usr/lib/openmpi/bin:${PATH}
    export LD_LIBRARY_PATH=/usr/lib/openmpi/lib:$LD_LIBRARY_PATH
# or
    export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/openmpi/lib:$LD_LIBRARY_PATH
```

  - On Fedora:

```
    export PATH=/usr/lib64/openmpi/bin:$PATH
    export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:$LD_LIBRARY_PATH
```

### Intel compiler suite

- Changes to the C and Fortran flags can be done in the  **CMakeLists.txt**
  file, under the section **# Adding specific flags for SPS**.
- You can also check  the C and Fortran flags in **cmake_rpn/modules/ec_compiler_presets/default/Linux-x86_64/intel.cmake**
- You may need to modify ```-march``` to generate code that can run on your
  system
- Make sure the compilers and libraries are in the appropriate
  environment variables (```PATH``` and ```LD_LIBRARY_PATH```)
- As gnu is the default compiler suite, you may have to use the following
  command to compile with Intel: ```cmake .. -DCOMPILER_SUITE=intel```

## Compiling and installing SPS

You can add extra CMake arguments such as```-DCMAKE_VERBOSE_MAKEFILE=ON```.

You can also add ```-j``` to **make** to launch multiple compile tasks in
parallel.

[OpenMP](https://www.openmp.org/) is enabled by default.  If you wish to build
without OpenMP support, you can add the ```-DWITH_OPENMP=OFF``` argument when
running **cmake**.

The default compiler suite is GNU. If you want to compile with other compilers,
add ```-DCOMPILER_SUITE=<compiler suite name (gnu|intel|...)>``` to the CMake
command line.  

This release has been tested with GNU and Intel compilers on Linux x86_64.
Other compilers have also been used in the past, but have not been tested
with the current release.  You will likely have to modify the *.cmake files
in the **cmake_rpn/modules/ec_compiler_presets/default/** folder.

If you get error messages (for example, compiler, OpenMP or MPI/OpenMPI not
found), make sure that the ```PATH``` and ```LD_LIBRARY_PATH``` environment
variables contain the appropriate paths.  You can also add
```-DCMAKE_VERBOSE_MAKEFILE=ON``` to your **cmake** command line to generate
verbose makefiles which will print the exact compiler command lines issued.

If the compiler or compile options are not right:
- Remove the content of the build directory
- Make appropriate changes to the cmake files corresponding to the
  compilers you are using
- Re-launch the commands starting at cmake

The installation process will create a directory named after the operating system
on which the compilation was executed, and the compiler you used
(work-[OS_NAME]-[COMPILER_NAME]). For example
*work-FedoraLinux-37-x86_64-gnu-12.3.1* would be created in the main directory,
and the following executables installed in the *bin* sub-folder: 
- cclargs_lite
- feseri
- flipit
- mainspsdm
- prphynml
- yy2global
- yydecode
- yyencode

A script named sps-config is also installed. It displays a summary of the
architecture, compiler, and flags used.

## Structure of the working environment

The following environment variables are created:
- sps_DIR = directory where the git clone was created
- SPS_WORK = work directory
- SPS_ARCH = architecture, for example FedoraLinux-37-x86_64-gnu-12.3.1
- SPS_MODEL_DFILES = sps database directory
- COMPILER_SUITE = compiler suite, for example gnu
- COMPILER_VERSION = compiler version, for example 12.3.1

## Running SPS

Go to the working directory, named *work-[OS_NAME]-[COMPILER_NAME]*, for
example *work-FedoraLinux-37-x86_64-gnu-12.3.1*

```
cd work-[OS_NAME]-[COMPILER_NAME]
or
cd $SPS_WORK
# Execute the model for a specific case, for example:
sps.sh --dircfg configurations/SPS_cfgs --ptopo 2x2x1
```

*sps.sh* ```-ptopo``` argument can be used to specify the number of CPU to
use.  For example,  ```-ptopo 2x2x1``` will use 4 cpus for a LAM, and
8 cpus for global Yin-Yang.

If you get an error message saying sps.sh or sps_dbase is not found, make
sure to set the environment variables using the setup file situated in the
main directory:

```
./.common_setup gnu
# or
./.common_setup intel
```

An in-house script (**r.run_in_parallel**) is used to run the model. If you
want to use another command, or if it doesn't work in your environment, edit
the file *scripts/sps.sh* to change the script.

See **README** in the work directory for other information on the different configurations.

## Working with model outputs

The model stores its outputs in FST files.  The following tools can be used
to perform various tasks on the output files. They are available for
download and installation here: https://github.com/ECCC-ASTD-MRD/fst-tools

- ```voir``` lists the records in FST files:
  ```
  voir -iment RUNMOD.dir/output/cfg_0000/...
  ```

- ```fststat``` produces statistical means of the records in a FST file:
  ```
  fststat -fst RUNMOD.dir/output/cfg_0000/...
  ```

[SPI](https://github.com/ECCC-ASTD-MRD/SPI-Bundle) is a scientific and
meteorological virtual globe offering processing, analysis and visualization
capabilities, with a user interface similar to Google Earth and NASA World
Wind, developed by Environment Canada.

[xrec](https://github.com/ECCC-ASTD-MRD/xrec) is another visualization
program which can be used to display 2D meteorological fields stored in the
FST files, developed by Research Informatics Services, Meteorological
Research Division, Environment and Climate Change Canada.

## Configurations files

The execution of all three components of SPS is configurable through the use
of three configuration files called:
- sps.cfg: file containing some namelists to configure the model execution
- outcfg.out: file used to configure the model output
- configexp.cfg: file used to configure the execution shell environment

Examples of these files can be found in the test cases in the configurations
directory.

A fourth configuration file is physics_input_table.

## Running your own configuration

Put the three configurations files (sps.cfg, outcfg.out and configexp.cfg)
in a directory structure such as: **experience/cfg_0000** in the
configurations directory.

The master directory name (**experience** in the example above) can be
any valid directory name. However, the second directory must have the name
\textit{cfg\_0000}.

Then use the sps.sh script to run the model:

```
cd work-[OS_NAME]-[COMPILER_NAME]
sps.sh --dircfg configurations/experience
```
