defmodule Casbin.AsyncCase do
  @moduledoc """
  A test case template for async-safe Casbin tests.

  This module provides a convenient way to write tests that use Casbin enforcers
  with `async: true`. It automatically handles enforcer isolation, preventing
  race conditions that occur when multiple tests share the same enforcer instance.

  ## Problem

  When using EnforcerServer with a fixed name, all tests share the same global
  state, making `async: true` tests fail with race conditions:

  ```elixir
  # ❌ This fails with async: true
  defmodule MyApp.PermissionsTest do
    use ExUnit.Case, async: true
    
    test "test 1" do
      EnforcerServer.add_policy("my_enforcer", {:p, ["user", "data", "read"]})
      assert EnforcerServer.allow?("my_enforcer", ["user", "data", "read"])
    end
    
    test "test 2" do
      # Test 1's cleanup might delete policies while this test is running!
      EnforcerServer.add_policy("my_enforcer", {:p, ["admin", "data", "write"]})
      assert EnforcerServer.allow?("my_enforcer", ["admin", "data", "write"])
    end
  end
  ```

  ## Solution

  Use `Casbin.AsyncCase` to automatically create isolated enforcers per test:

  ```elixir
  # ✅ This works with async: true
  defmodule MyApp.PermissionsTest do
    use Casbin.AsyncCase, async: true

    @config_file "path/to/casbin.conf"

    setup do
      {:ok, enforcer_name: start_test_enforcer(@config_file)}
    end

    test "test 1", %{enforcer_name: ename} do
      EnforcerServer.add_policy(ename, {:p, ["user", "data", "read"]})
      assert EnforcerServer.allow?(ename, ["user", "data", "read"])
    end

    test "test 2", %{enforcer_name: ename} do
      # This test has its own isolated enforcer!
      EnforcerServer.add_policy(ename, {:p, ["admin", "data", "write"]})
      assert EnforcerServer.allow?(ename, ["admin", "data", "write"])
    end
  end
  ```

  ## Using with EctoAdapter

  When using `EctoAdapter` with Ecto.SQL.Sandbox, you may need to allow the
  enforcer process to access the database connection:

  ```elixir
  defmodule MyApp.PermissionsTest do
    use MyApp.DataCase, async: true
    use Casbin.AsyncCase

    @config_file Application.app_dir(:my_app, "priv/casbin/model.conf")

    setup do
      # Check out and allow enforcer to use the connection
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)
      
      enforcer_name = start_test_enforcer(@config_file)
      
      # Allow enforcer process to access the database
      case Registry.lookup(Casbin.EnforcerRegistry, enforcer_name) do
        [{pid, _}] -> Ecto.Adapters.SQL.Sandbox.allow(MyApp.Repo, self(), pid)
        [] -> :ok
      end
      
      # Set up the adapter
      adapter = Casbin.Persist.EctoAdapter.new(MyApp.Repo)
      :ok = Casbin.EnforcerServer.set_persist_adapter(enforcer_name, adapter)
      
      {:ok, enforcer_name: enforcer_name}
    end

    test "policies persist to database", %{enforcer_name: ename} do
      :ok = EnforcerServer.add_policy(ename, {:p, ["user", "data", "read"]})
      :ok = EnforcerServer.save_policies(ename)
      
      # Verify it persisted
      assert EnforcerServer.allow?(ename, ["user", "data", "read"])
    end
  end
  ```

  ## Available Functions

  When you `use Casbin.AsyncCase`, the following functions become available:

  - `start_test_enforcer/1` - Starts an isolated enforcer for the current test
  - `start_test_enforcer/2` - Starts an isolated enforcer with a custom prefix
  - `unique_enforcer_name/1` - Generates a unique enforcer name

  These functions automatically handle cleanup via `on_exit/1`.

  ## Module Options

  You can pass options when using this module:

  ```elixir
  use Casbin.AsyncCase, async: true, prefix: "my_test"
  ```

  Options:
  - `async` - Passed to ExUnit.Case (default: true)
  - `prefix` - Default prefix for enforcer names (default: module name)

  ## Implementation Details

  This module:
  1. Uses `ExUnit.Case` under the hood
  2. Imports `Casbin.TestHelper` for convenience functions
  3. Generates unique enforcer names using `:erlang.unique_integer/1`
  4. Automatically cleans up enforcers via `on_exit/1` callbacks
  5. Clears the ETS table state between tests
  """

  defmacro __using__(opts) do
    # Extract async option (default to true for safety)
    async = Keyword.get(opts, :async, true)

    # Extract prefix option (default to module name)
    # Note: __CALLER__.module will be the test module using this macro
    prefix = Keyword.get(opts, :prefix, nil)

    quote do
      use ExUnit.Case, async: unquote(async)
      import Casbin.TestHelper

      # Store the default prefix for this test module
      @test_prefix unquote(prefix) || __MODULE__ |> to_string() |> String.replace("Elixir.", "")

      @doc """
      Starts a test enforcer with automatic isolation and cleanup.

      Creates a unique enforcer for the current test using the module's default
      prefix and the provided config file.

      ## Parameters

      - `config_file` - Path to the Casbin configuration file

      ## Returns

      The unique enforcer name (string) that can be used with EnforcerServer functions.

      ## Examples

          setup do
            {:ok, enforcer_name: start_test_enforcer("config/model.conf")}
          end

      The enforcer is automatically cleaned up when the test exits.
      """
      def start_test_enforcer(config_file) do
        start_test_enforcer(@test_prefix, config_file)
      end

      @doc """
      Starts a test enforcer with a custom prefix.

      Similar to `start_test_enforcer/1`, but allows specifying a custom prefix
      for the enforcer name.

      ## Parameters

      - `prefix` - Custom prefix for the enforcer name
      - `config_file` - Path to the Casbin configuration file

      ## Returns

      The unique enforcer name (string).

      ## Examples

          setup do
            ename = start_test_enforcer("custom_prefix", "config/model.conf")
            {:ok, enforcer_name: ename}
          end
      """
      def start_test_enforcer(prefix, config_file) do
        ename = unique_enforcer_name(prefix)

        {:ok, _pid} = Casbin.EnforcerSupervisor.start_enforcer(ename, config_file)

        # Automatically clean up when test exits
        on_exit(fn -> cleanup_enforcer(ename) end)

        ename
      end
    end
  end
end
