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

defmodule Casbin.Persist.EctoAdapterTest do
  use ExUnit.Case, async: true
  alias Casbin.Persist.EctoAdapter
  alias Casbin.Persist.EctoAdapter.CasbinRule
  alias Casbin.Persist.PersistAdapter
  doctest Casbin.Persist.EctoAdapter
  doctest Casbin.Persist.EctoAdapter.CasbinRule

  defmodule MockTestRepo do
    use Casbin.Persist.MockRepo, pfile: "../data/acl.csv" |> Path.expand(__DIR__)
  end

  describe "using the mock repo" do
    @repo MockTestRepo

    test "loads policies from the database" do
      expected =
        {:ok,
         [
           ["p", "alice", "blog_post", "create"],
           ["p", "alice", "blog_post", "delete"],
           ["p", "alice", "blog_post", "modify"],
           ["p", "alice", "blog_post", "read"],
           ["p", "bob", "blog_post", "read"],
           ["p", "peter", "blog_post", "create"],
           ["p", "peter", "blog_post", "modify"],
           ["p", "peter", "blog_post", "read"]
         ]}

      loaded =
        EctoAdapter.new(@repo)
        |> PersistAdapter.load_policies()

      assert loaded === expected
    end
  end
end
