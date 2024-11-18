# Contributing to OpenKasugai Hardware

## Reporting bugs and requests for additional functions

Use the [Issues](https://github.com/openkasugai/hardware-design/issues) on GitHub.

### BUGS

- Apply the label bug to the issue.

### Added functions

- Apply the label enhancement to the issue.

### Documentation Improvements

- Apply the label documentation to the issue.

## Other questions, design requests, ideas, etc.

- Use the  [Discussions](https://github.com/openkasugai/hardware-design/discussions) feature on GitHub.

## Development

If you want to customize the OpenKasugai Hardware implementation sample or develop a new function,
See [Function Block Development Guidelines](./docsrc/source/index.rst#function-block-development-guidelines).

## Pull Requests

- At first fork the develop branch of the OpenKasugai Hardware repository.
- Create a pull request to merge code from your feature branch to the develop branch.
  - In principle, branch names should be `feature/#[issue number]_[summary]`.
- You must agree to [DCO](https://developercertificate.org/) to contribute to OpenKasugai Hardware.
  - Add the following signature to the commit message to indicate that you agree with the DCO.
    - `Signed-off-by: Random J Developer <random@developer.example.org>`
      - Use your real name in the signature.
      - You need to set the same name and the email in GitHub Profile.
      - `git commit -s` can add the signature.
- Associate a pull request with the corresponding Issue.
  - If there is no corresponding issue, create a new one before creating a pull request.
- Use the templates when creating a pull request.
- The title of a pull request should include "fix" followed by the issue number and a summary of the pull request.
  - `fix #[issue number] [summary]`
