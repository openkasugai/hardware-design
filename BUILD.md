# Build procedure for sample implementation

## Introduction

This procedure document describes the steps required to generate Bitstream for the sample implementation.

## Directories

```
board : board designs
       -+- common             : board common file
        +- doc                : board design specifications
        +- nop_and_vec_fp_inc : board design including nop_st, nop_mm and vec_fp_inc
        +- nop_minimum        : minimum board design including only nop_st
        +- nop_mm             : board design including nop_st and nop_mm
        +- nop_toe            : board design including nop_st with OSS TOE 
        +- scripts            : script to generate board config
functions : HLS functions
       -+- nop_st             : HLS nop axis function
        +- nop_mm             : HLS nop axi function
        +- vec_fp_inc         : HLS vector fp32 increment function
        +- template           : common makefile
ip : Hardware IPs
       -+- axi_reader         : read from the device memory for functions having AXI I/F
        +- axi_writer         : write stream data to the device memory for functions having AXI I/F
        +- common             : common sub modules for other IPs
        +- doc                : IP specifications.
        +- external           : OSS TOE (fpga-network-stack)
        +- function_ctrl      : glue logics of HLS functions and route_controller
        +- route_controller   : connection control IP in FPGA
        +- stream_engine      : drive streaming DMA without host intervention
        +- toe_wrapper        : simplifies the user I/F of OSS TOE using the network_ip_ctrl module
```

## Build Environment

Vivado/Vitis HLS 2023.1

## Build Instructions

### Preparation

- set path for vitis and vivado 2023.1
  ```
  $ source /tools/Xilinx/Vitis/2023.1/settings64.sh 
  ```

- build IP files
  ```
  $ cd ./ip
  $ make
  ```

> [!NOTE]  
> If cmake is installed, but you still get errors with cmake when building, use the `which` command to check which cmake you are using. If you are using cmake in the Vitis environment, change the PATH so that the installed cmake command is executed.

### Build

- specify board design and make
  ```
  $ cd ./board
  $ make <nop_and_vec_fp_inc|nop_minimum|nop_mm|nop_toe>
  ```

### Configuration

```
$ xsdb
% connect
% tar <target fpga index>
% fpga {nop_and_vec_fp_inc,nop_minimum,nop_mm,nop_toe}/project_1/project_1.runs/impl/design_1_wrapper.bit
```
