#!/bin/sh
set -eu

repo="$(cd "$(dirname "$0")/.." && pwd)"
image="${KIBAN_TEST_IMAGE:-ubuntu:26.04}"

docker run --rm \
  -v "${repo}:/repo" \
  -w /repo \
  -e KIBAN_TEST_SHELLS="${KIBAN_TEST_SHELLS:-}" \
  -e KIBAN_TEST_RECORD="${KIBAN_TEST_RECORD:-}" \
  -e KIBAN_TEST_JOBS="${KIBAN_TEST_JOBS:-}" \
  "${image}" \
  sh -c '
    set -eu
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq >/dev/null
    apt-get install -y -qq --no-install-recommends \
      bats zsh dash sudo ca-certificates parallel procps python3 mandoc >/dev/null
    exec "$@"
  ' sh "$@"
