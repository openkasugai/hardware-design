# What is OpenKasugai Hardware

OpenKasugai Project aims to create a computing infrastructure that can process data by combining various hardware accelerators (HWA) such as FPGAs, GPUs, and xPUs. This system provides customized services for each user by combining arithmetic operations (functions). You can also improve application performance by using the most appropriate HWA for each function.

To achieve this, OpenKasugai Hardware employs hardware function chaining. This technology enables HWAs to autonomously manage output destinations and transfer processing results to any specified function. By eliminating CPU intervention in communication control and data transfer, this approach achieves low-latency and high-throughput data transfers.

The sample implementation includes a chain control circuit and a proprietary DMA circuit (LLDMA: Low-Latency Direct device Memory Access), enabling direct data transfer between FPGAs over the PCIe bus.

![](docsrc/source/_images/cover.png)

# Key Features

The sample implementation performs hardware function chaining for image processing, consisting of filtering and resizing.

|Features|Description|
|:--|:--|
|Chain Control|Identifies function chains and manages the destinations for processing results.|
|LLDMA|Enables communication via PCIe, enabling direct data transfers between the host and FPGA, as well as between FPGA cards.|
|Network Terminator|Enables communication via Ethernet. This module is not included in the sample implementation. If needed, we recommend using "PTU_25G_IC".|
|Function|Consists of a conversion adapter block and a filter-resize block. The conversion adapter block holds data frames and selects a processing unit. The filter-resize block contains multiple processing units and executes tasks in parallel, including a 5x5 median filter and resizing.|
|Direct Transfer Adapter|Enables data to be returned directly to the chain control circuitry as needed to bypass functions.|

# Block diagram

The following is a block diagram of the sample implementation.

![](docsrc/source/_images/block_diagram.png)

## About the network termination function

This sample implementation does not include the network termination function. If you want to use it, we recommend the following IP.

- Vendor : [Intellectual Highway, Corp.](https://www.i-highway.com/)
- IP name : PTU correspondence 25GbE for interconnect
- Type : `PTU_25G_IC`
- Version : `2.0.0-1`

# Documents

|Title|Description|
|:--|:--|
|README|These documents|
|[Tutorial](./TUTORIAL.md)|This document describes the procedures for setting up and executing an environment for verifying a sample implementation.|
|[build instructions](./BUILD.md)|This document provides instructions for building a sample implementation.|
|[Development Guidelines for Functions](https://openkasugai.github.io/hardware-design/)|This document provides design specifications and build instructions for customizing the sample implementation or for developing new functions.|

# Installation Procedure

Refer to ["Installation Procedure" in the tutorial](./TUTORIAL.md).

# System Requirements

Describes the environment used to validate the sample implementation. Refer to ["Validation environment configuration" in the tutorial](./TUTORIAL.md#1-Validation environment configuration) for the system configuration during verification.

## Hardware Configuration

|Item|Content|Remarks|
|:--|:--|:--:|
|Motherboard|PCI Express 3.0 x16 slot support (dual slot)|\*1|
|Power|225W (PCI Express slot + 8-pin AUX power)|\*1|
|Memory|Operation: 16GiB or more<br>Development: 64GiB or more (80GiB or more Recommended)|\*1|
|FPGA card|Alveo U250||

\*1) Based on Alveo U250 [Minimum System Requirements](https://docs.amd.com/r/en-US/ug1301-getting-started-guide-alveo-accelerator-cards/Minimum-System-Requirements) .

## Software configuration

|Item|Version|
|:--|:--|
|OS|Ubuntu 22.04.4 LTS|
|Kernel|5.15.0-117-generic|
|Vivado/Vitis HLS|2023.1|
|build-essential|12.9|
|cmake|3.22.1|
|python3-pip|3.10.12|
|pkg-config|0.29.2|
|meson|0.61.2.1|
|ninja|1.11.1.1|
|pyelftools|0.31|
|libnuma-dev|2.0.14.3|
|udev|249.11|
|libpciaccess-dev|0.16.3|
|DPDK|23.11.1|
|OpenCV|3.4.3|

# literature

Y. Ukon, T. Kawahara, Y. Arikawa, N. Miura, T. Ishizaki, W. kanemori, R. Tamura, K. Mori, and T. Sakamoto, ``Scalable Low-latency Hardware Function Chaining with Chain Control Circuit," The International Conference for High Performance Computing, Networking, Storage, and Analysis (SC24), Nov. 2024.
https://sc24.supercomputing.org/proceedings/poster/poster_pages/post122.html

# Contributing to OpenKasugai Hardware

Refer to ["Contributing to OpenKasugai Hardware](./CONTRIBUTING.md).

# License

## Hardware-design Repository

|Item|Path|License|
|:--|:--|:--|
|Chain Control|`/chain-control/chain_control/`|Apache License 2.0|
|Direct Transfer Adapter|`/chain-control/direct_trans_adaptor/`|Apache License 2.0|
|LLDMA|`/external-if/LLDMA/`|Apache License 2.0|
|Filter Resize|`/function/filter_resize/filter_resize/`|Apache License 2.0|
|Conversion Adapter|`/function/filter_resize/conversion_adaptor/`|Apache License 2.0|
|Global Register|`/example-design/fpga_reg/`|Apache License 2.0|
|PCIe Interface|`/example-design/pci_conversion/`|Apache License 2.0|
|Script for build|`/example-design/script/`|Apache License 2.0|

## Hardware-drivers Repository

|Item|Path|License|
|:--|:--|:--|
|Sample program|`/tools/sample_tester/`|BSD 3-Clause License|
|Library|`/lib/`|BSD 3-Clause License|
|Driver|`/driver/`|GNU General Public License v2.0|
