defmodule Casbin.AsyncTestHelper do
  @moduledoc """
  Helper module for running async tests with isolated enforcer instances.

  When running tests with `async: true`, tests must use unique enforcer names
  to avoid race conditions. This module provides utilities to:

  1. Generate unique enforcer names per test
  2. Start isolated enforcer instances
  3. Cleanup enforcers after tests complete

  ## Usage

  In your test module using `async: true`:

      defmodule MyApp.AclTest do
        use ExUnit.Case, async: true
        
        alias Casbin.AsyncTestHelper

        setup do
          # Generate a unique enforcer name for this test
          enforcer_name = AsyncTestHelper.unique_enforcer_name()
          
          # Start an isolated enforcer
          {:ok, pid} = AsyncTestHelper.start_isolated_enforcer(
            enforcer_name,
            "path/to/model.conf"
          )
          
          # Cleanup on test exit
          on_exit(fn -> AsyncTestHelper.stop_enforcer(enforcer_name) end)
          
          {:ok, enforcer: enforcer_name}
        end

        test "my async test", %{enforcer: enforcer_name} do
          # Use the unique enforcer_name in your test
          EnforcerServer.add_policy(enforcer_name, {:p, ["alice", "data", "read"]})
          # ...
        end
      end

  ## Why This Is Needed

  The EnforcerServer uses a global ETS table (`:enforcers_table`) and Registry
  to store enforcer state. When multiple tests use the same enforcer name with
  `async: true`, they share the same state, causing race conditions:

  - One test's cleanup can delete another test's policies
  - Policies added by one test may appear in another test
  - `list_policies()` may return unexpected results

  By using unique enforcer names per test, each test gets its own isolated
  enforcer instance, allowing safe concurrent test execution.
  """

  alias Casbin.{EnforcerSupervisor, EnforcerServer}

  @doc """
  Generates a unique enforcer name for a test.

  The name is based on the test process's unique monotonic integer,
  ensuring no collisions even when running tests concurrently.

  ## Examples

      iex> name1 = Casbin.AsyncTestHelper.unique_enforcer_name()
      iex> name2 = Casbin.AsyncTestHelper.unique_enforcer_name()
      iex> name1 != name2
      true
  """
  def unique_enforcer_name do
    # Use a monotonic unique integer to ensure uniqueness across concurrent calls
    ref = :erlang.unique_integer([:positive, :monotonic])
    "test_enforcer_#{ref}"
  end

  @doc """
  Starts an isolated enforcer for a test.

  This is a wrapper around `EnforcerSupervisor.start_enforcer/2` that
  ensures the enforcer is properly supervised and isolated.

  ## Parameters

    * `enforcer_name` - Unique name for the enforcer (use `unique_enforcer_name/0`)
    * `config_file` - Path to the Casbin model configuration file

  ## Returns

    * `{:ok, pid}` - The enforcer was started successfully
    * `{:error, reason}` - The enforcer failed to start

  ## Examples

      enforcer_name = Casbin.AsyncTestHelper.unique_enforcer_name()
      {:ok, pid} = Casbin.AsyncTestHelper.start_isolated_enforcer(
        enforcer_name,
        "test/data/acl.conf"
      )
  """
  def start_isolated_enforcer(enforcer_name, config_file) do
    EnforcerSupervisor.start_enforcer(enforcer_name, config_file)
  end

  @doc """
  Stops an enforcer and cleans up its state.

  This function:
  1. Stops the enforcer process via the supervisor
  2. Removes the enforcer from the ETS table
  3. Cleans up the Registry entry

  Safe to call even if the enforcer doesn't exist or was already stopped.

  ## Parameters

    * `enforcer_name` - Name of the enforcer to stop

  ## Examples

      Casbin.AsyncTestHelper.stop_enforcer(enforcer_name)
  """
  def stop_enforcer(enforcer_name) do
    # Look up the enforcer process
    case Registry.lookup(Casbin.EnforcerRegistry, enforcer_name) do
      [{pid, _}] ->
        # Stop the process via the supervisor
        DynamicSupervisor.terminate_child(Casbin.EnforcerSupervisor, pid)
        # Clean up ETS table entry
        :ets.delete(:enforcers_table, enforcer_name)

      [] ->
        # Enforcer not found, clean up ETS entry just in case
        :ets.delete(:enforcers_table, enforcer_name)
    end

    :ok
  end

  @doc """
  Convenience function that combines enforcer setup and cleanup.

  This function:
  1. Generates a unique enforcer name
  2. Starts the enforcer
  3. Registers an `on_exit` callback to clean up
  4. Returns the enforcer name

  Use this in your test setup for minimal boilerplate.

  ## Parameters

    * `config_file` - Path to the Casbin model configuration file
    * `context` - The test context (optional, defaults to empty keyword list)

  ## Returns

    A map/keyword list with `:enforcer_name` key containing the unique enforcer name

  ## Examples

      setup do
        Casbin.AsyncTestHelper.setup_isolated_enforcer("test/data/acl.conf")
      end

      test "my test", %{enforcer_name: enforcer_name} do
        EnforcerServer.add_policy(enforcer_name, {:p, ["alice", "data", "read"]})
        # ...
      end
  """
  def setup_isolated_enforcer(config_file, context \\ []) do
    enforcer_name = unique_enforcer_name()

    case start_isolated_enforcer(enforcer_name, config_file) do
      {:ok, _pid} ->
        # Register cleanup
        ExUnit.Callbacks.on_exit(fn -> stop_enforcer(enforcer_name) end)

        # Return the enforcer name in the context
        # Convert context to map and add enforcer_name
        ([enforcer_name: enforcer_name] ++ Enum.into(context, []))
        |> Enum.into(%{})

      {:error, reason} ->
        raise "Failed to start isolated enforcer: #{inspect(reason)}"
    end
  end
end
