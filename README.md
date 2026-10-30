# mimic-cli

Releases and installer for `mimic`, the command-line client for Mimic.
Single static binary, no runtime dependencies. The source lives in the Mimic repo.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Ubikron-Tech-Farm/mimic-cli/main/install.sh | sh
```

The script picks the release for your OS and architecture, verifies it against
`checksums.txt`, and installs `mimic` to `/usr/local/bin` if writable, otherwise
`~/.local/bin`. Set `MIMIC_VERSION=0.6.0` to pin a version, `MIMIC_INSTALL_DIR`
to choose the directory, and `GH_TOKEN` while this repository is private.

While the repository is private, `raw.githubusercontent.com` needs a token too,
so fetch the script through `gh`:

```bash
export GH_TOKEN=$(gh auth token)
gh api repos/Ubikron-Tech-Farm/mimic-cli/contents/install.sh -H 'Accept: application/vnd.github.raw' | sh
```

Or download a binary from [releases](https://github.com/Ubikron-Tech-Farm/mimic-cli/releases).

## Next

```bash
mimic login                         # or: mimic login --server your-host/mimic
mimic update                        # later, to upgrade in place
mimic skills install                # teach your AI agent the CLI
```
