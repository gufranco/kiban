#!/bin/sh
set -eu

: "${SCREENS_REPO:?}"
demo=/Users/Shared/demo
rm -rf "${demo}"
mkdir -p "${demo}/bin"
rm -rf "${HOME}/.kiban-screens"
mkdir -p "${HOME}/.kiban-screens"
