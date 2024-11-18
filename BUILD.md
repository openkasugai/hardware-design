# Introduction

This procedure document explains how to build a Tandem configuration of the [sample implementation](./README.md#block-diagram), and create configuration data files (*.mcs, *.bit) to be saved in the non-volatile area (Flash ROM) and the volatile area (SRAM) of the FPGA.
Instructions for writing each type of configuration data files are provided in the ["Test Procedures" section of the tutorial](./TUTORIAL.md#5-test-procedure).

- MCS file: Provides minimal circuitry to establish a PCI Express link between an FPGA and a HOST
- Bitstream file: Provides circuits for hardware function chaining and data processing.

# Directory Configuration

Compile using the following directory structure.

```
hardware-design/
+--chain-control/
|  +--chain_control/
|  |  +--script/
|  |      +--hls/
|  |          +--Makefile
|  +--direct_trans_adaptor/
|      +--script/
|          +--hls/
|              +--Makefile
+--external-if/
|  +--LLDMA/
+--function/
|  +--filter_resize/
|      +--filter_resize/
|      |  +--script/
|      |      +--hls/
|      |          +--Makefile
|      +--conversion_adaptor/
|          +--script/
|              +--hls/
|                  +--Makefile
+--example-design/
    +--fpga_reg/
    +--pci_conversion/
    +--script/
    |  +--impl/
    |  +--create_project.tcl
    |  +--Makefile
    +--bitstream/
```

# Build Environment

You can generate the MCS and Bitstream files using Vivado/Vitis HLS 2023.1. For instance, the following configuration takes approximately 8 hours to compile.

- CPU : Intel(R) Xeon(R) Gold 6330 CPU @ 2.00GHz
- Set number of CPU cores : 20
- Memory : 130GB

# Build Instructions

From now on, let's call the working directory `$workdir`.

After running the Vivado/Vitis initialization script, navigate to `example-design/script/`under the repository and run the make command.

```sh
$ source /tools/Xilinx/Vivado/2023.1/settings64.sh
$ cd $workdir
$ git clone https://github.com/openkasugai/hardware-design.git
$ cd $workdir/hardware-design/example-design/script/
$ make run-impl
```

After running the make command, a "project_1" directory is created under `$workdir/example-design/script/` and MCS and Bitstream files are stored in `project_1/project_1.runs/impl_1`.

|File|Description|
|:--|:--|
|`design_1_wrapper_tandem1.mcs`|Tandem Configuration stage1 MCS file|
|`design_1_wrapper_tandem2.bit`|Tandem Configuration stage2 Bitstream file|

# Rebuild Instructions

When rebuilding, execute the make distclean command to delete the generated project directory and intermediate files, and then execute the build again.

```sh
$ cd $workdir/hardware-design/example-design/script/
$ make distclean
$ make run-impl
```

----
