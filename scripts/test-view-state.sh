#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/.build"
swiftc -parse-as-library \
  "$root/Sources/Harbor/HarborViews.swift" \
  "$root/Sources/Harbor/HarborMode.swift" \
  "$root/Sources/Harbor/CopilotUsage.swift" \
  "$root/Sources/Harbor/L10n.swift" \
  "$root/Tests/HarborViewStateChecks.swift" \
  -o "$root/.build/HarborViewStateChecks"
"$root/.build/HarborViewStateChecks"
