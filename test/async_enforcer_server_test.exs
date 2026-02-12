defmodule Casbin.AsyncEnforcerServerTest do
  @moduledoc """
  This test module demonstrates how to safely use EnforcerServer in async tests.

  This solves the problem described in the issue where tests using a shared
  enforcer name with async: true experience race conditions.
  """
  use ExUnit.Case, async: true

  alias Casbin.{AsyncTestHelper, EnforcerServer}

  @cfile "../data/rbac.conf" |> Path.expand(__DIR__)
  @pfile "../data/rbac.csv" |> Path.expand(__DIR__)

  describe "async tests with isolated enforcers" do
    # These tests run concurrently and demonstrate no interference

    test "test 1: add and check policies independently" do
      # Setup isolated enforcer for this test
      enforcer_name = AsyncTestHelper.unique_enforcer_name()
      {:ok, _pid} = AsyncTestHelper.start_isolated_enforcer(enforcer_name, @cfile)
      on_exit(fn -> AsyncTestHelper.stop_enforcer(enforcer_name) end)

      # Add some policies
      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["alice", "data1", "read"]})
      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["alice", "data1", "write"]})

      # Check that our policies exist (won't be affected by other tests)
      policies = EnforcerServer.list_policies(enforcer_name, %{sub: "alice"})
      assert length(policies) == 2

      # Verify allow checks work
      assert EnforcerServer.allow?(enforcer_name, ["alice", "data1", "read"])
      assert EnforcerServer.allow?(enforcer_name, ["alice", "data1", "write"])
      refute EnforcerServer.allow?(enforcer_name, ["alice", "data1", "delete"])
    end

    test "test 2: independent policies in concurrent test" do
      enforcer_name = AsyncTestHelper.unique_enforcer_name()
      {:ok, _pid} = AsyncTestHelper.start_isolated_enforcer(enforcer_name, @cfile)
      on_exit(fn -> AsyncTestHelper.stop_enforcer(enforcer_name) end)

      # Add completely different policies
      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["bob", "data2", "read"]})

      # This test should NOT see alice's policies from test 1
      policies = EnforcerServer.list_policies(enforcer_name, %{})
      assert length(policies) == 1
      assert Enum.all?(policies, fn p -> p.attrs[:sub] == "bob" end)

      # Verify isolation - bob's permissions only
      assert EnforcerServer.allow?(enforcer_name, ["bob", "data2", "read"])
      refute EnforcerServer.allow?(enforcer_name, ["alice", "data1", "read"])
    end

    test "test 3: load policies and verify isolation" do
      enforcer_name = AsyncTestHelper.unique_enforcer_name()
      {:ok, _pid} = AsyncTestHelper.start_isolated_enforcer(enforcer_name, @cfile)
      on_exit(fn -> AsyncTestHelper.stop_enforcer(enforcer_name) end)

      # Load policies from file
      :ok = EnforcerServer.load_policies(enforcer_name, @pfile)

      # Add additional policies
      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["charlie", "data3", "execute"]})

      # List all policies - should have file policies + our addition
      policies = EnforcerServer.list_policies(enforcer_name, %{})
      # Should have policies from file plus our addition
      assert length(policies) > 1
      assert Enum.any?(policies, fn p -> p.attrs[:sub] == "charlie" end)
    end

    test "test 4: remove policies without affecting other tests" do
      enforcer_name = AsyncTestHelper.unique_enforcer_name()
      {:ok, _pid} = AsyncTestHelper.start_isolated_enforcer(enforcer_name, @cfile)
      on_exit(fn -> AsyncTestHelper.stop_enforcer(enforcer_name) end)

      # Add then remove policies
      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["dave", "data4", "read"]})
      policies_before = EnforcerServer.list_policies(enforcer_name, %{})
      assert length(policies_before) == 1

      :ok = EnforcerServer.remove_policy(enforcer_name, {:p, ["dave", "data4", "read"]})
      policies_after = EnforcerServer.list_policies(enforcer_name, %{})
      assert length(policies_after) == 0

      # This removal won't affect other tests' enforcers
    end
  end

  describe "using setup_isolated_enforcer helper" do
    setup do
      # Convenient one-liner setup
      AsyncTestHelper.setup_isolated_enforcer(@cfile)
    end

    test "test with minimal setup boilerplate", %{enforcer_name: enforcer_name} do
      # Enforcer is ready to use, cleanup is automatic
      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["user1", "resource", "action"]})

      assert EnforcerServer.allow?(enforcer_name, ["user1", "resource", "action"])

      policies = EnforcerServer.list_policies(enforcer_name, %{})
      assert length(policies) == 1
    end

    test "another test with isolated state", %{enforcer_name: enforcer_name} do
      # Each test gets a fresh enforcer
      policies = EnforcerServer.list_policies(enforcer_name, %{})
      # Empty - not affected by previous test
      assert length(policies) == 0

      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["user2", "resource2", "action2"]})

      policies = EnforcerServer.list_policies(enforcer_name, %{})
      assert length(policies) == 1
      assert List.first(policies).attrs[:sub] == "user2"
    end
  end

  describe "demonstrating the fixed race condition issue" do
    # This test would have failed before the fix when run with other tests
    # Now it passes reliably even with async: true

    test "policies remain stable during test execution" do
      enforcer_name = AsyncTestHelper.unique_enforcer_name()
      {:ok, _pid} = AsyncTestHelper.start_isolated_enforcer(enforcer_name, @cfile)
      on_exit(fn -> AsyncTestHelper.stop_enforcer(enforcer_name) end)

      # Add policies with deterministic resource names
      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["admin", "org_data", "read"]})
      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["admin", "org_settings", "write"]})

      # Policies should be immediately available (not deleted by another test's cleanup)
      policies = EnforcerServer.list_policies(enforcer_name, %{sub: "admin"})
      assert length(policies) == 2

      # All checks should work
      Enum.each(policies, fn policy ->
        req = [policy.attrs[:sub], policy.attrs[:obj], policy.attrs[:act]]

        assert EnforcerServer.allow?(enforcer_name, req),
               "Expected #{inspect(req)} to be allowed"
      end)
    end

    test "no 'already existed' errors from concurrent adds" do
      enforcer_name = AsyncTestHelper.unique_enforcer_name()
      {:ok, _pid} = AsyncTestHelper.start_isolated_enforcer(enforcer_name, @cfile)
      on_exit(fn -> AsyncTestHelper.stop_enforcer(enforcer_name) end)

      # This should never return {:error, :already_existed} from another test
      result = EnforcerServer.add_policy(enforcer_name, {:p, ["unique_user", "data", "read"]})
      assert result == :ok

      # Adding the same policy again should return the error
      result2 = EnforcerServer.add_policy(enforcer_name, {:p, ["unique_user", "data", "read"]})
      assert result2 == {:error, :already_existed}
    end
  end
end
