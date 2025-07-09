# OpenKasugai Hardware Experimental Branch

> [!WARNING]  
> 本ブランチは実験的な目的で開発されたものであり、**現在のところメンテナンスやサポートは行っておりません。**  
> また、`hardware-drivers`リポジトリの同名ブランチにあるソフトウェアと組み合わせて使用する必要があります。（mainブランチのものと使用することはできません）

## はじめに

OpenKasugai Hardware Experimental Branchは、ベンダから標準提供されるIPコアやオープンソースのIPコアを使用して、OpenKasugai Hardwareコンセプトの実装例を示した実験的な取り組みです。
（OpenKasugai ProjectについてはメインブランチのREADMEを参照）

## 特徴

- ネットワーク通信が可能なPTU回路とDMA通信が可能なXDMA回路を搭載した最小構成の実装

- PTU部にOSSを利用、DMA部は標準機能（XDMA）とした汎用的な実装

- 複数FPGAを密に連携可能とする評価環境
  - PCIe 接続 (XDMA) + AXIS ファンクション (HLS) 構成の実装
  - PCIe 接続 (XDMA) + AXI ファンクション (HLS) 構成の実装
  - Ethernet 接続 (OSS TOE) + AXIS ファンクション (HLS) 構成の実装

## ドキュメント

|タイトル|説明|
|:--|:--|
|README|本書|
|[ビルド手順書](./BUILD_ja.md)|サンプル実装のビルド手順を説明します。|
|[チュートリアル](./TUTORIAL_ja.md)|サンプル実装の動作確認に必要な環境構築と実行手順を説明します。|
|[ボードデザイン概要](./board/doc/README_ja.md)|サンプル実装のボードデザインについて説明します。|

## システム要件

### 推奨ハードウェア構成

|項目|内容|備考|
|:--|:--|:--:|
|マザーボード|PCI Express 3.0 x16スロット対応のもの (デュアルスロット)|\*1|
|電源|225W (PCI Express スロット + 8ピンAUX電源)|\*1|
|メモリ|運用: 16GiB以上<br>開発: 64GiB以上 (80GiB以上推奨)|\*1|
|FPGAカード|Alveo U250||

\*1) Alveo U250 の [Minimum System Requirements](https://docs.amd.com/r/en-US/ug1301-getting-started-guide-alveo-accelerator-cards/Minimum-System-Requirements) 
に準じます。

### 推奨ソフトウェア構成

|項目|バージョン|
|:--|:--|
|OS|Ubuntu 22.04.4 LTS|
|Kernel|5.15.0-138-generic|
|Vivado/Vitis HLS|2023.1|
|build-essential|12.9|
|cmake|3.22.1|
|python3-pip|3.10.12|
|GoogleTest|1.16.0|

## サポートポリシー

- バグ報告、機能要望への対応は原則として行っておりません。

- issueやPull Requestへの確認・対応をお約束するものではありません。

- 技術サポート（使い方やエラー対応等）は提供していません。

## ライセンス

### Hardware-design リポジトリ

|項目|パス|ライセンス|
|:--|:--|:--|
|ボードデザイン|`/board/`|Apache License 2.0|
|ファンクション|`/functions/`|Apache License 2.0|
|ハードウェアIP|`/ip/`|Apache License 2.0|

### Hardware-drivers リポジトリ

|項目|パス|ライセンス|
|:--|:--|:--|
|テストコード|`/test/`|BSD 3-Clause License|
|ツール|`/src/tools/`|BSD 3-Clause License|
|ライブラリ|`/src/lib/`|BSD 3-Clause License|
|ドライバ|`/src/drivers/`|GNU General Public License v2.0|