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

defmodule Casbin.Persist.EctoServerLoadTest do
  use ExUnit.Case, async: true
  alias Casbin.{EnforcerServer, EnforcerSupervisor}
  alias Casbin.Persist.EctoAdapter

  defmodule MockAclRepo do
    use Casbin.Persist.MockRepo, pfile: "../data/acl.csv" |> Path.expand(__DIR__)
  end

  defmodule MockRbacRepo do
    use Casbin.Persist.MockRepo, pfile: "../data/rbac.csv" |> Path.expand(__DIR__)
  end

  @cfile_acl "../data/acl.conf" |> Path.expand(__DIR__)
  @cfile_rbac "../data/rbac.conf" |> Path.expand(__DIR__)
  @repo_acl MockAclRepo
  @repo_rbac MockRbacRepo

  setup do
    # Every test below starts enforcers under unique names, so there is no
    # shared state to clear here. Wiping `:enforcers_table` would take out
    # the enforcers of the test modules running alongside this one.
    :ok
  end

  describe "load_policies/1 with ACL model" do
    test "loads policies from EctoAdapter on startup" do
      ename = unique_ename("test_acl_load")

      # Start enforcer
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile_acl)

      # Set persist adapter
      adapter = EctoAdapter.new(@repo_acl)
      :ok = EnforcerServer.set_persist_adapter(ename, adapter)

      # Load policies from adapter
      :ok = EnforcerServer.load_policies(ename)

      # Verify policies are loaded
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "create"]) === true
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "delete"]) === true
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "create"]) === false
      assert EnforcerServer.allow?(ename, ["peter", "blog_post", "create"]) === true
      assert EnforcerServer.allow?(ename, ["peter", "blog_post", "delete"]) === false
    end

    test "returns error when no adapter is set" do
      ename = unique_ename("test_acl_no_adapter")

      # Start enforcer without setting adapter
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile_acl)

      # Try to load policies without adapter - should work with readonly file adapter
      :ok = EnforcerServer.load_policies(ename)
    end
  end

  describe "load_policies/1 and load_mapping_policies/1 with RBAC model" do
    test "loads both policies and mapping policies from EctoAdapter" do
      ename = unique_ename("test_rbac_load")

      # Start enforcer
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile_rbac)

      # Set persist adapter
      adapter = EctoAdapter.new(@repo_rbac)
      :ok = EnforcerServer.set_persist_adapter(ename, adapter)

      # Load policies and mapping policies from adapter
      :ok = EnforcerServer.load_policies(ename)
      :ok = EnforcerServer.load_mapping_policies(ename)

      # Verify policies are loaded and role mappings work
      # bob has role reader, reader can read
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "create"]) === false

      # peter has role author, author inherits reader and can also create/modify
      assert EnforcerServer.allow?(ename, ["peter", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(ename, ["peter", "blog_post", "create"]) === true
      assert EnforcerServer.allow?(ename, ["peter", "blog_post", "modify"]) === true
      assert EnforcerServer.allow?(ename, ["peter", "blog_post", "delete"]) === false

      # alice has role admin, admin inherits author which inherits reader
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "create"]) === true
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "modify"]) === true
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "delete"]) === true
    end
  end

  describe "backward compatibility" do
    test "load_policies/2 with file path still works" do
      ename = unique_ename("test_file_load")
      pfile = "../data/acl.csv" |> Path.expand(__DIR__)

      # Start enforcer
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile_acl)

      # Load policies from file
      :ok = EnforcerServer.load_policies(ename, pfile)

      # Verify policies are loaded
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "create"]) === true
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "read"]) === true
    end

    test "load_mapping_policies/2 with file path still works" do
      ename = unique_ename("test_file_mapping_load")
      pfile = "../data/rbac.csv" |> Path.expand(__DIR__)

      # Start enforcer
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile_rbac)

      # Load policies and mapping policies from file
      :ok = EnforcerServer.load_policies(ename, pfile)
      :ok = EnforcerServer.load_mapping_policies(ename, pfile)

      # Verify role mappings work
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "delete"]) === true
    end
  end

  describe "persistence workflow" do
    test "complete workflow: set adapter, load, modify, verify" do
      ename = unique_ename("test_workflow")

      # Start enforcer
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile_acl)

      # Set persist adapter
      adapter = EctoAdapter.new(@repo_acl)
      :ok = EnforcerServer.set_persist_adapter(ename, adapter)

      # Load policies from adapter
      :ok = EnforcerServer.load_policies(ename)

      # Verify initial state
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "create"]) === true

      # Add a new policy (should persist to adapter)
      :ok = EnforcerServer.add_policy(ename, {:p, ["alice", "data", "read"]})

      # Verify new policy works
      assert EnforcerServer.allow?(ename, ["alice", "data", "read"]) === true

      # List policies to verify it's there
      policies = EnforcerServer.list_policies(ename, %{sub: "alice", obj: "data"})
      assert length(policies) === 1
    end
  end

  # Returns an enforcer name unique to the running test and stops that
  # enforcer once the test is over, so tests stay isolated from each other
  # and enforcers do not pile up while the suite runs.
  defp unique_ename(prefix) do
    ename = "#{prefix}_#{:erlang.unique_integer([:positive])}"
    on_exit(fn -> EnforcerSupervisor.stop_enforcer(ename) end)
    ename
  end
end
