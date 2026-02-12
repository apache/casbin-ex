defmodule Casbin.AsyncTestHelperTest do
  use ExUnit.Case, async: true

  alias Casbin.AsyncTestHelper
  alias Casbin.EnforcerServer

  @cfile "../data/acl.conf" |> Path.expand(__DIR__)

  describe "unique_enforcer_name/0" do
    test "generates unique names" do
      name1 = AsyncTestHelper.unique_enforcer_name()
      name2 = AsyncTestHelper.unique_enforcer_name()

      assert is_binary(name1)
      assert is_binary(name2)
      assert name1 != name2
      assert String.starts_with?(name1, "test_enforcer_")
      assert String.starts_with?(name2, "test_enforcer_")
    end

    test "generates unique names across concurrent calls" do
      # Spawn multiple processes to generate names concurrently
      tasks =
        for _ <- 1..10 do
          Task.async(fn -> AsyncTestHelper.unique_enforcer_name() end)
        end

      names = Task.await_many(tasks)

      # All names should be unique
      assert length(names) == length(Enum.uniq(names))
    end
  end

  describe "start_isolated_enforcer/2 and stop_enforcer/1" do
    test "starts and stops an enforcer" do
      enforcer_name = AsyncTestHelper.unique_enforcer_name()

      assert {:ok, pid} = AsyncTestHelper.start_isolated_enforcer(enforcer_name, @cfile)
      assert is_pid(pid)
      assert Process.alive?(pid)

      # Verify enforcer is registered
      assert [{^pid, _}] = Registry.lookup(Casbin.EnforcerRegistry, enforcer_name)

      # Verify enforcer is in ETS table
      assert [{^enforcer_name, _}] = :ets.lookup(:enforcers_table, enforcer_name)

      # Stop the enforcer
      assert :ok = AsyncTestHelper.stop_enforcer(enforcer_name)

      # Verify enforcer is removed from registry
      assert [] = Registry.lookup(Casbin.EnforcerRegistry, enforcer_name)

      # Verify enforcer is removed from ETS table
      assert [] = :ets.lookup(:enforcers_table, enforcer_name)
    end

    test "stop_enforcer is idempotent" do
      enforcer_name = AsyncTestHelper.unique_enforcer_name()
      {:ok, _pid} = AsyncTestHelper.start_isolated_enforcer(enforcer_name, @cfile)

      # Stopping once should work
      assert :ok = AsyncTestHelper.stop_enforcer(enforcer_name)

      # Stopping again should also work without error
      assert :ok = AsyncTestHelper.stop_enforcer(enforcer_name)
    end

    test "stop_enforcer works with non-existent enforcer" do
      # Use a unique name that is guaranteed not to exist
      enforcer_name = AsyncTestHelper.unique_enforcer_name()

      # Should not raise an error
      assert :ok = AsyncTestHelper.stop_enforcer(enforcer_name)
    end
  end

  describe "enforcer isolation" do
    test "each enforcer has independent state" do
      # Start two isolated enforcers
      enforcer1 = AsyncTestHelper.unique_enforcer_name()
      enforcer2 = AsyncTestHelper.unique_enforcer_name()

      {:ok, _pid1} = AsyncTestHelper.start_isolated_enforcer(enforcer1, @cfile)
      {:ok, _pid2} = AsyncTestHelper.start_isolated_enforcer(enforcer2, @cfile)

      # Add policy to enforcer1
      :ok = EnforcerServer.add_policy(enforcer1, {:p, ["alice", "data1", "read"]})

      # Add different policy to enforcer2
      :ok = EnforcerServer.add_policy(enforcer2, {:p, ["bob", "data2", "write"]})

      # Verify enforcer1 has only its policy
      policies1 = EnforcerServer.list_policies(enforcer1, %{})
      assert length(policies1) == 1
      assert Enum.any?(policies1, fn p -> p.attrs[:sub] == "alice" end)
      refute Enum.any?(policies1, fn p -> p.attrs[:sub] == "bob" end)

      # Verify enforcer2 has only its policy
      policies2 = EnforcerServer.list_policies(enforcer2, %{})
      assert length(policies2) == 1
      assert Enum.any?(policies2, fn p -> p.attrs[:sub] == "bob" end)
      refute Enum.any?(policies2, fn p -> p.attrs[:sub] == "alice" end)

      # Cleanup
      AsyncTestHelper.stop_enforcer(enforcer1)
      AsyncTestHelper.stop_enforcer(enforcer2)
    end

    test "concurrent policy additions to different enforcers don't interfere" do
      # Create multiple enforcers concurrently
      enforcers =
        for i <- 1..5 do
          {AsyncTestHelper.unique_enforcer_name(), i}
        end

      # Start all enforcers
      for {name, _} <- enforcers do
        {:ok, _} = AsyncTestHelper.start_isolated_enforcer(name, @cfile)
      end

      # Add policies concurrently
      tasks =
        for {name, i} <- enforcers do
          Task.async(fn ->
            :ok =
              EnforcerServer.add_policy(name, {:p, ["user#{i}", "resource#{i}", "action#{i}"]})

            name
          end)
        end

      Task.await_many(tasks, 5000)

      # Verify each enforcer has exactly one policy with correct data
      for {name, i} <- enforcers do
        policies = EnforcerServer.list_policies(name, %{})
        assert length(policies) == 1
        policy = List.first(policies)
        assert policy.attrs[:sub] == "user#{i}"
        assert policy.attrs[:obj] == "resource#{i}"
        assert policy.attrs[:act] == "action#{i}"
      end

      # Cleanup
      for {name, _} <- enforcers do
        AsyncTestHelper.stop_enforcer(name)
      end
    end
  end

  describe "setup_isolated_enforcer/2" do
    test "sets up enforcer and returns context" do
      context = AsyncTestHelper.setup_isolated_enforcer(@cfile)

      assert %{enforcer_name: enforcer_name} = context
      assert is_binary(enforcer_name)
      assert String.starts_with?(enforcer_name, "test_enforcer_")

      # Verify enforcer is running
      assert [{pid, _}] = Registry.lookup(Casbin.EnforcerRegistry, enforcer_name)
      assert Process.alive?(pid)

      # Cleanup
      AsyncTestHelper.stop_enforcer(enforcer_name)
    end

    test "merges with existing context" do
      existing_context = [foo: :bar, baz: :qux]
      context = AsyncTestHelper.setup_isolated_enforcer(@cfile, existing_context)

      assert %{enforcer_name: _, foo: :bar, baz: :qux} = context

      # Cleanup
      AsyncTestHelper.stop_enforcer(context.enforcer_name)
    end

    test "enforcer can be used immediately after setup" do
      context = AsyncTestHelper.setup_isolated_enforcer(@cfile)

      # Should be able to use the enforcer right away
      :ok =
        EnforcerServer.add_policy(
          context.enforcer_name,
          {:p, ["alice", "data", "read"]}
        )

      policies = EnforcerServer.list_policies(context.enforcer_name, %{})
      assert length(policies) == 1

      # Cleanup
      AsyncTestHelper.stop_enforcer(context.enforcer_name)
    end
  end

  describe "async test safety demonstration" do
    # These tests run concurrently to demonstrate isolation
    test "async test 1 with isolated enforcer" do
      enforcer_name = AsyncTestHelper.unique_enforcer_name()
      {:ok, _} = AsyncTestHelper.start_isolated_enforcer(enforcer_name, @cfile)
      on_exit(fn -> AsyncTestHelper.stop_enforcer(enforcer_name) end)

      # Add some policies
      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["test1_alice", "data", "read"]})
      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["test1_bob", "data", "write"]})

      # Verify our policies are still there (not affected by other tests)
      policies = EnforcerServer.list_policies(enforcer_name, %{})
      assert length(policies) == 2
      assert Enum.any?(policies, fn p -> p.attrs[:sub] == "test1_alice" end)
      assert Enum.any?(policies, fn p -> p.attrs[:sub] == "test1_bob" end)
    end

    test "async test 2 with isolated enforcer" do
      enforcer_name = AsyncTestHelper.unique_enforcer_name()
      {:ok, _} = AsyncTestHelper.start_isolated_enforcer(enforcer_name, @cfile)
      on_exit(fn -> AsyncTestHelper.stop_enforcer(enforcer_name) end)

      # Add different policies
      :ok =
        EnforcerServer.add_policy(enforcer_name, {:p, ["test2_charlie", "resource", "execute"]})

      # Verify our policies (should not see test1's policies)
      policies = EnforcerServer.list_policies(enforcer_name, %{})
      assert length(policies) == 1
      assert Enum.any?(policies, fn p -> p.attrs[:sub] == "test2_charlie" end)
      refute Enum.any?(policies, fn p -> p.attrs[:sub] == "test1_alice" end)
      refute Enum.any?(policies, fn p -> p.attrs[:sub] == "test1_bob" end)
    end

    test "async test 3 with isolated enforcer" do
      enforcer_name = AsyncTestHelper.unique_enforcer_name()
      {:ok, _} = AsyncTestHelper.start_isolated_enforcer(enforcer_name, @cfile)
      on_exit(fn -> AsyncTestHelper.stop_enforcer(enforcer_name) end)

      # Add yet different policies
      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["test3_dave", "file", "read"]})
      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["test3_eve", "file", "write"]})
      :ok = EnforcerServer.add_policy(enforcer_name, {:p, ["test3_frank", "file", "delete"]})

      # Verify our policies (isolated from other tests)
      policies = EnforcerServer.list_policies(enforcer_name, %{})
      assert length(policies) == 3
      assert Enum.any?(policies, fn p -> p.attrs[:sub] == "test3_dave" end)
      assert Enum.any?(policies, fn p -> p.attrs[:sub] == "test3_eve" end)
      assert Enum.any?(policies, fn p -> p.attrs[:sub] == "test3_frank" end)
    end
  end
end
