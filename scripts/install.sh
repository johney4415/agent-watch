#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bin_dir=${AGENTWATCH_BIN_DIR:-"$HOME/.local/bin"}
app_dir=${AGENTWATCH_APP_DIR:-"$HOME/Applications"}
app_bundle="$app_dir/Agent Watch.app"

cd "$repo_dir"
swift build -c release

mkdir -p "$bin_dir" "$app_bundle/Contents/MacOS"
cp .build/release/agent-watch "$bin_dir/agent-watch"
cp .build/release/agent-watch "$app_bundle/Contents/MacOS/agent-watch"

plutil -create xml1 "$app_bundle/Contents/Info.plist"
plutil -replace CFBundleName -string "Agent Watch" "$app_bundle/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "Agent Watch" "$app_bundle/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "dev.johney4415.agent-watch" "$app_bundle/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "agent-watch" "$app_bundle/Contents/Info.plist"
plutil -replace CFBundlePackageType -string "APPL" "$app_bundle/Contents/Info.plist"
plutil -replace LSUIElement -bool true "$app_bundle/Contents/Info.plist"
plutil -replace NSAppleEventsUsageDescription -string "Agent Watch uses automation to focus the matching iTerm2 session." "$app_bundle/Contents/Info.plist"

printf 'Installed CLI: %s\n' "$bin_dir/agent-watch"
printf 'Installed app: %s\n' "$app_bundle"
printf 'Next: add the hooks documented in README.md, then open Agent Watch.app.\n'
