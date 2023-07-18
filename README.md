# How to get, compile and run SPS at the CMC.

Warning: this repository uses submodules. Make sure you follow the
instructions below.

## Getting sps git repository

### Choose one of the following methods:

1. cloning only the necessary components:
```
git clone git@gitlab.science.gc.ca:MIG/sps.git
cd sps
```

2. or cloning everything, including rpn-si libraries (rmn, vgrid, rpncomm, tdpack) in one step:
```
git clone --recursive git@gitlab.science.gc.ca:MIG/sps.git
cd sps
```

3. or cloning in several steps
```
git clone git@gitlab.science.gc.ca:MIG/sps.git
cd sps
```
Update rpn-si libraries and cmake_rpn submodules
```
git submodule update --init --recursive
```

## Choosing a version
```
git branch # what is the current branch
git branch -a # list all branches (look at the list of remote branches to choose from)
git tag # list tags (if you want to select a tagged version)
git checkout <hash|branch|tag> # checkout a branch, a tag, or a specific hash. Example: git checkout 5.3
```
Or, if you want, create your own branch from the current branch
```
git checkout -b mybranch
```

## Preparing sps compilation for Intel compiler
```
./scripts/link-dbase.sh
. ./.eccc_setup_intel
```

### or for gnu

Please note you cannot compile with Intel and then with GNU in the same shell
```
. ./.eccc_setup_gnu
```

Before the first build, or if you made important changes (such as updating
other submodules, or adding or removing source files):
```
. ./.initial_setup
```

## Building and installing SPS

There is a new script aimed at replacing the top-level Makefile.
For now, both still coexist.
See cado -h (short help) or cado help or the content of the Makefile for options.
For example: cado cmake or make cmake generates Makefiles to compile gem,
gemdyn, modelutils and rpnphy

Configure:
```
cado cmake
or 
make cmake
```

Compile:
```
cado build -j
or
make -j
```
Install in working directory
```
cado work -j
make -j work
```
cado work -j or make -j work can be used to compile and install in the same step.

In development mode, sps is compiled using Intel shared libraries: use the
following command to compile with static libraries:
```
cado cmake-static
```

See others options with cado -h (short help) or cado help

## Running SPS: example
cd $SPS_WORK
sps.sh --dircfg ./configurations/SPS_cfgs --ptopo 2x2x1 --inorder

## Structure of the working environment
The structure of the build and work directories is different whether the
$storage_model environment variable exists:

The following environment variables are created (examples):
- sps_DIR = directory where the git clone was created
- SPS_WORK = work directory
- SPS_ARCH = architecture, for example ubuntu-18.04-amd64-64-intel-2022.1.2
- COMPILER_SUITE = compiler suite, for example Intel
- COMPILER_VERSION = compiler version, for example 2022.1.2

- SPS_STORAGE_DIR = where build and work directories are situated
  - Example if $storage_model variable exists:
    - SPS_STORAGE_DIR=/local/storage/sps/ubuntu-18.04-amd64-64-intel-2022.1.2
    - in sps_DIR:
      - build-ubuntu-18.04-amd64-64-intel-2022.1.2 is a link, such as:
        /local/storage/sps/ubuntu-18.04-amd64-64-intel-2022.1.2/build
      - work-ubuntu-18.04-amd64-64-intel-2022.1.2 is a link, such as:
        /local/storage/sps/ubuntu-18.04-amd64-64-intel-2022.1.2/work

  - Example if $storage_model variable doesn't exist:
    - SPS_STORAGE_DIR=$HOME/sps/
    - directories situated in sps_DIR:
      - build-ubuntu-18.04-amd64-64-intel-2022.1.2
      - work-ubuntu-18.04-amd64-64-intel-2022.1.2
