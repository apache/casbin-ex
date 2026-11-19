# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

import Config

if Mix.env() == :dev do
  config :git_hooks,
    # Pin the project root, otherwise auto_install bakes deps/git_hooks into
    # the generated hook and it runs mix from the dependency's own directory.
    project_path: File.cwd!(),
    auto_install: true,
    verbose: true,
    hooks: [
      pre_push: [
        tasks: [
          {:cmd, "mix credo --strict"},
          {:cmd, "mix format"}
        ]
      ]
    ]
end
