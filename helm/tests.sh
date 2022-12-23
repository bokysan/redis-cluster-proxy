#!/usr/bin/env bash
set -e

declare FIND
mkdir -p fixtures

if command -v gfind > /dev/null; then
  FIND="$(which gfind)"
else
  FIND="$(which find)"
fi

for i in `$FIND -maxdepth 1 -type f -name test\*yml | sort`; do
    echo "☆☆☆☆☆☆☆☆☆☆ $i ☆☆☆☆☆☆☆☆☆☆"
    helm template -f $i --dry-run redis-cluster-proxy > fixtures/demo.yaml
    docker run -it -v `pwd`/fixtures:/fixtures garethr/kubeval fixtures/demo.yaml
done
