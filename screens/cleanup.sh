#!/bin/sh
set -u

data="${HOME}/.kiban-screens"
if docker inspect redis --format '{{range .Mounts}}{{.Source}} {{end}}' 2>/dev/null | grep -q "${data}/"; then
  docker stop redis >/dev/null
  docker rm redis >/dev/null
fi
rm -rf "${data}" /Users/Shared/demo
