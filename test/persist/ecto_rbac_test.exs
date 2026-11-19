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

defmodule Casbin.Persist.EctoRbacTest do
  use ExUnit.Case, async: true
  alias Casbin.Enforcer
  alias Casbin.Persist.EctoAdapter

  @cfile "../data/rbac.conf" |> Path.expand(__DIR__)

  defmodule MockAclRepo do
    use Casbin.Persist.MockRepo, pfile: "../data/rbac.csv" |> Path.expand(__DIR__)
  end

  @repo MockAclRepo

  setup do
    adapter = EctoAdapter.new(@repo)
    {:ok, e} = Enforcer.init(@cfile, adapter)

    e =
      Enforcer.load_policies!(e)
      |> Enforcer.load_mapping_policies!()

    {:ok, e: e}
  end

  defp setup_delete_author_role(%{e: e} = ctx) do
    e = Enforcer.remove_mapping_policy(e, {:g, "author", "reader"})
    %{ctx | e: e}
  end

  describe "allow?/2" do
    @test_cases [
      {["bob", "blog_post", "read"], true},
      {["bob", "blog_post", "create"], false},
      {["bob", "blog_post", "modify"], false},
      {["bob", "blog_post", "delete"], false},
      {["peter", "blog_post", "read"], true},
      {["peter", "blog_post", "create"], true},
      {["peter", "blog_post", "modify"], true},
      {["peter", "blog_post", "delete"], false},
      {["alice", "blog_post", "read"], true},
      {["alice", "blog_post", "create"], true},
      {["alice", "blog_post", "modify"], true},
      {["alice", "blog_post", "delete"], true}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect(req)}", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

  describe "when removed mapping policy author -> reader" do
    setup [:setup_delete_author_role]

    @test_cases [
      {["bob", "blog_post", "read"], true},
      {["bob", "blog_post", "create"], false},
      {["bob", "blog_post", "modify"], false},
      {["bob", "blog_post", "delete"], false},
      {["peter", "blog_post", "read"], false},
      {["peter", "blog_post", "create"], true},
      {["peter", "blog_post", "modify"], true},
      {["peter", "blog_post", "delete"], false},
      {["alice", "blog_post", "read"], false},
      {["alice", "blog_post", "create"], true},
      {["alice", "blog_post", "modify"], true},
      {["alice", "blog_post", "delete"], true}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect(req)}", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end
end
