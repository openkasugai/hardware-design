# サンプル実装のテスト手順

## 準備

### ツールのインストール

- ビルドに必要なパッケージのインストールを行います。
  ```sh
  $ sudo apt install build-essential cmake python3-pip
  ```

- Vivado ML エディション 2023.1 を [AMD のダウンロードサイト](https://japan.xilinx.com/support/download/index.html/content/xilinx/ja/downloadNav/vivado-design-tools/2023-1.html) からダウンロードし、インストールします。Vitis もこのインストーラに含まれます。

  インストール手順は [UG973 : Vivado Design Suite User Guide: Release Notes, Installation, and Licensing](https://docs.amd.com/r/2023.1-English/ug973-vivado-release-notes-install-license/Release-Notes) を参照してください。

### リポジトリの clone

以降、本チュートリアルの作業ディレクトリを `$workdir` とします。

```sh
$ cd $workdir
$ git clone -b experimental https://github.com/openkasugai/hardware-design.git
$ git clone -b experimental https://github.com/openkasugai/hardware-drivers.git
```

### Hugepage の設定

FPGA-ホスト間のDMA転送に必要な連続したメモリ領域を十分な大きさで確保するために、Hugepageを設定します。

`/etc/default/grub` を編集し、`GRUB_CMDLINE_LINUX_DEFAULT` に hugepagesz=1G で 32ページ分が起動時に確保されるように設定します。

```diff
- GRUB_CMDLINE_LINUX_DEFAULT=""
+ GRUB_CMDLINE_LINUX_DEFAULT="default_hugepagesz=1G hugepagesz=1G hugepages=32"
```

Grub設定を反映し、システムを再起動します。

```sh
$ sudo update-grub
$ sudo reboot
```

再起動後、設定が反映されていることを確認します。

```sh
$ cat /proc/meminfo
# (中略)
HugePages_Total:      32
HugePages_Free:       32
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:    1048576 kB
```

## ビットストリームの生成と書き込み

[ビルド手順書](./BUILD_ja.md) を参照してください。

## ソフトウェアのビルドとインストール

`hardware-drivers`のREADMEを参照して以下を実行します。
- ドライバおよびライブラリのビルド
- ドライバのインストール
- テストコードのビルド

## テストコードの実行

### PCIe転送テスト

- $workdir/hardware-drivers/で以下を実行します。
  ```sh
  $ cd test/iddma
  $ make test
  ```
 
- ボードの接続状況やボードデザインの選択状況に応じて以下のテストが行われます。
  - Host -> HLS nop function (AXIS) -> Host のH2D+D2H転送テスト
  - Host -> HLS nop function (AXIS) -> HLS nop function (AXIS) -> Host のD2D転送テスト (FPGA2枚装着時)
  - Host -> HLS nop function (AXI) -> Host のH2D+D2H転送テスト
  - Host -> HLS vector fp increment function -> Host のH2D+D2H転送テスト (FPGAにnop_and_vec_fp_incのボードデザイン設定時)

### TCP転送テスト（FPGAにnop_toeのボードデザイン設定時）  

- FPGAとホスト間を図のように接続します。<br/>
<img src="images/tutorial_tcp_test.png" width=300><br/>

- 各IPアドレスやポートの情報を環境変数に設定します。
  ```sh
  $ export FPGA_ETH_IP=192.168.130.197    # fpga IP address
  $ export FPGA_ETH_MASK=255.255.255.0    # fpga subnet mask
  $ export FPGA_ETH_GATEWAY=192.168.130.1 # fpga default gateway
  $ export CPU_IP=192.168.130.97     # CPU test side IP address
  $ export CPU_PORT_BASE=30000       # CPU test side listen port
  $ export XSE_RX_PORT_BASE=20000    # fpga test side fpga listen port
  $ export XSE_IP=${FPGA_ETH_IP}     # fpga test side fpga IP address
  $ export XSE_TX_PORT_BASE=30000    # fpga test side fpga connect port
  ```

- $workdir/hardware-drivers/で以下を実行しTOEの設定を行います。
  ```sh
  $ make setup-toe
  ```

- 以下を実行することにより、Host NIC -> FPGA NIC -> HLS nop function (AXIS) -> FPGA NIC -> Host NIC のH2D+D2H転送テストが行われます。
  ```sh
  $ cd test/iddma
  $ make test_tcp
  ```
