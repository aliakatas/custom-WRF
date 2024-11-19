#!/bin/bash

# # Install requirements
# sudo apt update && sudo apt full-upgrade -y
# sudo apt install -y build-essential csh m4 cmake gcc gfortran libjpeg-dev

# Set variables
WRF_ROOT=~/build_wrf
WRF_LIBS=${WRF_ROOT}/libraries
WRF_DEPS_BUILD_DIR=~/wrf_deps_builds

MPICH_ROOT=${WRF_DEPS_BUILD_DIR}/mpich3
MPICH_INSTALL_DIR=${WRF_LIBS}/mpich3
MPICH_BIN=${MPICH_INSTALL_DIR}/bin

ZLIB_ROOT=${WRF_DEPS_BUILD_DIR}/zlib
ZLIB_INSTALL_DIR=${WRF_LIBS}/zlib
ZLIB_BIN=${ZLIB_INSTALL_DIR}/bin

# ********************************************
echo "WRF Root is: " ${WRF_ROOT}
echo "WRF libraries are located in: " ${WRF_LIBS}
echo "WRF dependencies will be built here: " ${WRF_DEPS_BUILD_DIR}

# Some useful function(s)
create_directory() {
    local dir_path="$1"
    
    # Check if directory path is provided
    if [ -z "$dir_path" ]; then
        echo "Error: Directory path not provided"
        return 1
    fi

    if [ -d "$dir_path" ]; then
        echo "$dir_path already exists"
        return 0
    else
        # Attempt to create the directory
        mkdir -p "$dir_path"
        
        # Check if directory creation was successful
        if [ $? -eq 0 ]; then
            echo "Directory '$dir_path' created successfully"
            return 0
        else
            echo "Error: Failed to create directory '$dir_path'"
            return 1
        fi
    fi
}

# # Create directories
# create_directory ${WRF_ROOT}
# create_directory ${WRF_LIBS}
# create_directory ${WRF_DEPS_BUILD_DIR}

# # Change dir to start building dependencies
# cd ${WRF_DEPS_BUILD_DIR}

# # MPICH
# create_directory ${MPICH_ROOT}
# cd ${MPICH_ROOT}
# wget https://www.mpich.org/static/downloads/4.2.3/mpich-4.2.3.tar.gz
# tar xfz mpich-4.2.3.tar.gz
# mkdir mpich_build && cd mpich_build
# ../mpich-4.2.3/configure --prefix=${MPICH_INSTALL_DIR}
# make 
# make install

# Add MPICH to the PATH
PATH=${MPICH_BIN}:${PATH}

# Review where the binaries are read from
echo "which mpicc says: " `which mpicc`
echo "which mpicc says: " `which mpiexec`

# # Run a couple of quick tests to verify it is working
# mkdir ${MPICH_ROOT}/mpi_testing && cd ${MPICH_ROOT}/mpi_testing
# mpiexec -hosts 127.0.0.1 -n 1 hostname
mpiexec -hosts 127.0.0.1 -n 2 ${MPICH_ROOT}/mpich_build/examples/cpi

# Prepping for netCDF - with ZLIB
cd ${WRF_DEPS_BUILD_DIR}

create_directory ${ZLIB_ROOT}
cd ${ZLIB_ROOT}
wget https://www.zlib.net/zlib-1.3.1.tar.gz
tar xfz zlib-1.3.1.tar.gz
mkdir zlib_build && cd zlib_build
../zlib-1.3.1/configure --prefix=${ZLIB_INSTALL_DIR}
make install

# Add ZLIB to the PATH
PATH=${ZLIB_BIN}:${PATH}


