#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#   https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: prepare_source.sh vX.Y.Z-rcN NEW_OUTPUT_DIRECTORY" >&2
  exit 1
fi

TAG="$1"
OUTPUT="$2"
if [[ ! "$TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-rc[1-9][0-9]*$ ]]; then
  echo "expected an RC tag: vX.Y.Z-rcN" >&2
  exit 1
fi

VERSION="${TAG#v}"
BASE_VERSION="${VERSION%%-rc*}"
COMMIT="$(git rev-parse --verify "refs/tags/${TAG}^{commit}")"
COMMITTED_VERSION="$(git show "${COMMIT}:mix.exs" | sed -nE 's/^[[:space:]]*version:[[:space:]]*"([^"]+)".*/\1/p')"
if [ "$COMMITTED_VERSION" != "$BASE_VERSION" ]; then
  echo "committed mix.exs version does not match the RC tag" >&2
  exit 1
fi

for LEGAL in LICENSE NOTICE DISCLAIMER; do
  CONTENT="$(git show "${COMMIT}:${LEGAL}")"
  if [[ ! "$CONTENT" =~ [^[:space:]] ]]; then
    echo "missing or empty $LEGAL" >&2
    exit 1
  fi
done

mkdir -p -- "$(dirname "$OUTPUT")"
mkdir -- "$OUTPUT"
NAME="apache-casbin-ex-${BASE_VERSION}-incubating-src"
git archive --format=tar.gz --prefix="$NAME/" -o "$OUTPUT/$NAME.tar.gz" "$COMMIT"
(
  cd "$OUTPUT"
  sha512sum "$NAME.tar.gz" > "$NAME.tar.gz.sha512"
)
printf 'Tag: %s\nCommit: %s\nUnsigned candidate; not an approved ASF release.\n' \
  "$TAG" "$COMMIT" > "$OUTPUT/SOURCE.txt"
echo "Prepared $OUTPUT/$NAME.tar.gz from $COMMIT; signing, review and staging remain manual."
