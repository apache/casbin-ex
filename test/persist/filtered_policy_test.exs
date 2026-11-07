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

defmodule Casbin.Persist.FilteredPolicyTest do
  use ExUnit.Case, async: true
  alias Casbin.Enforcer
  alias Casbin.Persist.EctoAdapter
  alias Casbin.Persist.PersistAdapter

  @cfile "../data/rbac_domain.conf" |> Path.expand(__DIR__)

  describe "load_filtered_policy/2 with EctoAdapter" do
    test "returns error when repo is not set" do
      adapter = EctoAdapter.new(nil)
      assert {:error, "repo is not set"} == PersistAdapter.load_filtered_policy(adapter, %{})
    end
  end

  describe "load_filtered_policies!/2 with Enforcer" do
    test "raises error when repo is not set" do
      adapter = EctoAdapter.new(nil)
      {:ok, e} = Enforcer.init(@cfile, adapter)

      assert_raise ArgumentError, "repo is not set", fn ->
        Enforcer.load_filtered_policies!(e, %{v2: "domain1"})
      end
    end
  end
end
