# Custom WRF deployment
In this repo, the steps to deploy the Weather Research and Forecasting model (WRF) are documented.
The main goal is to set up the system on a Raspberry Pi 4. 
The [blog post](https://chrisdearden.net/WRFRPi/) from Chris Dearden is used for guidance, as well as the [official tutorial](https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compilation_tutorial.php).

## Hardware specs
+ Host: Raspberry Pi 4 Model B Rev 1.4 
+ CPU: (4) @ 1.800 GHz 
+ Memory: 3791 MiB 
+ OS: Debian GNU/Linux 12 (bookworm) aarch64

## Requirements
Before building WRF, the following dependencies/libraries will need to be built and installed. 
The libraries are the following:
1. [MPICH](https://www.mpich.org/) a portable implementation of MPI.
2. [netCDF](https://www.unidata.ucar.edu/software/netcdf/) library to support reading and writing files with array-oriented scientific data.
3. [m4](https://www.gnu.org/software/m4/m4.html) a general-purpose macro processor that can be used to preprocess C and assembly language programs.
4. [zlib](https://zlib.net/) a (de-)compression library.
5. [libpng](http://www.libpng.org/pub/png/) a library to support the Portable Network Graphics format.
6. [jasper](https://github.com/jasper-software/jasper) collection of libraries and apps to code and manipulate various image formats.

As a first attempt, we will try building the system using GNU Fortran and C compilers.
At a later stage, once we get familiar with the process, we will try using Intel's oneAPI compilers.

In addition to the [WRF code](https://github.com/wrf-model/WRF), we will be needing the code for the WRF Pre-Processing System (WPS) from the official [Github page](https://github.com/wrf-model/WPS).

## Build Steps
The parts describing the process of building and installing the dependencies can be fully automated using [this script](./build-wrf.sh).

1. Let's start by updating our system and making sure that all the necessary packages are installed:
   ```bash
   sudo apt update && sudo apt full-upgrade -y
   sudo apt install -y build-essential csh m4 cmake gcc gfortran libjpeg-dev libssl-dev libpsl-dev
   ```

2. To keep things tidy, let's create some variables to work with:
   ```bash
   WRF_ROOT=~/build_wrf
   WRF_LIBS=${WRF_ROOT}/libraries
   WRF_DEPS_BUILD_DIR=~/wrf_deps_builds
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
   ```
   You will notice that some variables are exported. This is required to allow the build system for WRF and WPS to be able to pick up the correct paths.
   
3. Before drilling down to the dependencies, create the folders:
   ```bash
   mkdir -p ${WRF_ROOT}
   mkdir -p ${WRF_LIBS}
   mkdir -p ${WRF_DEPS_BUILD_DIR}
   ```
   The installation folder for all the libraries is goign to be `WRF_LIBS`, whereas `WRF_DEPS_BUILD_DIR` is for building them.

### MPICH
Time to build MPICH. There is an excellent [guide](https://www.southampton.ac.uk/~sjc/raspberrypi/pi_supercomputer_southampton.htm) from Prof Simon Cox, but it has a wider scope.
In summary, we need to perform the following steps using the latest version at the time of writing (mpich 4.2.3). Alternatively, use the [official Github repo](https://github.com/pmodels/mpich).

1. Firstly, create some folders:
   ```bash
   mkdir -p ${MPICH_ROOT} && cd ${MPICH_ROOT}
   ```

2. Then, download the source code from [here](https://www.mpich.org/downloads/):
   ```bash
   wget https://www.mpich.org/static/downloads/4.2.3/mpich-4.2.3.tar.gz
   ```

3. Decompress the tarball:
   ```bash
   tar xfz mpich-4.2.3.tar.gz
   ```

4. ...and create a build directory:
   ```
   mkdir mpich_build && cd mpich_build
   ```

5. Run the following to configure the package (ready for build) and define the installation folder:
   ```bash
   ../mpich-4.2.3/configure --prefix=${MPICH_INSTALL_DIR}
   ```

6. Ready to build MPICH, so go ahead and run:
   ```bash
   make
   ```
   Be prepared to wait for a good few hours...

7. Finally, install the package:
   ```bash
   make install
   ```

8. At this point MPCIH should be installed, so let's add it to our $PATH:
   ```bash
   export PATH=${MPICH_INSTALL_DIR}/bin:$PATH
   ```

9.  To make sure that the library has been installed correctly, run the following:
   ```bash
   which mpicc
   which mpiexec
   ```

10. Create a directory and move into it to run some tests for MPICH:
   ```bash
   mkdir -p ${MPICH_ROOT}/mpi_testing && cd ${MPICH_ROOT}/mpi_testing
   ```

11. Now run the single-node test with the following:
   ```bash
   mpiexec -hosts 127.0.0.1 -n 1 hostname
   ```
   This should return "raspberrypi" or the hostname of your device.

12. Now run another test using one of the examples provided in C (calculate pi):
   ```bash
   mpiexec -hosts 127.0.0.1 -n 2 ${MPICH_ROOT}/mpich_build/examples/cpi
   ```
   The return message should look like this:
   ```bash
   Process 0 of 2 is on raspberrypi
   Process 1 of 2 is on raspberrypi
   pi is approximately 3.1415926544231318, Error is 0.0000000008333387
   wall clock time = 0.000214
   ```

### NetCDF
NetCDF can be downloaded from [unidata](https://downloads.unidata.ucar.edu/netcdf/) and there is some useful documentation [here](https://docs.unidata.ucar.edu/nug/current/getting_and_building_netcdf.html). 
We will be needing both netcdf-c and netcdf-fortran for our build. The latest versions at this time are netcdf-c 4.9.2 and netcdf-fortran 4.6.1.
The official repos for netCDF-C and netCDF-Fortran can be found on [Github](https://github.com/Unidata).

Since we want support for netCDF-4 and parallel I/O operations, we need to download and build HDF5, zlib and curl. So, before proceeding with netCDF, let's do that.

#### ZLIB
The library can be downloaded [here](https://www.zlib.net/) and the latest version at the time of writing is 1.3.1.
1. Create some folders:
   ```bash
   mkdir -p ${ZLIB_ROOT} && cd ${ZLIB_ROOT}
   ```

2. Then, download the source code:
   ```bash
   wget https://www.zlib.net/zlib-1.3.1.tar.gz
   ```

3. Decompress the tarball:
   ```bash
   tar xfz zlib-1.3.1.tar.gz
   ```

4. ...and create a build directory:
   ```
   mkdir zlib_build && cd zlib_build
   ```

5. Run the following to configure the package (ready for build) and define the installation folder:
   ```bash
   ../zlib-1.3.1/configure --prefix=${ZLIB_INSTALL_DIR}
   ```

6. Ready to build and install ZLIB, so go ahead and run:
   ```bash
   make install
   ```

#### HDF5
The library can be downloaded [here](https://www.hdfgroup.org/download-hdf5/source-code/) and the latest version at the time of writing is 1.14.5. Mind that it might require a user account (free to register). 
Alternatively, head to [HDF5-Github](https://github.com/HDFGroup/hdf5) and clone away!

1. Create some folders:
   ```bash
   mkdir -p ${H5_ROOT} && cd ${H5_ROOT}
   ```

2. Then, download the source code:
   ```bash
   wget https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5_1.14.5.tar.gz
   ```

3. Decompress the tarball:
   ```bash
   tar xfz hdf5_1.14.5.tar.gz
   ```

4. ...and create a build directory:
   ```bash
   mkdir hdf5_build && cd hdf5_build
   ```

5. Run the following to configure the package (ready for build) and define the installation folder:
   ```bash
   ../hdf5-hdf5_1.14.5/configure --with-zlib=${ZLIB_INSTALL_DIR} --prefix=${H5_INSTALL_DIR} --enable-hl --enable-fortran
   ```

6. Ready to build and install HDF5, so go ahead and run:
   ```bash
   make check
   make install
   ```

7. Add HDF5 to the PATH:
   ```bash
   PATH=${H5_BIN}:${PATH}
   ```
   
#### CURL
The library can be downloaded [here](https://curl.se/download.html) and the latest version at the time of writing is 8.10.1.
1. Create some folders:
   ```bash
   mkdir -p ${CURL_ROOT} && cd ${CURL_ROOT}
   ```

2. Then, download the source code:
   ```bash
   wget https://curl.se/download/curl-8.10.1.tar.gz
   ```

3. Decompress the tarball:
   ```bash
   tar xfz curl-8.10.1.tar.gz
   ```

4. ...and create a build directory:
   ```bash
   mkdir curl_build && cd curl_build
   ```

5. Run the following to configure the package (ready for build) and define the installation folder:
   ```bash
   ../curl-8.10.1/configure --prefix=${CURL_INSTALL_DIR} --with-openssl
   ```

6. Ready to build and install CURL, so go ahead and run:
   ```bash
   make   
   make install
   ```

---------

Having all of the above in order, we can start the build process for netCDF.
Starting with netCDF-C, we have the following steps.

1. Let's start by creating some folders for tidiness:
   ```bash
   mkdir -p ${NC_ROOT} && cd ${NC_ROOT}
   ```

2. Proceed with downloading the source code archive:
   ```bash
   wget https://downloads.unidata.ucar.edu/netcdf-c/4.9.2/netcdf-c-4.9.2.tar.gz
   ```

3. Decompresss the tarball:
   ```bash
   tar xzf netcdf-c-4.9.2.tar.gz
   ```

4. Now, create and move into the build directory:
   ```bash
   mkdir netcdf-c-build && cd netcdf-c-build
   ```

5. Configure the build system. Disabling xml2 will force using the netCDF internal version of the library.
   ```bash
   CPPFLAGS="-I${H5_INSTALL_DIR}/include -I${ZLIB_INSTALL_DIR}/include -I${CURL_INSTALL_DIR}/include" LDFLAGS="-L${H5_INSTALL_DIR}/lib -L${ZLIB_INSTALL_DIR}/lib -L${CURL_INSTALL_DIR}/lib" ../netcdf-c-4.9.2/configure --prefix=${NC_INSTALL_DIR} --disable-libxml2
   ```

6. Ready to build and install netCDF-C, so go ahead and run:
   ```bash
   make check
   make install
   ```

On exit, it gives a very useful message about how to use netcdf with your projects:
```bash
...
| You can use script "nc-config" to find out the relevant     |
| compiler options to build your application. Enter           |
|                                                             |
|     nc-config --help                                        |
|                                                             |
| for additional information.
...
```

Another useful step is to export some environment variables for later or for the future:
```bash
export PATH=${NC_BIN}:${PATH}
```

#### netCDF-Fortran
Now we are ready to build netCDF-Fortran. 

1. Move to the right directory:
   ```bash
   cd ${NC_ROOT}
   ```
2. Proceed with downloading the source code archive:
   ```bash
   wget https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.1/netcdf-fortran-4.6.1.tar.gz
   ```

3. Decompresss the tarball:
   ```bash
   tar xzf netcdf-fortran-4.6.1.tar.gz
   ```

4. Now, create and move into the build directory:
   ```bash
   mkdir netcdf-f-build && cd netcdf-f-build
   ```

5. Configure the build system:
   ```bash
   CPPFLAGS="-I${NC_INSTALL_DIR}/include" LDFLAGS="-L${NC_INSTALL_DIR}/lib" ../netcdf-fortran-4.6.1/configure --prefix=${NC_INSTALL_DIR}
   ```

6. Ready to build and install netCDF-Fortran, so go ahead and run:
   ```bash
   make check
   make install
   ```

### LIBPNG
Moving on to libpng. 

1. Create a folder and enter:
   ```bash
   mkdir ${PNG_ROOT} && cd ${PNG_ROOT}
   ```

2. Download the source code [here](http://www.libpng.org/pub/png/libpng.html). Latest version at the time of writing: 1.6.44.
   ```bash
   wget https://download.sourceforge.net/libpng/libpng-1.6.44.tar.gz
   ```

3. Extract the files from the archive:
   ```bash
   tar xzf libpng-1.6.44.tar.gz
   ```

4. Enter the folder and create a build folder:
   ```bash
   mkdir libpng-build && cd libpng-build
   ```
5. Configure the build system and use the grib2 folder as the installation folder:
   ```bash
   ../libpng-1.6.44/configure --prefix=${PNG_INSTALL_DIR}
   ```

6. Ready to build and install, so go ahead and run:
   ```bash
   make
   make install
   ```

### JASPER
Finally, we need to build and install jasper. 
Saving some keystrokes since it follows the same logic as above, the commands needed are the following:
```bash
mkdir -p ${JASPER_ROOT}
git clone git@github.com:jasper-software/jasper.git
mkdir jasper-build && cd jasper-build
cmake ../jasper -DJAS_ENABLE_SHARED=true -DCMAKE_INSTALL_PREFIX=${JASPER_INSTALL_DIR} -DALLOW_IN_SOURCE_BUILD=on
cmake --build .
make clean all
make test
make install
export JASPERINC=${JASPER_INSTALL_DIR}/include
export JASPERLIB=${JASPER_INSTALL_DIR}/lib
```
---------

## WRF
Now we **_should_** be ready to build WRF!
I have not figured out the way to automate it yet, so here are the commands:
```bash
cd ${WRF_ROOT}
git clone git@github.com:wrf-model/WRF.git
cd WRF
export WRFIO_NCD_LARGE_FILE_SUPPORT=1
./configure
```
At this point, you will be asked to select some options. 
For the build, I selected (serial) for GCC AArch64, and no nesting.
Follow up with:
```bash
./compile em_real >& log.compile &
```

## WPS
Once WRF is done, we can proceed with WPS:
```bash
cd ${WRF_ROOT}

wget https://github.com/wrf-model/WPS/archive/refs/tags/v4.6.0.tar.gz
tar xzf v4.6.0.tar.gz
cd WPS-4.6.0
./configure
```

## Notes
For budgeting time, on the RPi 4 (4GB):
- Libraries take roughly 5 hours to build with the vast majority of the time going to MPICH, then HDF5 and netCDF-C.
- WRF takes roughly 2 hours & 15 minutes to build, plus 10 minutes to run post-build tasks.
- WPS takes roughly XXX to build - will update once it succeeds...

To redirect stdout and stderr to a log file when running a command and want to put it to the background:
```bash
command > log_file 2>&1 &
```

### Issues
On configuring WPS, I get the following:
```bash
Will use NETCDF in dir: /home/aristotelis/build_wrf/libraries/netcdf
Found what looks like a valid WRF I/O library in ../WRF
Found Jasper environment variables for GRIB2 support...
  $JASPERLIB = /home/aristotelis/build_wrf/libraries/grib2/lib
  $JASPERINC = /home/aristotelis/build_wrf/libraries/grib2/include
------------------------------------------------------------------------
Please select from among the following supported platforms.


Enter selection [1-0] : 1

Invalid response (1)
------------------------------------------------------------------------
Please select from among the following supported platforms.


Enter selection [1-0] : 
```

To fix this, follow the change proposed [here](https://github.com/wrf-model/WPS/pull/262)

Run `./configure` and select `1.  Linux x86_64 aarch64, gfortran    (serial)` or whatever matches the WRF option best.
If some errors still pop up or if the process does not produce the expected binaries, [this](https://forum.mmm.ucar.edu/threads/resolved-wps-pgi-usr-lib64-mpich-3-2-lib-file-not-recognized-is-a-directory.47/) is another avenue to explore.

