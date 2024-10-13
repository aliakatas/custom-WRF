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
4. Time to build MPICH. There is an excellent [guide](https://www.southampton.ac.uk/~sjc/raspberrypi/pi_supercomputer_southampton.htm) from Prof Simon Cox.
In summary, we need to perform the following steps:
   a. Firstly, create some folders:
   ```bash
   mkdir -p ~/software/mpich3
   cd ~/software/mpich3
   ```
   b. Then, download the source code from [here](https://www.mpich.org/downloads/):
   ```bash
   wget https://www.mpich.org/static/downloads/4.2.3/mpich-4.2.3.tar.gz
   ```
   c. Decompress the tarball:
   ```bash
   tar xfz mpich-4.2.3.tar.gz
   ```
   d. ...and create a build directory:
   ```
   mkdir mpich_build
   cd mpich_build
   ```
   e. Run the following to configure the package (ready for build) and define the installation folder:
   ```bash
   ../mpich-4.2.3/configure --prefix=/home/<user>/build_WRF/libraries/mpich3-install
   ```
   f. Ready to build MPICH, so go ahead and run:
   ```bash
   make
   ```
   Be prepared to wait for a few hours...
   g. Finally, install the package:
   ```bash
   make install
   ```
6. At this point MPCIH should be installed, so let's add it to our $PATH:
```bash
export PATH=$PATH:/home/<user>/build_WRF/libraries/mpich3-install/bin
```
7. To make this available to future sessions, let's add this to the user's configuration file:
```bash
echo >> ~/.bashrc
echo "#Add MPI to PATH" >> ~/.bashrc
echo PATH="$PATH:/home/<user>/build_WRF/libraries/mpich3-install/bin" >> ~/.bashrc
```

