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

## Build Steps
1. Let's start by updating our system:
```bash
sudo apt update && sudo apt dist-upgrade -y
```
2. Proceed with installing the base system for building:
```bash
sudo apt install build-essentials csh m4 cmake gcc gfortran libjpeg-dev
```
3. To keep things tidy, let's create a folder to build the required libraries:
```bash
mkdir -p ~/build_WRF/libraries
```

### MPICH
Time to build MPICH. There is an excellent [guide](https://www.southampton.ac.uk/~sjc/raspberrypi/pi_supercomputer_southampton.htm) from Prof Simon Cox, but it has a wider scope.
In summary, we need to perform the following steps using the latest version at this time (mpich 4.2.3):
1. Firstly, create some folders:
```bash
mkdir -p ~/software/mpich3
cd ~/software/mpich3
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
mkdir mpich_build
cd mpich_build
```
5. Run the following to configure the package (ready for build) and define the installation folder:
```bash
../mpich-4.2.3/configure --prefix=/home/<user>/build_WRF/libraries/mpich3-install
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
export PATH=$PATH:/home/<user>/build_WRF/libraries/mpich3-install/bin
```
9. To make this available to future sessions, let's add this to the user's configuration file:
```bash
echo >> ~/.bashrc
echo "#Add MPI to PATH" >> ~/.bashrc
echo PATH="$PATH:/home/<user>/build_WRF/libraries/mpich3-install/bin" >> ~/.bashrc
```
10. To make sure that the library has been installed correctly, run the following:
```bash
which mpicc
which mpiexec
```
11. Create a directory and move into it to run some tests for MPICH:
```bash
mkdir -p ~/software/mpich3/mpi_testing
cd ~/software/mpich3/mpi_testing
```
12. Now run the single-node test with the following:
```bash
mpiexec -hosts 127.0.0.1 -n 1 hostname
```
This should return "raspberrypi" or the hostname of your device.
13. Now run another test using one of the examples provided in C (calculate pi):
```bash
mpiexec -hosts 127.0.0.1 -n 2 ~/software/mpich3/mpich_build/examples/cpi
```
The return message should look like this:
```
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
mkdir -p ~/software/zlib
cd ~/software/zlib
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
mkdir zlib_build
cd zlib_build
```
5. Run the following to configure the package (ready for build) and define the installation folder:
```bash
ZDIR=/home/<user>/build_WRF/libraries/zlib-install
../zlib-1.3.1/configure --prefix=${ZDIR}
```
6. Ready to build and install ZLIB, so go ahead and run:
```bash
make install
```

If the installation directory for ZLIB is needed in other sessions, include it in the user's configuration file:
```bash
echo >> ~/.bashrc
echo "#Add ZLIB to PATH" >> ~/.bashrc
echo PATH="$PATH:${ZDIR}" >> ~/.bashrc
```

#### HDF5
TBA

#### CURL
TBA

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


