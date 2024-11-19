# Custom WRF deployment
In this repo, the steps to deploy the Weather Research and Forecasting model (WRF) are documented.
The main goal is to set up the system on a Raspberry Pi 4. The [blog post](https://chrisdearden.net/WRFRPi/) from Chris Dearden is used for guidance.

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

__Note__: To redirect stdout and stderr to a log file when running a command and want to put it to the background:
```bash
command > log_file 2>&1 &
```

## Build Steps
1. Let's start by updating our system:
   ```bash
   sudo apt update && sudo apt dist-upgrade -y
   ```

2. Proceed with installing the base system for building:
   ```bash
   sudo apt install build-essential csh m4 cmake gcc gfortran libjpeg-dev
   ```

3. To keep things tidy, let's create a folder to store/install the required libraries:
   ```bash
   mkdir -p ~/build_wrf/libraries
   ```
   and one to build them in:
   ```bash
   mkdir -p ~/wrf_deps_builds
   ```

### MPICH
Time to build MPICH. There is an excellent [guide](https://www.southampton.ac.uk/~sjc/raspberrypi/pi_supercomputer_southampton.htm) from Prof Simon Cox, but it has a wider scope.
In summary, we need to perform the following steps using the latest version at this time (mpich 4.2.3):
1. Firstly, create some folders:
   ```bash
   mkdir -p ~/wrf_deps_builds/mpich3 && cd ~/wrf_deps_builds/mpich3
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
   ../mpich-4.2.3/configure --prefix=~/build_wrf/libraries/mpich3
   ```

6. Ready to build MPICH, so go ahead and run:
   ```bash
   make
   ```
   Be prepared to wait for a few hours...

7. Finally, install the package:
   ```bash
   make install
   ```

8. At this point MPCIH should be installed, so let's add it to our $PATH:
   ```bash
   export PATH=~/build_wrf/libraries/mpich3/bin:$PATH
   ```

9. To make this available to future sessions, let's add this to the user's configuration file:
   ```bash
   echo >> ~/.bashrc
   echo "#Add MPI to PATH" >> ~/.bashrc
   echo PATH="$PATH:~/build_wrf/libraries/mpich3/bin" >> ~/.bashrc
   ```

10. To make sure that the library has been installed correctly, run the following:
   ```bash
   which mpicc
   which mpiexec
   ```

11. Create a directory and move into it to run some tests for MPICH:
   ```bash
   mkdir -p ~/wrf_deps_builds/mpich3/mpi_testing && cd ~/wrf_deps_builds/mpich3/mpi_testing
   ```

12. Now run the single-node test with the following:
   ```bash
   mpiexec -hosts 127.0.0.1 -n 1 hostname
   ```
   This should return "raspberrypi" or the hostname of your device.

13. Now run another test using one of the examples provided in C (calculate pi):
   ```bash
   mpiexec -hosts 127.0.0.1 -n 2 ~/wrf_deps_builds/mpich3/mpich_build/examples/cpi
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

Since we want support for netCDF-4 and parallel I/O operations, we need to download and build HDF5, zlib and curl. So, before proceeding with netCDF, let's do that.

#### ZLIB
The library can be downloaded [here](https://www.zlib.net/) and the latest version at the time of writing is 1.3.1.
1. Create some folders:
   ```bash
   mkdir -p ~/wrf_deps_builds/zlib && cd ~/wrf_deps_builds/zlib
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
   ../zlib-1.3.1/configure --prefix=~/build_wrf/libraries/zlib
   ```

6. Ready to build and install ZLIB, so go ahead and run:
   ```bash
   make install
   ```
   If the installation directory for ZLIB is needed in other sessions, include it in the user's configuration file:
   ```bash
   echo >> ~/.bashrc
   echo "#Add ZLIB to PATH" >> ~/.bashrc
   echo PATH="~/build_wrf/libraries/zlib/bin:$PATH" >> ~/.bashrc
   ```

#### HDF5
The library can be downloaded [here](https://www.hdfgroup.org/download-hdf5/source-code/) and the latest version at the time of writing is 1.14.5. Mind that it might require a user account (free to register). 
Alternatively, head to [HDF5-Github](https://github.com/HDFGroup/hdf5) and clone away!
1. Create some folders:
   ```bash
   mkdir -p ~/wrf_deps_builds/hdf5 && cd ~/wrf_deps_builds/hdf5
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
   ```
   mkdir hdf5_build && cd hdf5_build
   ```

5. Run the following to configure the package (ready for build) and define the installation folder:
   ```bash
   ../hdf5-hdf5_1.14.5/configure --with-zlib=~/build_wrf/libraries/zlib --prefix=~/build_wrf/libraries/hdf5 --enable-hl
   ```

6. Ready to build and install HDF5, so go ahead and run:
   ```bash
   make check
   make install
   ```
7. Add HDF5 to the PATH:
   ```bash
   PATH=~/build_wrf/libraries/hdf5/bin:${PATH}
   ```
   or more permanently:
   ```bash
   echo >> ~/.bashrc
   echo "#Add HDF5 to PATH" >> ~/.bashrc
   echo PATH="~/build_wrf/libraries/hdf5/bin:$PATH" >> ~/.bashrc
   ```

#### CURL
The library can be downloaded [here](https://curl.se/download.html) and the latest version at the time of writing is 8.10.1.
1. Create some folders:
```bash
mkdir -p ~/software/curl
cd ~/software/curl
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
```
mkdir curl_build
cd curl_build
```
5. Run the following to configure the package (ready for build) and define the installation folder:
```bash
CURLDIR=/home/<user>/build_WRF/libraries/curl-install
../curl-8.10.1/configure --prefix=${CURLDIR} --with-openssl
```
6. There might be some errors related to not finding the openssl library. If not, skip to the next step.
To rectify this, install the dev packages:
```bash
sudo apt install libssl-dev libpsl-dev
```
and re-run step 5.

7. Ready to build and install CURL, so go ahead and run:
```bash
make   
make install
```

---------

Having all of the above in order, we can start the build process for netCDF.

1. Let's start by creating some folders for tidiness:
```bash
mkdir -p ~/software/netcdf
cd ~/software/netcdf
```
2. Proceed with downloading the source code archive:
```bash
wget https://downloads.unidata.ucar.edu/netcdf-c/4.9.2/netcdf-c-4.9.2.tar.gz
wget https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.1/netcdf-fortran-4.6.1.tar.gz
```
3. Decompresss the tarballs:
```bash
tar xzf netcdf-c-4.9.2.tar.gz
tar xzf netcdf-fortran-4.6.1.tar.gz
```
4. ... and move to the netcdf-c directory first:
```bash
cd netcdf-c-4.9.2
```
5. Create the build directories needed:
```bash
mkdir netcdf-c-build
mkdir netcdf-f-build
```
6. Enter the "c-build" directory:
```bash
cd netcdf-c-build
```
7. Configure the build system. Disabling xml2 will force using the netCDF internal version of the library.
```bash
NCDIR=/home/<user>/build_WRF/libraries/netcdf-install
CPPFLAGS="-I${H5DIR}/include -I${ZDIR}/include -I${CURLDIR}/include" LDFLAGS="-L${H5DIR}/lib -L${ZDIR}/lib -L${CURLDIR}/lib" ../configure --prefix=${NCDIR} --disable-libxml2
```
8. Ready to build and install netCDF-C, so go ahead and run:
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

Another usefule step is to export some environment variables for later or for the future:
```bash
export PATH=/home/<user>/build_WRF/libraries/netcdf-install/bin:$PATH
export NETCDF=/home/<user>/build_WRF/libraries/netcdf-install

echo >> ~/.bashrc
echo "#Add NETCDF to PATH" >> ~/.bashrc
echo PATH="${NETCDF}:$PATH" >> ~/.bashrc
```
------------
#### netCDF-Fortran
Now we are ready to build netCDF-Fortran. 
1. Move to the relevant directory:
```bash
cd ../netcdf-f-build
```
2. Configure the build system:
```bash
CPPFLAGS="-I${NCDIR}/include" LDFLAGS="-L${NCDIR}/lib" ../configure --prefix=${NCDIR}
```
3. Ready to build and install netCDF-Fortran, so go ahead and run:
```bash
make check
make install
```

### LIBPNG
Moving on to libpng. 

1. Create a folder and enter:
```bash
mkdir ~/libpng && cd ~/libpng
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
cd libpng-1.6.44
mkdir libpng_build && libpng_build
```
5. Configure the build system and use the grib2 folder as the installation folder:
```bash
../configure --prefix=/home/<user>/build_WRF/libraries/grib2-install
```
6. Ready to build and install, so go ahead and run:
```bash
make
make install
```

### JASPER
Finally, we need to build and install jasper.
```bash
cd ~/software
git clone git@github.com:jasper-software/jasper.git
cd jasper
mkdir jasper_build && cd jasper_build
cmake .. -DJAS_ENABLE_SHARED=true -DCMAKE_INSTALL_PREFIX=/home/<user>/build_WRF/libraries/grib2-install -DALLOW_IN_SOURCE_BUILD=on
cmake --build .
make clean all
make test
make install
export JASPERINC=/home/<user>/build_WRF/libraries/grib2-install/include
export JASPERLIB=/home/<user>/build_WRF/libraries/grib2-install/lib
```
---------

Now we **_should_** be ready to build WRF!

```bash
cd ~/build_WRF
git clone git@github.com:wrf-model/WRF.git
cd WRF
export WRFIO_NCD_LARGE_FILE_SUPPORT=1
./configure
# messages about not finding HDF5 nor JASPER
# selected option 3. dmpar + gfortran
# selected basic nesting (1.)
# Other messages:
# ------------------------------------------------------------------------
# Settings listed above are written to configure.wrf.
# If you wish to change settings, please edit that file.
# If you wish to change the default options, edit the file:
#      arch/configure.defaults
# NetCDF users note:
#  This installation of NetCDF supports large file support.  To DISABLE large file
#  support in NetCDF, set the environment variable WRFIO_NCD_NO_LARGE_FILE_SUPPORT
#  to 1 and run configure again. Set to any other value to avoid this message.
#   
# 
# Testing for NetCDF, C and Fortran compiler
# 
# This installation of NetCDF is 64-bit
#                  C compiler is 64-bit
#            Fortran compiler is 64-bit
#               It will build in 64-bit
#  
# NetCDF version: 4.9.2
# Enabled NetCDF-4/HDF-5: yes
# NetCDF built with PnetCDF: no
#  
# 
# ************************** W A R N I N G ************************************
#  
# The moving nest option is not available due to missing rpc/types.h file.
# Copy landread.c.dist to landread.c in share directory to bypass compile error.
#  
# *****************************************************************************
```

Could it all this be in vain?
It looks like the instructions here: https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compilation_tutorial.php are similar but somehow clearer?
Will attempt later!


