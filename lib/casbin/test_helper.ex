defmodule Casbin.TestHelper do
  @moduledoc """
  Helper utilities for testing with Casbin enforcers in async mode.

  This module provides functions to create isolated enforcers for each test,
  preventing race conditions when running tests with `async: true`.

  ## Problem

  When using a fixed enforcer name (e.g., `"my_enforcer"`), all tests share
  the same global state, causing race conditions in async tests:

  ```elixir
  # This fails with async: true
  defmodule MyApp.AclTest do
    use ExUnit.Case, async: true  # ❌ Tests interfere with each other

    test "admin has permissions" do
      EnforcerServer.add_policy("my_enforcer", {:p, ["admin", "data", "read"]})
      # Another test's cleanup may delete this policy mid-test!
      assert EnforcerServer.allow?("my_enforcer", ["admin", "data", "read"])
    end
  end
  ```

  ## Solution

  Use `unique_enforcer_name/1` to generate a unique name for each test:

  ```elixir
  defmodule MyApp.AclTest do
    use ExUnit.Case, async: true  # ✅ Tests are isolated
    import Casbin.TestHelper

    setup do
      ename = unique_enforcer_name("acl_test")
      {:ok, _pid} = Casbin.EnforcerSupervisor.start_enforcer(ename, config_path)
      
      on_exit(fn -> cleanup_enforcer(ename) end)
      
      {:ok, enforcer_name: ename}
    end

    test "admin has permissions", %{enforcer_name: ename} do
      EnforcerServer.add_policy(ename, {:p, ["admin", "data", "read"]})
      assert EnforcerServer.allow?(ename, ["admin", "data", "read"])
    end
  end
  ```

  ## Functions

  - `unique_enforcer_name/1` - Generates a unique enforcer name with optional prefix
  - `cleanup_enforcer/1` - Cleans up an enforcer and its state
  """

  @doc """
  Generates a unique enforcer name for test isolation.

  The generated name includes a prefix (default: "test") and a unique integer,
  ensuring no naming conflicts between parallel tests.

  ## Parameters

  - `prefix` - Optional string prefix for the enforcer name (default: "test")

  ## Examples

      iex> name1 = Casbin.TestHelper.unique_enforcer_name("acl")
      iex> name2 = Casbin.TestHelper.unique_enforcer_name("acl")
      iex> name1 != name2
      true

      iex> name = Casbin.TestHelper.unique_enforcer_name("my_module")
      iex> String.contains?(name, "my_module")
      true

      iex> name = Casbin.TestHelper.unique_enforcer_name()
      iex> String.contains?(name, "test")
      true

  ## Usage in Tests

      setup do
        ename = unique_enforcer_name("user_permissions")
        {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, config_file)
        on_exit(fn -> cleanup_enforcer(ename) end)
        {:ok, enforcer_name: ename}
      end
  """
  def unique_enforcer_name(prefix \\ "test") do
    "#{prefix}_#{:erlang.unique_integer([:positive, :monotonic])}"
  end

  @doc """
  Cleans up an enforcer and removes it from the ETS table.

  This function should be called in the test's `on_exit/1` callback to ensure
  proper cleanup after each test.

  ## Parameters

  - `ename` - The enforcer name to clean up

  ## Examples

      on_exit(fn -> 
        Casbin.TestHelper.cleanup_enforcer(enforcer_name)
      end)

  ## Implementation Notes

  This function:
  1. Removes the enforcer from the ETS table (`:enforcers_table`)
  2. Stops the enforcer process if it's still running

  Note: If the enforcer is supervised by `EnforcerSupervisor`, the supervisor
  will automatically restart it. For tests, you typically don't need to worry
  about this as the test process exits.
  """
  def cleanup_enforcer(ename) do
    # Remove from ETS table
    :ets.delete(:enforcers_table, ename)

    # Try to stop the process if it's registered
    case Registry.lookup(Casbin.EnforcerRegistry, ename) do
      [{pid, _}] when is_pid(pid) ->
        # Stop the process. We use :shutdown as the reason for a clean exit
        # The supervisor won't restart it because it's a test scenario
        if Process.alive?(pid) do
          DynamicSupervisor.terminate_child(Casbin.EnforcerSupervisor, pid)
        end

      [] ->
        :ok
    end
  end

  @doc """
  Creates a test enforcer with a unique name and automatic cleanup.

  This is a convenience function that combines `unique_enforcer_name/1`,
  enforcer startup, and automatic cleanup.

  ## Parameters

  - `config_file` - Path to the Casbin configuration file
  - `prefix` - Optional string prefix for the enforcer name (default: "test")

  ## Returns

  `{:ok, enforcer_name}` on success, or `{:error, reason}` on failure.

  ## Examples

      test "admin permissions" do
        {:ok, ename} = Casbin.TestHelper.create_test_enforcer(config_path)
        EnforcerServer.add_policy(ename, {:p, ["admin", "data", "read"]})
        assert EnforcerServer.allow?(ename, ["admin", "data", "read"])
      end

      test "with custom prefix" do
        {:ok, ename} = Casbin.TestHelper.create_test_enforcer(config_path, "my_test")
        # ...
      end

  Note: This function automatically registers cleanup in `on_exit/1`, so you
  don't need to manually clean up the enforcer.
  """
  def create_test_enforcer(config_file, prefix \\ "test") do
    ename = unique_enforcer_name(prefix)

    case Casbin.EnforcerSupervisor.start_enforcer(ename, config_file) do
      {:ok, _pid} ->
        # Register cleanup
        ExUnit.Callbacks.on_exit(fn -> cleanup_enforcer(ename) end)
        {:ok, ename}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
