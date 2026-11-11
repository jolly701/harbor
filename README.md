# Harbor

Harbor is a macOS menu bar app for [copilot-api](https://github.com/ericc-ch/copilot-api). It starts the local proxy with a bundled Bun runtime, so the app does not need a system Node or Bun install.

## Requirements

- macOS 14 or later
- Apple Silicon

## Menu

- Start and stop the server on `127.0.0.1:4141`
- Sign in with the GitHub device flow
- Open the usage page while the server is running
- Quit, which also stops the server

The GitHub token is stored at `~/.local/share/copilot-api/github_token`.

## Build

```sh
scripts/build-app.sh
```

The script builds the release binary, assembles `dist/Harbor.app`, and ad-hoc signs it. Copy that app to `/Applications`.

Bundled in `Vendor/`:

- Bun 1.4.4 for darwin-aarch64
- copilot-api 0.7.0, including a local `/v1/responses` passthrough
