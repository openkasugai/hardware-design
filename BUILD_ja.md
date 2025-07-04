# サンプル実装のビルド手順

## はじめに

本手順書では、サンプル実装のBitstream生成に必要な手順について説明します。

## ディレクトリ構成

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

## ビルド環境

Vivado/Vitis HLS 2023.1

## ビルド手順

### 準備

- vitis and vivado 2023.1環境にパスを通します。
  ```
  $ source /tools/Xilinx/Vitis/2023.1/settings64.sh 
  ```

- ipディレクトリにおいてFPGA IPのビルドを実行します。
  ```
  $ cd ./ip
  $ make
  ```

> [!NOTE]  
> cmakeがインストールされていても、ビルド時にcmakeでエラーが発生する場合は、`which`コマンドを利用して、どのcmakeを使用しているかを確認してください。Vitis環境のcmakeを使用している場合はPATHを変更することでインストールしたcmakeコマンドが実行されるようにしてください。

### ビルド

- boardディレクトリにおいてボードデザインを指定してmakeを実行します。
  ```
  $ cd ./board
  $ make <nop_and_vec_fp_inc|nop_minimum|nop_mm|nop_toe>
  ```

### Bitstreamの書き込み

```
$ xsdb
% connect
% tar <target fpga index>
% fpga {nop_and_vec_fp_inc,nop_minimum,nop_mm,nop_toe}/project_1/project_1.runs/impl/design_1_wrapper.bit
```
