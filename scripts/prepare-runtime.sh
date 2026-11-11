#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/.build"
staging="$(mktemp -d "$root/.build/harbor-runtime.XXXXXX")"
trap 'rm -rf "$staging"' EXIT HUP INT TERM

cp "$root/Runtime/package.json" "$root/Runtime/package-lock.json" "$staging/"
npm ci --prefix "$staging" --omit=dev --ignore-scripts --no-audit --no-fund

mkdir -p "$staging/bun" "$staging/copilot-api/node_modules"
cp "$staging/node_modules/@oven/bun-darwin-aarch64/bin/bun" "$staging/bun/bun"
chmod +x "$staging/bun/bun"
cp -R "$staging/node_modules/copilot-api/." "$staging/copilot-api/"
rsync -a --exclude '/@oven/' --exclude '/copilot-api/' --exclude '/.bin/copilot-api' \
  "$staging/node_modules/" "$staging/copilot-api/node_modules/"
patch -s -d "$staging/copilot-api" -p1 < "$root/patches/copilot-api-0.7.0.patch"

rm -rf "$staging/node_modules"
rm -rf "$root/.build/harbor-runtime"
mv "$staging" "$root/.build/harbor-runtime"
trap - EXIT HUP INT TERM
