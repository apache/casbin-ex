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

defmodule Casbin.Enforcer.AclRestfulModelTest do
  use ExUnit.Case, async: true
  alias Casbin.Enforcer

  @cfile "../data/acl_restful.conf" |> Path.expand(__DIR__)
  @pfile "../data/acl_restful.csv" |> Path.expand(__DIR__)

  setup do
    {:ok, e} = Enforcer.init(@cfile)
    e = e |> Enforcer.load_policies!(@pfile)
    {:ok, e: e}
  end

  describe "allow?/2 when `sub` is `alice`" do
    @test_cases [
      {["alice", "/alice_data", "GET"], false},
      {["alice", "/alice_data/", "GET"], true},
      {["alice", "/alice_data/hello", "GET"], true},
      {["alice", "/alice_data/foo/baz", "GET"], true},
      {["alice", "/alice_data/resource1", "GET"], true},
      {["alice", "/alice_data/resource1", "POST"], true},
      {["alice", "/alice_data/resource2", "GET"], true},
      {["alice", "/alice_data/resource2", "POST"], false},
      {["alice", "/bob_data/", "GET"], false},
      {["alice", "/bob_data/", "POST"], false},
      {["alice", "/bob_data/foo", "GET"], false},
      {["alice", "/bob_data/foo", "POST"], false},
      {["alice", "/peter_data/", "GET"], false},
      {["alice", "/peter_data/", "POST"], false},
      {["alice", "/peter_data/foo", "GET"], false},
      {["alice", "/peter_data/foo", "POST"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request `#{inspect(req)}`", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

  describe "allow?/2 when `sub` is `bob`" do
    @test_cases [
      {["bob", "/bob_data/", "POST"], true},
      {["bob", "/bob_data/", "GET"], false},
      {["bob", "/bob_data/foo", "POST"], true},
      {["bob", "/bob_data/foo", "GET"], false},
      {["bob", "/bob_data/foo/baz", "POST"], true},
      {["bob", "/bob_data/foo/baz", "GET"], false},
      {["bob", "/bob_data/foo_baz", "POST"], true},
      {["bob", "/bob_data/foo_baz", "GET"], false},
      {["bob", "/alice_data/resource2", "GET"], true},
      {["bob", "/alice_data/resource2", "POST"], false},
      {["bob", "/alice_data/", "GET"], false},
      {["bob", "/alice_data/", "POST"], false},
      {["bob", "/alice_data/resource1", "GET"], false},
      {["bob", "/alice_data/resource1", "POST"], false},
      {["bob", "/alice_data/foo", "GET"], false},
      {["bob", "/alice_data/foo", "POST"], false},
      {["bob", "/alice_data/resource1/foo", "GET"], false},
      {["bob", "/alice_data/resource1/foo", "POST"], false},
      {["bob", "/peter_data", "GET"], false},
      {["bob", "/peter_data", "POST"], false},
      {["bob", "/peter_data/", "GET"], false},
      {["bob", "/peter_data/", "POST"], false},
      {["bob", "/peter_data/foo", "GET"], false},
      {["bob", "/peter_data/foo", "POST"], false},
      {["bob", "/peter_data/foo/baz", "GET"], false},
      {["bob", "/peter_data/foo/baz", "POST"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request `#{inspect(req)}`", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

  describe "allow?/2 when `sub` is `peter`" do
    @test_cases [
      {["peter", "/peter_data", "POST"], true},
      {["peter", "/peter_data", "GET"], true},
      {["peter", "/peter_data/", "POST"], false},
      {["peter", "/peter_data/", "GET"], false},
      {["peter", "/peter_data/foo", "POST"], false},
      {["peter", "/peter_data/foo", "GET"], false},
      {["peter", "/alice_data", "GET"], false},
      {["peter", "/alice_data", "POST"], false},
      {["peter", "/alice_data/", "GET"], false},
      {["peter", "/alice_data/", "POST"], false},
      {["peter", "/alice_data/resource1", "GET"], false},
      {["peter", "/alice_data/resource1", "POST"], false},
      {["peter", "/alice_data/resource2", "GET"], false},
      {["peter", "/alice_data/resource2", "POST"], false},
      {["peter", "/alice_data/foo", "GET"], false},
      {["peter", "/alice_data/foo", "POST"], false},
      {["peter", "/bob_data", "GET"], false},
      {["peter", "/bob_data", "POST"], false},
      {["peter", "/bob_data/", "GET"], false},
      {["peter", "/bob_data/", "POST"], false},
      {["peter", "/bob_data/foo", "GET"], false},
      {["peter", "/bob_data/foo", "POST"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request `#{inspect(req)}`", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end
end
