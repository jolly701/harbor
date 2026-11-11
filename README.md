# Harbor

Harbor is a macOS menu bar app for [copilot-api](https://github.com/ericc-ch/copilot-api). It starts the local proxy with a bundled Bun runtime, so the app does not need a system Node or Bun install.

Opening Harbor shows a control window. Closing the window keeps the app in the menu bar; open Harbor again or choose “打开 Harbor” in the menu to bring the window back.
Only one Harbor instance runs per user. Opening another instance brings the existing window forward.

## Requirements

- macOS 14 or later
- Apple Silicon

## Menu

- Start and stop the server on `127.0.0.1:4141`
- Sign in with the GitHub device flow
- Open the usage page while the server is running
- Quit, which also stops the server started by Harbor

If another process already uses port 4141, Harbor reports the conflict and leaves that process alone.

The GitHub token is stored at `~/.local/share/copilot-api/github_token`.

## Build

Building requires Xcode command line tools, Node.js 20.18.1 or later, and npm 9 or later. The
first build downloads the pinned Bun and copilot-api packages from npm; npm
verifies their integrity using `Runtime/package-lock.json`.

```sh
scripts/build-app.sh
```

The script prepares the runtime in `.build/harbor-runtime`, builds the release binary, assembles `dist/Harbor.app`, and ad-hoc signs it. Copy that app to `/Applications`.

Bundled in the application:

- Bun 1.4.4 for darwin-aarch64
- copilot-api 0.7.0, with the local compatibility changes in `patches/copilot-api-0.7.0.patch`

For `swift run`, first run `scripts/prepare-runtime.sh` to prepare the local runtime.
