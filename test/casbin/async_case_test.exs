defmodule Casbin.AsyncCaseTest do
  use Casbin.AsyncCase, async: true

  alias Casbin.EnforcerServer

  @cfile "../../data/acl.conf" |> Path.expand(__DIR__)
  @pfile "../../data/acl.csv" |> Path.expand(__DIR__)

  setup do
    # Start isolated enforcer for this test
    enforcer_name = start_test_enforcer(@cfile)
    
    {:ok, enforcer_name: enforcer_name}
  end

  describe "AsyncCase basic functionality" do
    test "creates unique enforcer per test", %{enforcer_name: ename} do
      # Verify enforcer name is unique and properly formatted
      assert is_binary(ename)
      assert String.contains?(ename, "Casbin.AsyncCaseTest")
      
      # Verify enforcer is functional
      :ok = EnforcerServer.add_policy(ename, {:p, ["alice", "data", "read"]})
      assert EnforcerServer.allow?(ename, ["alice", "data", "read"]) == true
    end

    test "test 1 has isolated state", %{enforcer_name: ename} do
      # Add policy specific to this test
      :ok = EnforcerServer.add_policy(ename, {:p, ["user1", "resource1", "read"]})
      
      # Verify it exists
      assert EnforcerServer.allow?(ename, ["user1", "resource1", "read"]) == true
      
      # Verify only this test's policies exist
      policies = EnforcerServer.list_policies(ename, %{})
      assert length(policies) == 1
    end

    test "test 2 has different isolated state", %{enforcer_name: ename} do
      # Add different policy in this test
      :ok = EnforcerServer.add_policy(ename, {:p, ["user2", "resource2", "write"]})
      
      # Verify it exists
      assert EnforcerServer.allow?(ename, ["user2", "resource2", "write"]) == true
      
      # Should not see test 1's policies
      policies = EnforcerServer.list_policies(ename, %{sub: "user1"})
      assert length(policies) == 0
    end

    test "test 3 with loaded policies", %{enforcer_name: ename} do
      # Load pre-defined policies
      :ok = EnforcerServer.load_policies(ename, @pfile)
      
      # Verify policies are loaded
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "create"]) == true
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "read"]) == true
      
      # Add a new policy
      :ok = EnforcerServer.add_policy(ename, {:p, ["charlie", "blog_post", "delete"]})
      
      # Verify new policy works
      assert EnforcerServer.allow?(ename, ["charlie", "blog_post", "delete"]) == true
    end
  end

  describe "AsyncCase concurrent tests" do
    test "concurrent test A", %{enforcer_name: ename} do
      # Simulate real work
      :ok = EnforcerServer.add_policy(ename, {:p, ["concurrent_a", "data", "read"]})
      Process.sleep(5)
      assert EnforcerServer.allow?(ename, ["concurrent_a", "data", "read"]) == true
    end

    test "concurrent test B", %{enforcer_name: ename} do
      # Simulate real work
      :ok = EnforcerServer.add_policy(ename, {:p, ["concurrent_b", "data", "write"]})
      Process.sleep(5)
      assert EnforcerServer.allow?(ename, ["concurrent_b", "data", "write"]) == true
    end

    test "concurrent test C", %{enforcer_name: ename} do
      # Simulate real work
      :ok = EnforcerServer.add_policy(ename, {:p, ["concurrent_c", "data", "delete"]})
      Process.sleep(5)
      assert EnforcerServer.allow?(ename, ["concurrent_c", "data", "delete"]) == true
    end
  end

  describe "AsyncCase with RBAC" do
    @cfile_rbac "../../data/rbac.conf" |> Path.expand(__DIR__)
    @pfile_rbac "../../data/rbac.csv" |> Path.expand(__DIR__)

    test "works with role-based access control" do
      ename = start_test_enforcer("rbac_test", @cfile_rbac)
      
      # Load policies and mappings
      :ok = EnforcerServer.load_policies(ename, @pfile_rbac)
      :ok = EnforcerServer.load_mapping_policies(ename, @pfile_rbac)
      
      # Verify RBAC works
      # bob has role reader, reader can read
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "read"]) == true
      assert EnforcerServer.allow?(ename, ["bob", "blog_post", "create"]) == false
      
      # alice has role admin, admin can do everything
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "read"]) == true
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "create"]) == true
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "modify"]) == true
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "delete"]) == true
    end

    test "can add and remove mapping policies" do
      ename = start_test_enforcer("mapping_test", @cfile_rbac)
      
      # Load initial state
      :ok = EnforcerServer.load_policies(ename, @pfile_rbac)
      :ok = EnforcerServer.load_mapping_policies(ename, @pfile_rbac)
      
      # Add a new user with a role
      :ok = EnforcerServer.add_mapping_policy(ename, {:g, "charlie", "author"})
      
      # Verify charlie has author permissions
      assert EnforcerServer.allow?(ename, ["charlie", "blog_post", "create"]) == true
      assert EnforcerServer.allow?(ename, ["charlie", "blog_post", "delete"]) == false
      
      # Remove the mapping
      :ok = EnforcerServer.remove_mapping_policy(ename, {:g, "charlie", "author"})
      
      # Verify charlie no longer has author permissions
      assert EnforcerServer.allow?(ename, ["charlie", "blog_post", "create"]) == false
    end
  end

  describe "AsyncCase with policy modifications" do
    test "can add policies", %{enforcer_name: ename} do
      :ok = EnforcerServer.add_policy(ename, {:p, ["alice", "data1", "read"]})
      :ok = EnforcerServer.add_policy(ename, {:p, ["alice", "data1", "write"]})
      :ok = EnforcerServer.add_policy(ename, {:p, ["bob", "data2", "read"]})
      
      assert EnforcerServer.allow?(ename, ["alice", "data1", "read"]) == true
      assert EnforcerServer.allow?(ename, ["alice", "data1", "write"]) == true
      assert EnforcerServer.allow?(ename, ["bob", "data2", "read"]) == true
      
      # List policies to verify
      alice_policies = EnforcerServer.list_policies(ename, %{sub: "alice"})
      assert length(alice_policies) == 2
    end

    test "can remove policies", %{enforcer_name: ename} do
      # Add policies
      :ok = EnforcerServer.add_policy(ename, {:p, ["alice", "data1", "read"]})
      :ok = EnforcerServer.add_policy(ename, {:p, ["alice", "data1", "write"]})
      
      # Verify they exist
      assert EnforcerServer.allow?(ename, ["alice", "data1", "read"]) == true
      assert EnforcerServer.allow?(ename, ["alice", "data1", "write"]) == true
      
      # Remove one policy
      :ok = EnforcerServer.remove_policy(ename, {:p, ["alice", "data1", "read"]})
      
      # Verify it's removed but other remains
      assert EnforcerServer.allow?(ename, ["alice", "data1", "read"]) == false
      assert EnforcerServer.allow?(ename, ["alice", "data1", "write"]) == true
    end

    test "returns error for duplicate policy", %{enforcer_name: ename} do
      # Add policy
      :ok = EnforcerServer.add_policy(ename, {:p, ["alice", "data", "read"]})
      
      # Try to add again
      result = EnforcerServer.add_policy(ename, {:p, ["alice", "data", "read"]})
      assert {:error, :already_existed} = result
    end
  end
end
