# OpenKasugai Hardware へのコントリビューション

## バグの報告・機能追加要望

GitHub の [Issues](https://github.com/openkasugai/hardware-design/issues) を使用してください。

### バグ

- Labels には `bug` を付与してください。

### 機能追加

- Labels には `enhancement` を付与してください。

### ドキュメント改善

- Labels には `documentation` を付与してください。

## その他質問、設計に関する要望やアイデアなど

GitHub の [Discussions](https://github.com/openkasugai/hardware-design/discussions)機能をご利用ください。

## 開発

OpenKasugai Hardwareの実装サンプルをカスタマイズする場合や新規にファンクションを開発する場合は
[ファンクションブロック開発ガイドライン](./docsrc/source/index_ja.rst#function-block-development-guidelines)を参照ください。 

## プルリクエスト

- コントリビュータは、最初に OpenKasugai Hardware リポジトリの develop branch を fork してください。
- コントリビュータは、fork したリポジトリ上で topic branch を作成し、OpenKasugai Hardware 配下のリポジトリの develop branch に対して Pull Request を行ってください。
  - topic branch のブランチ名は任意です。
- コントリビュータは、[DCO](https://developercertificate.org/)に同意する必要があります。
  - DCO に同意していることを示すため、全てのコミットに対して、コミットメッセージに以下を記入してください。
    - `Signed-off-by: Random J Developer <random@developer.example.org>`
      - 氏名の部分は、本名を使用してください。
      - GitHub の Profile の Name に同じ名前、Email に同じメールアドレスを設定する必要があります。
      - `git commit -s` でコミットに署名を追加ください。
- Pull Request を発行する際は、対応する Issue に紐づけてください。
  - 対応する Issue がない場合は Pull Request の発行前に作成してください。
- Pull Request のタイトルには、"fix"に続いて対処した issue 番号および修正の概要を記入してください。
  - `fix #[issue番号] [修正の概要]`
- Pull Request の本文は、テンプレートを使用してください。

