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

defmodule Casbin.Enforcer.KeyMatch2Test do
  use ExUnit.Case, async: true
  alias Casbin.Enforcer

  @cfile "../data/keymatch2.conf" |> Path.expand(__DIR__)
  @pfile "../data/keymatch2.csv" |> Path.expand(__DIR__)

  setup do
    {:ok, e} = Enforcer.init(@cfile)

    e =
      e
      |> Enforcer.load_policies!(@pfile)
      |> Enforcer.load_mapping_policies!(@pfile)

    {:ok, e: e}
  end

  describe "allow?/2" do
    @test_cases [
      {["alice", "/alice_data/1", "GET"], true},
      {["alice", "/alice_data2/1/using/2", "GET"], true},
      {["alice", "/alice_data2/1/using/2", "POST"], false},
      {["alice", "/alice_data2/1/using/2/admin/", "GET"], false},
      {["alice", "/admin/alice_data2/1/using/2", "GET"], false},
      {["bob", "/admin/alice_data2/1/using/2", "GET"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect(req)}", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

  describe "key_match2?/2" do
    @test_cases [
      {"/foo", "/foo", true},
      {"/foo", "/foo*", true},
      {"/foo", "/foo/*", false},
      {"/foo/bar", "/foo", false},
      {"/foo/bar", "/foo*", false},
      {"/foo/bar", "/foo/*", true},
      {"/foobar", "/foo", false},
      {"/foobar", "/foo*", false},
      {"/foobar", "/foo/*", false},
      {"/", "/:resource", false},
      {"/resource1", "/:resource", true},
      {"/myid", "/:id/using/:resId", false},
      {"/myid/using/myresid", "/:id/using/:resId", true},
      {"/proxy/myid", "/proxy/:id/*", false},
      {"/proxy/myid/", "/proxy/:id/*", true},
      {"/proxy/myid/res", "/proxy/:id/*", true},
      {"/proxy/myid/res/res2", "/proxy/:id/*", true},
      {"/proxy/myid/res/res2/res3", "/proxy/:id/*", true},
      {"/proxy/", "/proxy/:id/*", false},
      {"/alice", "/:id", true},
      {"/alice/all", "/:id/all", true},
      {"/alice", "/:id/all", false},
      {"/alice/all", "/:id", false},
      {"/alice/all", "/:/all", false}
    ]

    Enum.each(@test_cases, fn {key1, key2, res} ->
      test "response `#{res}` for combination `#{key1}` `#{key2}`" do
        assert Enforcer.key_match2?(unquote(key1), unquote(key2)) === unquote(res)
      end
    end)
  end
end
