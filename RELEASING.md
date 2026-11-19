<!--
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements. See the NOTICE file
distributed with this work for additional information
regarding copyright ownership. The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at

  https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied. See the License for the
specific language governing permissions and limitations
under the License.
-->

# Releasing Apache Casbin (Incubating) for Elixir

Apache Casbin is undergoing incubation at The Apache Software Foundation.
See [DISCLAIMER](DISCLAIMER) for the full disclaimer.

Follow the [ASF release policy](https://www.apache.org/legal/release-policy.html)
and [Incubation Policy](https://incubator.apache.org/policy/incubation.html#releases).
CI success and a Git tag do not constitute release approval.

1. Merge reviewed preparation changes, including the intended version in
   `mix.exs`. Check provenance, licensing, dependency advisories, actual package
   contents and display text. Build and test a clean source extraction.
2. Create the immutable `vX.Y.Z-rcN` tag. The workflow prepares an unsigned source
   archive and SHA-512 as an Actions artifact for development review. It has no
   registry credential and creates no GitHub release. Locally run
   `bash scripts/prepare_source.sh vX.Y.Z-rcN NEW_OUTPUT_DIRECTORY`.
3. Review the downloaded source and its exact commit/hash. In a clean extraction,
   run `mix deps.get`, `mix format --check-formatted`,
   `mix compile --warnings-as-errors` and `mix test` with `MIX_ENV=test` throughout.
   Record skipped tests and distinguish mock repositories from real SQL tests.
   Run `mix hex.build` and review the convenience package's contents and metadata.
4. Have the final source archive reviewed and sign its exact bytes with the
   release manager's ASF key. Stage the archive, `.sha512` and `.asc` in a new RC
   directory under `https://dist.apache.org/repos/dist/dev/incubator/casbin/`.
   Verify fresh public downloads against official Casbin KEYS. Corrections need
   a new RC; never replace signed, staged or voted files.
5. Obtain and record project/PPMC endorsement and binding IPMC approval for that
   exact candidate. Keep components, voter eligibility, ballots and tallies
   separate even when using a combined or concurrent voting arrangement.
6. After approval, promote the voted source originals and integrity files into
   the ASF release area. Do not regenerate the archives. Point final `vX.Y.Z` at
   the voted commit; final tags have no automatic publication side effects.
7. Publish the Hex convenience package from a clean extraction of approved ASF
   source with reviewed toolchain/dependency inputs. Check identity/version and
   registry nonexistence first. Use `mix hex.publish package` to omit unreviewed
   generated HexDocs. Do not use `--replace` or blindly retry uncertain uploads.
   Download the published package and verify metadata, legal files and file-byte
   correspondence with the approved source. Any future HexDocs publication needs
   a separate review of generated content and bundled assets.
8. Create GitHub release notes after approval, including the full disclaimer,
   official download and verification links. Reuse the approved originals for
   attachments. Identify pre-ASF releases accurately. Update download pages,
   announce and record closeout.

GitHub write/tag access, ASF distribution access, signing/KEYS and Hex ownership
are separate capabilities. Verify PPMC platform administration separately.
Never perform a real publication to test access. A workflow rerun produces
another development artifact, not permission to replace reviewed originals.
