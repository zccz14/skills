#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} != --help ]] || { echo 'Usage: sync-main.sh'; exit; }
[[ $# == 0 ]]
git fetch --prune origin
git switch main
git pull --ff-only origin main
