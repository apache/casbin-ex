#!/usr/bin/env python3
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

"""Prepare unsigned RC sources locally, without signing or publication."""

import hashlib
from pathlib import Path
import re
import subprocess
import sys


def git(*args):
    return subprocess.check_output(["git", *args])


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare_source.py vX.Y.Z-rcN NEW_OUTPUT_DIRECTORY")
    tag, output = sys.argv[1:]
    match = re.fullmatch(r"v(\d+\.\d+\.\d+)-rc[1-9]\d*", tag)
    if not match:
        raise SystemExit("expected an RC tag: vX.Y.Z-rcN")
    version = match[1]
    commit = git("rev-parse", "--verify", f"refs/tags/{tag}^{{commit}}").decode().strip()
    manifest = git("show", f"{commit}:mix.exs").decode()
    if re.findall(r'^\s*version:\s*"([^"]+)"', manifest, re.MULTILINE) != [version]:
        raise SystemExit("committed mix.exs version does not match the RC tag")
    for legal in ("LICENSE", "NOTICE", "DISCLAIMER"):
        if not git("show", f"{commit}:{legal}").strip():
            raise SystemExit(f"missing or empty {legal}")
    destination = Path(output)
    destination.mkdir(parents=True, exist_ok=False)
    name = f"apache-casbin-ex-{version}-incubating-src"
    archive = destination / f"{name}.tar.gz"
    subprocess.run(
        ["git", "archive", "--format=tar.gz", f"--prefix={name}/", f"--output={archive}", commit],
        check=True,
    )
    digest = hashlib.sha512(archive.read_bytes()).hexdigest()
    (destination / f"{archive.name}.sha512").write_text(
        f"{digest}  {archive.name}\n", encoding="ascii"
    )
    (destination / "SOURCE.txt").write_text(
        f"Tag: {tag}\nCommit: {commit}\nUnsigned candidate; not an approved ASF release.\n",
        encoding="utf-8",
    )
    print(f"Prepared {archive} from {commit}; signing, review and staging remain manual.")


if __name__ == "__main__":
    main()
