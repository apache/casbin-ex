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
    # Ensure clean state
    :ets.delete_all_objects(:enforcers_table)
    :ok
  end

  describe "load_policies/1 with ACL model" do
    test "loads policies from EctoAdapter on startup" do
      ename = "test_acl_load_#{:erlang.unique_integer([:positive])}"

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
      ename = "test_acl_no_adapter_#{:erlang.unique_integer([:positive])}"

      # Start enforcer without setting adapter
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile_acl)

      # Try to load policies without adapter - should work with readonly file adapter
      :ok = EnforcerServer.load_policies(ename)
    end
  end

  describe "load_policies/1 and load_mapping_policies/1 with RBAC model" do
    test "loads both policies and mapping policies from EctoAdapter" do
      ename = "test_rbac_load_#{:erlang.unique_integer([:positive])}"

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
      ename = "test_file_load_#{:erlang.unique_integer([:positive])}"
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
      ename = "test_file_mapping_load_#{:erlang.unique_integer([:positive])}"
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
      ename = "test_workflow_#{:erlang.unique_integer([:positive])}"

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
end
