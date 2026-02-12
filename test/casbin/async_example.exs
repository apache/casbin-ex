defmodule Casbin.AsyncExample do
  @moduledoc """
  Example demonstrating the fix for shared global enforcer state in async tests.
  
  This module shows both the BEFORE (problematic) and AFTER (fixed) patterns.
  """

  defmodule BeforeAsyncFix do
    @moduledoc """
    ❌ PROBLEMATIC: Using a fixed enforcer name causes race conditions in async tests.
    
    This is what users were experiencing - tests would fail randomly when run together.
    """
    use ExUnit.Case, async: false  # Had to use async: false

    alias Casbin.{EnforcerSupervisor, EnforcerServer}

    @enforcer_name "my_enforcer"  # ❌ Shared global state!
    @cfile "../../data/acl.conf" |> Path.expand(__DIR__)

    setup do
      # All tests share the same enforcer
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(@enforcer_name, @cfile)

      on_exit(fn ->
        # This cleanup affects ALL tests using this enforcer
        :ets.delete(:enforcers_table, @enforcer_name)
      end)

      :ok
    end

    test "admin permissions" do
      EnforcerServer.add_policy(@enforcer_name, {:p, ["admin", "data", "read"]})
      # Another test's cleanup might delete this policy mid-test!
      assert EnforcerServer.allow?(@enforcer_name, ["admin", "data", "read"])
    end

    test "user permissions" do
      EnforcerServer.add_policy(@enforcer_name, {:p, ["user", "data", "read"]})
      # Race condition: might see policies from other tests
      assert EnforcerServer.allow?(@enforcer_name, ["user", "data", "read"])
    end
  end

  defmodule AfterAsyncFix do
    @moduledoc """
    ✅ FIXED: Using Casbin.AsyncCase for isolated enforcers per test.
    
    Each test gets its own enforcer instance, preventing race conditions.
    """
    use Casbin.AsyncCase, async: true  # ✅ Now safe to use async: true!

    alias Casbin.EnforcerServer

    @cfile "../../data/acl.conf" |> Path.expand(__DIR__)

    setup do
      # Each test gets its own unique enforcer
      {:ok, enforcer_name: start_test_enforcer(@cfile)}
    end

    test "admin permissions", %{enforcer_name: ename} do
      EnforcerServer.add_policy(ename, {:p, ["admin", "data", "read"]})
      # This test's policies are isolated from other tests
      assert EnforcerServer.allow?(ename, ["admin", "data", "read"])
    end

    test "user permissions", %{enforcer_name: ename} do
      EnforcerServer.add_policy(ename, {:p, ["user", "data", "read"]})
      # No interference from other tests!
      assert EnforcerServer.allow?(ename, ["user", "data", "read"])
    end

    test "concurrent test 1", %{enforcer_name: ename} do
      # Runs in parallel with other tests
      EnforcerServer.add_policy(ename, {:p, ["user1", "resource1", "action"]})
      assert EnforcerServer.allow?(ename, ["user1", "resource1", "action"])
    end

    test "concurrent test 2", %{enforcer_name: ename} do
      # Runs in parallel with other tests
      EnforcerServer.add_policy(ename, {:p, ["user2", "resource2", "action"]})
      assert EnforcerServer.allow?(ename, ["user2", "resource2", "action"])
    end
  end

  defmodule UsingTestHelper do
    @moduledoc """
    ✅ Alternative: Using Casbin.TestHelper for more control.
    
    This approach gives you more flexibility while still ensuring isolation.
    """
    use ExUnit.Case, async: true

    import Casbin.TestHelper
    alias Casbin.{EnforcerSupervisor, EnforcerServer}

    @cfile "../../data/acl.conf" |> Path.expand(__DIR__)

    setup do
      # Generate unique name and start enforcer manually
      ename = unique_enforcer_name("test_helper_example")
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)
      
      # Register cleanup
      on_exit(fn -> cleanup_enforcer(ename) end)
      
      {:ok, enforcer_name: ename}
    end

    test "using test helper", %{enforcer_name: ename} do
      EnforcerServer.add_policy(ename, {:p, ["alice", "data", "read"]})
      assert EnforcerServer.allow?(ename, ["alice", "data", "read"])
    end
  end

  defmodule QuickExample do
    @moduledoc """
    ✅ Convenience: Using create_test_enforcer for minimal boilerplate.
    """
    use ExUnit.Case, async: true

    import Casbin.TestHelper
    alias Casbin.EnforcerServer

    @cfile "../../data/acl.conf" |> Path.expand(__DIR__)

    test "quick test with minimal setup" do
      # create_test_enforcer handles everything including automatic cleanup
      {:ok, ename} = create_test_enforcer(@cfile, "quick")
      
      EnforcerServer.add_policy(ename, {:p, ["user", "resource", "action"]})
      assert EnforcerServer.allow?(ename, ["user", "resource", "action"])
      
      # Cleanup happens automatically via on_exit registered by create_test_enforcer
    end
  end
end
