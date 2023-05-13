[![CI](https://github.com/tj-actions/setup-bin/workflows/CI/badge.svg)](https://github.com/tj-actions/setup-bin/actions?query=workflow%3ACI)
[![Update release version.](https://github.com/tj-actions/setup-bin/workflows/Update%20release%20version./badge.svg)](https://github.com/tj-actions/setup-bin/actions?query=workflow%3A%22Update+release+version.%22)
[![Public workflows that use this action.](https://img.shields.io/endpoint?url=https%3A%2F%2Fused-by.vercel.app%2Fapi%2Fgithub-actions%2Fused-by%3Faction%3Dtj-actions%2Fsetup-bin%26badge%3Dtrue)](https://github.com/search?o=desc\&q=tj-actions+setup-bin+path%3A.github%2Fworkflows+language%3AYAML\&s=\&type=Code)

## setup-bin

GitHub action to download and install go and rust binaries from github release artifacts created by [goreleaser-action](https://github.com/goreleaser/goreleaser-action) or [rust-build.action](https://github.com/rust-build/rust-build.action).

```yaml
...
    steps:
      - uses: actions/checkout@v2
      - name: Setup bin
        id: serup-bin-go
        uses: tj-actions/setup-bin@v1
        with:
          language-type: 'go'
          repository-owner: [REPOSITORY_OWNER]
          repository: [REPOSITORY]
          
      - name: Show output
        run: |
          echo "setup-bin-go: ${{ steps.setup-bin-go.outputs.binary_path }}"
```

## Inputs

<!-- AUTO-DOC-INPUT:START - Do not remove or modify this section -->

|      INPUT       |  TYPE  | REQUIRED |         DEFAULT         |                       DESCRIPTION                        |
|------------------|--------|----------|-------------------------|----------------------------------------------------------|
|  language-type   | string |   true   |                         | Language type of package to <br>install: `rust` or `go`  |
|    repository    | string |   true   |                         |       Repository where the binary is <br>located         |
| repository-owner | string |   true   |                         |    Repository owner where the binary <br>is located      |
|      token       | string |  false   | `"${{ github.token }}"` |          GITHUB\_TOKEN or a Repo scoped <br>PAT           |
|     version      | string |  false   |       `"latest"`        |          Version of the binary to <br>install            |

<!-- AUTO-DOC-INPUT:END -->

*   Free software: [MIT license](LICENSE)

If you feel generous and want to show some extra appreciation:

[![Buy me a coffee][buymeacoffee-shield]][buymeacoffee]

[buymeacoffee]: https://www.buymeacoffee.com/jackton1

[buymeacoffee-shield]: https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png

## Credits

This package was created with [Cookiecutter](https://github.com/cookiecutter/cookiecutter) using [cookiecutter-action](https://github.com/tj-actions/cookiecutter-action)

## Report Bugs

Report bugs at https://github.com/tj-actions/setup-bin/issues.

If you are reporting a bug, please include:

*   Your operating system name and version.
*   Any details about your workflow that might be helpful in troubleshooting.
*   Detailed steps to reproduce the bug.
