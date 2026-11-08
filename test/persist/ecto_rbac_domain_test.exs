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

defmodule Casbin.Persist.EctoRbacDomainTest do
  use ExUnit.Case, async: true
  alias Casbin.Enforcer
  alias Casbin.Persist.EctoAdapter

  @cfile "../data/rbac_domain.conf" |> Path.expand(__DIR__)

  defmodule MockAclRepo do
    use Casbin.Persist.MockRepo, pfile: "../data/rbac_domain.csv" |> Path.expand(__DIR__)
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

  describe "allow?/2" do
    @test_cases [
      {["alice", "domain1", "data1", "read"], true},
      {["alice", "domain1", "data1", "write"], true},
      {["alice", "domain2", "data2", "read"], true},
      {["alice", "domain2", "data2", "write"], true},
      {["alice", "domain2", "data2", "no_existing"], false},
      {["alice", "domain2", "no_existing", "read"], false},
      {["alice", "domain3", "data2", "read"], false},
      {["bob", "domain1", "data1", "read"], false},
      {["bob", "domain1", "data1", "write"], false},
      {["bob", "domain2", "data2", "read"], true},
      {["bob", "domain2", "data2", "write"], true},
      {["bob", "domain2", "data2", "no_existing"], false},
      {["bob", "domain2", "no_existing", "read"], false},
      {["bob", "domain3", "data2", "read"], true},
      {["peter", "domain1", "data1", "read"], false},
      {["peter", "domain1", "data1", "write"], false},
      {["peter", "domain2", "data2", "read"], false},
      {["peter", "domain2", "data2", "write"], false},
      {["peter", "domain2", "data2", "no_existing"], false},
      {["peter", "domain2", "no_existing", "read"], false},
      {["peter", "domain3", "data2", "read"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response `#{res}` for request #{inspect(req)}", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end
end
