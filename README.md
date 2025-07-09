# OpenKasugai Hardware Experimental Branch

> [!WARNING]  
> This branch was developed for experimental purposes **and is NOT currently maintained or supported.**  
> It must also be used with software in the `hardware-drivers` repository in the branch of the same name. (It cannot be used with the one in the main branch)

## Introduction

OpenKasugai Hardware Experimental Branch is an experimental effort to demonstrate an example implementation of OpenKasugai Hardware concept using standard IP cores provided by vendors and open source IP cores. （For more information about the OpenKasugai Project, see the README of the main branch.）

## Features

- Implementation of a minimum configuration on an FPGA equipped with a PTU circuit capable of network communication and an XDMA circuit capable of DMA communication

- General-purpose implementation using OSS for the PTU part and standard functionality (XDMA) for the DMA part

- Evaluation environment that enables close cooperation between multiple FPGAs
  - PCIe connection (XDMA) + AXIS Function (HLS) configuration implementation
  - PCIe connection (XDMA) + AXI Function (HLS) configuration implementation
  - Ethernet connection (OSS TOE) + AXIS Function (HLS) configuration implementation

## Documents

|Title|Description|
|:--|:--|
|README|This document|
|[Build Instructions](./BUILD.md)|This document provides instructions for building a sample implementation.|
|[Tutorial](./TUTORIAL.md)|This document describes the procedures for setting up and executing an environment for verifying a sample implementation.|
|[Board Design Overview](./board/doc/README.md)|This document describes the board design of the sample implementation.|

## System Requirements

### Hardware Configuration

|Item|Content|Remarks|
|:--|:--|:--:|
|Motherboard|PCI Express 3.0 x16 slot support (dual slot)|\*1|
|Power|225W (PCI Express slot + 8-pin AUX power)|\*1|
|Memory|Operation: 16GiB or more<br>Development: 64GiB or more (80GiB or more Recommended)|\*1|
|FPGA card|Alveo U250||

\*1) Based on Alveo U250 [Minimum System Requirements](https://docs.amd.com/r/en-US/ug1301-getting-started-guide-alveo-accelerator-cards/Minimum-System-Requirements) .

### Software Configuration

|Item|Version|
|:--|:--|
|OS|Ubuntu 22.04.4 LTS|
|Kernel|5.15.0-138-generic|
|Vivado/Vitis HLS|2023.1|
|build-essential|12.9|
|cmake|3.22.1|
|python3-pip|3.10.12|
|GoogleTest|1.16.0|

## Support Policy

- Bug reports and feature requests are generally not handled.

- Issues and Pull Requests are welcome, but may not be reviewed or merged.

- We do not provide general technical support ( e.g., usage questions, troubleshooting ).

## License

### Hardware-design Repository

|Item|Path|License|
|:--|:--|:--|
|Board designs|`/board/`|Apache License 2.0|
|HLS functions|`/functions/`|Apache License 2.0|
|Hardware IPs|`/ip/`|Apache License 2.0|

### Hardware-drivers Repository

|Item|Path|License|
|:--|:--|:--|
|Test Code|`/test/`|BSD 3-Clause License|
|Tools|`/src/tools/`|BSD 3-Clause License|
|Library|`/src/lib/`|BSD 3-Clause License|
|Driver|`/src/drivers/`|GNU General Public License v2.0|