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

defmodule Casbin.Persist.ReadonlyFileAdapterFilteredTest do
  use ExUnit.Case, async: true
  alias Casbin.Enforcer
  alias Casbin.Persist.PersistAdapter
  alias Casbin.Persist.ReadonlyFileAdapter

  @cfile "../data/rbac_domain.conf" |> Path.expand(__DIR__)
  @pfile "../data/rbac_domain.csv" |> Path.expand(__DIR__)

  describe "load_filtered_policy/2 with ReadonlyFileAdapter" do
    test "filters policies by domain" do
      adapter = ReadonlyFileAdapter.new(@pfile)

      # Load only policies for domain1 (domain is at v1 position)
      {:ok, policies} = PersistAdapter.load_filtered_policy(adapter, %{v1: "domain1"})

      # Should only have policies with domain1
      assert length(policies) == 2

      assert Enum.all?(policies, fn [_ptype, _subj, domain, _obj, _act] -> domain == "domain1" end)
    end

    test "filters policies by ptype" do
      adapter = ReadonlyFileAdapter.new(@pfile)

      # Load only p (policy) rules, not g (role) rules
      {:ok, policies} = PersistAdapter.load_filtered_policy(adapter, %{ptype: "p"})

      # Should only have p rules
      assert length(policies) == 5
      assert Enum.all?(policies, fn [ptype | _] -> ptype == "p" end)
    end

    test "filters policies by multiple criteria" do
      adapter = ReadonlyFileAdapter.new(@pfile)

      # Load only p rules for domain2 (domain is at v1 position)
      {:ok, policies} = PersistAdapter.load_filtered_policy(adapter, %{ptype: "p", v1: "domain2"})

      # Should only have p rules with domain2
      assert length(policies) == 2

      assert Enum.all?(policies, fn [ptype, _subj, domain, _obj, _act] ->
               ptype == "p" && domain == "domain2"
             end)
    end

    test "filters policies by list of values" do
      adapter = ReadonlyFileAdapter.new(@pfile)

      # Load policies for domain1 OR domain2 (domain is at v1 position)
      {:ok, policies} =
        PersistAdapter.load_filtered_policy(adapter, %{v1: ["domain1", "domain2"]})

      # Should have policies with domain1 or domain2
      assert length(policies) == 4

      assert Enum.all?(policies, fn [_ptype, _subj, domain, _obj, _act] ->
               domain in ["domain1", "domain2"]
             end)
    end

    test "returns empty list when policy file is nil" do
      adapter = ReadonlyFileAdapter.new()
      assert {:ok, []} == PersistAdapter.load_filtered_policy(adapter, %{})
    end

    test "returns empty list when no policies match filter" do
      adapter = ReadonlyFileAdapter.new(@pfile)

      # Load policies for non-existent domain
      {:ok, policies} = PersistAdapter.load_filtered_policy(adapter, %{v1: "non_existent_domain"})

      assert policies == []
    end
  end

  describe "load_filtered_policies!/2 with Enforcer and ReadonlyFileAdapter" do
    test "loads only filtered policies into enforcer" do
      {:ok, e} = Enforcer.init(@cfile)
      adapter = ReadonlyFileAdapter.new(@pfile)
      e = Enforcer.set_persist_adapter(e, adapter)

      # Load only policies for domain1 (domain is at v1 position)
      e =
        Enforcer.load_filtered_policies!(e, %{v1: "domain1"})
        |> Enforcer.load_mapping_policies!()

      # Should only have domain1 policies
      policies = Enforcer.list_policies(e)
      assert length(policies) == 2

      # Domain1 requests should work
      assert Enforcer.allow?(e, ["alice", "domain1", "data1", "read"]) === true
      assert Enforcer.allow?(e, ["alice", "domain1", "data1", "write"]) === true

      # Domain2 requests should not work (policies not loaded)
      assert Enforcer.allow?(e, ["alice", "domain2", "data2", "read"]) === false
      assert Enforcer.allow?(e, ["bob", "domain2", "data2", "read"]) === false
    end

    test "loads only p policies when filtered by ptype" do
      {:ok, e} = Enforcer.init(@cfile)
      adapter = ReadonlyFileAdapter.new(@pfile)
      e = Enforcer.set_persist_adapter(e, adapter)

      # Load only p rules, not g rules
      e = Enforcer.load_filtered_policies!(e, %{ptype: "p"})

      policies = Enforcer.list_policies(e)
      assert length(policies) == 5

      # Without role mappings loaded, role-based permissions should not work
      mapping_policies = Enforcer.list_mapping_policies(e)
      assert mapping_policies == []
    end
  end
end
