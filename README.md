# Custom WRF deployment
In this repo, the steps to deploy the Weather Research and Forecasting model (WRF) are documented.
The main goal is to set up the system on a Raspberry Pi 4. The [blog post](https://chrisdearden.net/WRFRPi/) from Chris Dearden is used for guidance.

## Hardware specs
Host: Raspberry Pi 4 Model B Rev 1.4 
CPU: (4) @ 1.800 GHz 
Memory: 3791 MiB 
OS: Debian GNU/Linux 12 (bookworm) aarch64

## Requirements
Before building WRF, the following dependencies/libraries will need to be built and installed. 
The libraries are the following:
1. [MPICH](https://www.mpich.org/) a portable implementation of MPI.
2. [netCDF](https://www.unidata.ucar.edu/software/netcdf/) library to support reading and writing files with array-oriented scientific data.
3. [m4](https://www.gnu.org/software/m4/m4.html) a general-purpose macro processor that can be used to preprocess C and assembly language programs.
4. [zlib](https://zlib.net/) a (de-)compression library.
5. libpng
6. jasper
7. WPS

As a first attempt, we will try building the system using GNU Fortran and C compilers.

