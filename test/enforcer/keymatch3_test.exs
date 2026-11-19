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

defmodule Casbin.Enforcer.KeyMatch3Test do
  use ExUnit.Case, async: true
  alias Casbin.Enforcer

  @cfile "../data/keymatch3.conf" |> Path.expand(__DIR__)
  @pfile "../data/keymatch3.csv" |> Path.expand(__DIR__)

  setup do
    {:ok, e} = Enforcer.init(@cfile)

    e =
      e
      |> Enforcer.load_policies!(@pfile)

    {:ok, e: e}
  end

  describe "allow?/2 with keyMatch3" do
    @test_cases [
      {["alice", "/alice_data/resource1", "GET"], true},
      {["alice", "/alice_data2/myid/using/myresid", "GET"], true},
      {["alice", "/alice_data2/1/using/2", "GET"], true},
      {["alice", "/alice_data2/1/using/2", "POST"], false},
      {["bob", "/bob_data/123/", "GET"], true},
      {["bob", "/bob_data/123/extra", "GET"], true},
      {["alice", "/alice_data/", "GET"], false},
      {["bob", "/alice_data/resource1", "GET"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect(req)}", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end
end
