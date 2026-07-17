#!/bin/sh
set -eu

bin_path=${AGENTWATCH_BIN_DIR:-"$HOME/.local/bin"}/agent-watch
app_bundle=${AGENTWATCH_APP_DIR:-"$HOME/Applications"}/Agent Watch.app

if [ -f "$bin_path" ]; then rm "$bin_path"; fi
if [ -d "$app_bundle" ]; then rm -R "$app_bundle"; fi

printf 'Removed Agent Watch. Hook configuration and ~/.agent-watch were left untouched.\n'
