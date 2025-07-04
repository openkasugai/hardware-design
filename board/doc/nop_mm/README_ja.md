# Overview

- nop_st, nop_mm の HLS function を備えた AXI function の動作確認用の board design である
- DDR は SLR0, SLR1 の 2ch を使用

## board design 全体構成

![nop_mm_overview.svg](images/nop_mm_overview.svg)

# Implementation

## clock regions

- DDR I/F が 300MHz であり、そのほかは、xdma の user clk である 250MHz としている
- DDR I/F への AXI interconnect は動作確認用 design のため、以下の実装としている
  - xdma の user clk をベースクロックとし、X-bar 部分を 250MHz 駆動としている
  - 深さ 32 の FIFO を使用している

## tdest routing

- route_controller によって制御する tdest は以下の設定としている
  - function inputs
    - 0 : nop_st
    - 8 : nop_mm
  - route_controller
    - 0 : pcie side
- tdest の使い分けとして、各 master interface に対して、連続した tdest の割り当てが必要であり、本 board では 8以上を axi_writer への tdest とした

## Synthesis Result

![nop_mm_synthesis_result.png](images/nop_mm_synthesis_result.png)<br/>
<img src="images/nop_mm_color_ja.png" width=300>
