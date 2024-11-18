# はじめに

本手順書では、[実機サンプル](./README_ja.md#ブロック図)のTandemコンフィギュレーションのビルド手順について説明し、FPGA カードの不揮発領域(Flash ROM)に保存するコンフィギュレーションデータファイル（\*.mcs)とFPGA の揮発性領域(SRAM)に保存するコンフィギュレーションデータファイル（\*.bit）を作成します。
各データの書き込み手順については、[チュートリアルの『テスト手順』](./TUTORIAL_ja.md#5-テスト手順)を参照ください。

- MCSファイル： FPGA とホスト間の PCI Express リンクを確立するための最小限の回路を提供する
- Bitstreamファイル：ファンクションチェイニング機能と演算機能を実装する回路を提供する

# ディレクトリ構成

以下のディレクトリ構成に対してコンパイルを実行します。

```
hardware-design/
├─chain-control/
│  ├─chain_control/
│  │  └─script/
│  │      └─hls/
│  │          └─Makefile
│  └─direct_trans_adaptor/
│      └─script/
│          └─hls/
│              └─Makefile
├─external-if/
│  └─LLDMA/
├─function/
│  └─filter_resize/
│      ├─filter_resize/
│      │  └─script/
│      │      └─hls/
│      │          └─Makefile
│      └─conversion_adaptor/
│          └─script/
│              └─hls/
│                  └─Makefile
└─example-design/
    ├─fpga_reg/
    ├─pci_conversion/
    ├─script/
    │  ├─impl/
    │  ├─create_project.tcl
    │  └─Makefile
    └─bitstream/
```

# ビルド環境

MCS・Bitstreamファイルのビルドには Vivado/Vitis HLS 2023.1 を使用します。

例えば、以下の構成でコンパイルを行う場合、約8時間かかります。
- CPU : Intel(R) Xeon(R) Gold 6330 CPU @ 2.00GHz
- CPU コア数 : 20
- メモリ : 130GB

# ビルド手順

以降、作業ディレクトリを `$workdir` とします。

Vivado/Vitis の初期設定スクリプトを実行した後、リポジトリ配下の `example-design/script/` に移動してmakeコマンドを実行します。

```sh
$ source /tools/Xilinx/Vivado/2023.1/settings64.sh
$ cd $workdir
$ git clone https://github.com/openkasugai/hardware-design.git
$ cd $workdir/hardware-design/example-design/script/
$ make run-impl
```

makeコマンドの実行後、`$workdir/example-design/script/` 配下に”project_1”ディレクトリが生成され、`project_1/project_1.runs/impl_1` にMCSファイルとBitstreamファイルが保存されます。

|ファイル|説明|
|:--|:--|
|`design_1_wrapper_tandem1.mcs`|Tandem Configuration stage1 MCS file|
|`design_1_wrapper_tandem2.bit`|Tandem Configuration stage2 Bitstream file|

# 再ビルド手順

再ビルドする際は、make distcleanコマンドにて生成されたプロジェクトディレクトリと中間ファイルを削除した後に、再度ビルドを実行します。

```sh
$ cd $workdir/hardware-design/example-design/script/
$ make distclean
$ make run-impl
```

----
