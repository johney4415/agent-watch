#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version=${1:-dev}
dist_dir="$repo_dir/dist"
stage_dir="$dist_dir/Agent-Watch-$version"
app_bundle="$stage_dir/Agent Watch.app"

cd "$repo_dir"
swift build -c release

rm -rf "$stage_dir"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp .build/release/agent-watch "$app_bundle/Contents/MacOS/agent-watch"
cp LICENSE "$app_bundle/Contents/Resources/LICENSE"

plutil -create xml1 "$app_bundle/Contents/Info.plist"
plutil -replace CFBundleName -string "Agent Watch" "$app_bundle/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "Agent Watch" "$app_bundle/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "dev.johney4415.agent-watch" "$app_bundle/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "agent-watch" "$app_bundle/Contents/Info.plist"
plutil -replace CFBundlePackageType -string "APPL" "$app_bundle/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$version" "$app_bundle/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$version" "$app_bundle/Contents/Info.plist"
plutil -replace LSMinimumSystemVersion -string "14.0" "$app_bundle/Contents/Info.plist"
plutil -replace LSUIElement -bool true "$app_bundle/Contents/Info.plist"
plutil -replace NSAppleEventsUsageDescription -string "Agent Watch uses automation to focus the matching iTerm2 session." "$app_bundle/Contents/Info.plist"

archive="$dist_dir/Agent-Watch-$version.zip"
rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$app_bundle" "$archive"
shasum -a 256 "$archive"
