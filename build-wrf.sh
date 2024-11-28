#!/bin/bash

# Set variables
WRF_ROOT=~/build_wrf
WRF_LIBS=${WRF_ROOT}/libraries
WRF_DEPS_BUILD_DIR=~/wrf_deps_builds

# Check if an argument was passed
if [ $# -ne 0 ]; then
    
    case "$1" in
        "clean")
            echo "Running clean workflow"
            rm -rf ${WRF_ROOT}
            rm -rf ${WRF_DEPS_BUILD_DIR}
            exit 0
            ;;
        *)
            echo "Error: Invalid argument. Supported arguments are: clean"
            exit 1
            ;;
    esac
fi

# Install requirements
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y build-essential csh m4 cmake gcc gfortran libjpeg-dev libssl-dev libpsl-dev

MPICH_ROOT=${WRF_DEPS_BUILD_DIR}/mpich3
MPICH_INSTALL_DIR=${WRF_LIBS}/mpich3
MPICH_BIN=${MPICH_INSTALL_DIR}/bin

ZLIB_ROOT=${WRF_DEPS_BUILD_DIR}/zlib
ZLIB_INSTALL_DIR=${WRF_LIBS}/zlib
ZLIB_BIN=${ZLIB_INSTALL_DIR}/bin

H5_ROOT=${WRF_DEPS_BUILD_DIR}/hdf5
H5_INSTALL_DIR=${WRF_LIBS}/hdf5
export HDF5=${H5_INSTALL_DIR}
H5_BIN=${ZLIB_INSTALL_DIR}/bin

CURL_ROOT=${WRF_DEPS_BUILD_DIR}/curl
CURL_INSTALL_DIR=${WRF_LIBS}/curl
CURL_BIN=${CURL_INSTALL_DIR}/bin

NC_ROOT=${WRF_DEPS_BUILD_DIR}/netcdf
NC_INSTALL_DIR=${WRF_LIBS}/netcdf
export NETCDF=${NC_INSTALL_DIR}
NC_BIN=${NC_INSTALL_DIR}/bin

PNG_ROOT=${WRF_DEPS_BUILD_DIR}/libpng
PNG_INSTALL_DIR=${WRF_LIBS}/grib2
PNG_BIN=${PNG_INSTALL_DIR}/bin

JASPER_ROOT=${WRF_DEPS_BUILD_DIR}/jasper
JASPER_INSTALL_DIR=${WRF_LIBS}/grib2
JASPER_BIN=${JASPER_INSTALL_DIR}/bin

export JASPERINC=${JASPER_INSTALL_DIR}/include
export JASPERLIB=${JASPER_INSTALL_DIR}/lib

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

# Create directories
create_directory ${WRF_ROOT}
create_directory ${WRF_LIBS}
create_directory ${WRF_DEPS_BUILD_DIR}

# Change dir to start building dependencies
cd ${WRF_DEPS_BUILD_DIR}

# MPICH
create_directory ${MPICH_ROOT}
cd ${MPICH_ROOT}
wget https://www.mpich.org/static/downloads/4.2.3/mpich-4.2.3.tar.gz
tar xfz mpich-4.2.3.tar.gz
mkdir mpich_build && cd mpich_build
../mpich-4.2.3/configure --prefix=${MPICH_INSTALL_DIR}
make 
make install

# Add MPICH to the PATH
export PATH=${MPICH_BIN}:${PATH}

# Review where the binaries are read from
echo "which mpicc says: " `which mpicc`
echo "which mpicc says: " `which mpiexec`

# Run a couple of quick tests to verify it is working
mkdir ${MPICH_ROOT}/mpi_testing && cd ${MPICH_ROOT}/mpi_testing
mpiexec -hosts 127.0.0.1 -n 1 hostname
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
export PATH=${ZLIB_BIN}:${PATH}

# Prepping for netCDF - moving on to HDF5
cd ${WRF_DEPS_BUILD_DIR}

create_directory ${H5_ROOT}
cd ${H5_ROOT}
wget https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5_1.14.5.tar.gz
tar xfz hdf5_1.14.5.tar.gz
mkdir hdf5_build && cd hdf5_build
# don't forget Fortran: https://forum.mmm.ucar.edu/threads/error-cannot-find-lhdf5_hl_fortran-and-lhdf5_fortran.16060/
../hdf5-hdf5_1.14.5/configure --with-zlib=${ZLIB_INSTALL_DIR} --prefix=${H5_INSTALL_DIR} --enable-hl --enable-fortran
make check
make install

# Add HDF5 to the PATH
export PATH=${H5_BIN}:${PATH}

# Prepping for netCDF - moving on to CURL
cd ${WRF_DEPS_BUILD_DIR}

create_directory ${CURL_ROOT}
cd ${CURL_ROOT}
wget https://curl.se/download/curl-8.10.1.tar.gz
tar xfz curl-8.10.1.tar.gz
mkdir curl_build && cd curl_build
../curl-8.10.1/configure --prefix=${CURL_INSTALL_DIR} --with-openssl
make 
make install

# Add CURL to the PATH - maybe not really necessary?
export PATH=${CURL_INSTALL_DIR}/lib:${PATH}

# Time for netCDF
cd ${WRF_DEPS_BUILD_DIR}

create_directory ${NC_ROOT}
cd ${NC_ROOT}
# do the C first!
wget https://downloads.unidata.ucar.edu/netcdf-c/4.9.2/netcdf-c-4.9.2.tar.gz
tar xzf netcdf-c-4.9.2.tar.gz
mkdir netcdf-c-build && cd netcdf-c-build
CPPFLAGS="-I${H5_INSTALL_DIR}/include -I${ZLIB_INSTALL_DIR}/include -I${CURL_INSTALL_DIR}/include" LDFLAGS="-L${H5_INSTALL_DIR}/lib -L${ZLIB_INSTALL_DIR}/lib -L${CURL_INSTALL_DIR}/lib" ../netcdf-c-4.9.2/configure --prefix=${NC_INSTALL_DIR} --disable-libxml2
make check
make install

# Add netCDF to the PATH
export PATH=${NC_BIN}:${PATH}

# Now do the Fortran
wget https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.1/netcdf-fortran-4.6.1.tar.gz
tar xzf netcdf-fortran-4.6.1.tar.gz
mkdir netcdf-f-build && cd netcdf-f-build
CPPFLAGS="-I${NC_INSTALL_DIR}/include" LDFLAGS="-L${NC_INSTALL_DIR}/lib" ../netcdf-fortran-4.6.1/configure --prefix=${NC_INSTALL_DIR}
make check
make install

# netCDF is already in the PATH

# Let's do libpng
cd ${WRF_DEPS_BUILD_DIR}

create_directory ${PNG_ROOT}
cd ${PNG_ROOT}
wget https://download.sourceforge.net/libpng/libpng-1.6.44.tar.gz
tar xzf libpng-1.6.44.tar.gz
mkdir libpng-buil && cd libpng-build
../libpng-1.6.44/configure --prefix=${PNG_INSTALL_DIR}
make
make install

# Add libpng to the PATH
export PATH=${PNG_BIN}:${PATH}

# Finally, do JASPER
cd ${WRF_DEPS_BUILD_DIR}

create_directory ${JASPER_ROOT}
git clone git@github.com:jasper-software/jasper.git
mkdir jasper-build && cd jasper-build
cmake ../jasper -DJAS_ENABLE_SHARED=true -DCMAKE_INSTALL_PREFIX=${JASPER_INSTALL_DIR} -DALLOW_IN_SOURCE_BUILD=on
cmake --build .
make clean all
make test
make install

# Are we really ready to go now?
cd ${WRF_ROOT}

git clone git@github.com:wrf-model/WRF.git
cd WRF
export WRFIO_NCD_LARGE_FILE_SUPPORT=1

# # From this point onward, it's best
# # to run interactively?
# ./configure
# selected (serial) for GCC AArch64 + no nesting
# ./compile em_real >& log.compile &

# # Presumably, WRF is done and dusted.
# # Move on to WPS
# cd ${WRF_ROOT}

# wget https://github.com/wrf-model/WPS/archive/refs/tags/v4.6.0.tar.gz
# tar xzf v4.6.0.tar.gz
# cd WPS-4.6.0
# ./configure

# at this point, more interaction is advised (?)
# see https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compilation_tutorial.php#STEP4
