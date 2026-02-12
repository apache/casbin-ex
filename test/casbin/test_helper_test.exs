defmodule Casbin.TestHelperTest do
  use ExUnit.Case, async: true
  
  alias Casbin.{EnforcerSupervisor, EnforcerServer, TestHelper}

  @cfile "../../data/acl.conf" |> Path.expand(__DIR__)
  @pfile "../../data/acl.csv" |> Path.expand(__DIR__)

  setup do
    # Clean ETS state before each test
    :ets.delete_all_objects(:enforcers_table)
    :ok
  end

  describe "unique_enforcer_name/1" do
    test "generates unique names" do
      name1 = TestHelper.unique_enforcer_name("test")
      name2 = TestHelper.unique_enforcer_name("test")
      
      assert name1 != name2
      assert String.contains?(name1, "test")
      assert String.contains?(name2, "test")
    end

    test "uses default prefix when not provided" do
      name = TestHelper.unique_enforcer_name()
      assert String.contains?(name, "test")
    end

    test "includes custom prefix" do
      name = TestHelper.unique_enforcer_name("my_module")
      assert String.contains?(name, "my_module")
    end

    test "generates names suitable for concurrent tests" do
      # Simulate multiple tests running in parallel
      names = 
        1..100
        |> Enum.map(fn _ -> 
          Task.async(fn -> TestHelper.unique_enforcer_name("concurrent") end)
        end)
        |> Enum.map(&Task.await/1)

      # All names should be unique
      assert length(Enum.uniq(names)) == 100
    end
  end

  describe "cleanup_enforcer/1" do
    test "removes enforcer from ETS table" do
      ename = TestHelper.unique_enforcer_name("cleanup_test")
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)

      # Verify it's in the ETS table
      assert :ets.lookup(:enforcers_table, ename) != []

      # Clean up
      TestHelper.cleanup_enforcer(ename)

      # Verify it's removed
      assert :ets.lookup(:enforcers_table, ename) == []
    end

    test "stops the enforcer process" do
      ename = TestHelper.unique_enforcer_name("cleanup_process_test")
      {:ok, pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)

      assert Process.alive?(pid)

      # Clean up
      TestHelper.cleanup_enforcer(ename)

      # Give it a moment to stop
      Process.sleep(10)

      # Verify process is no longer registered
      assert Registry.lookup(Casbin.EnforcerRegistry, ename) == []
    end

    test "handles non-existent enforcer gracefully" do
      # Should not raise an error
      assert :ok = TestHelper.cleanup_enforcer("non_existent_enforcer")
    end
  end

  describe "create_test_enforcer/2" do
    test "creates enforcer and returns unique name" do
      assert {:ok, ename} = TestHelper.create_test_enforcer("create_test", @cfile)
      
      assert String.contains?(ename, "create_test")
      
      # Verify enforcer works
      :ok = EnforcerServer.load_policies(ename, @pfile)
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "read"]) == true
    end

    test "uses default prefix when not provided" do
      assert {:ok, ename} = TestHelper.create_test_enforcer(@cfile)
      assert String.contains?(ename, "test")
    end

    test "returns error for invalid config file" do
      assert {:error, _reason} = TestHelper.create_test_enforcer("test", "/invalid/path.conf")
    end
  end

  describe "async test isolation" do
    # These tests run in parallel to verify isolation
    test "test 1 - isolated enforcer" do
      ename = TestHelper.unique_enforcer_name("async_1")
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)
      on_exit(fn -> TestHelper.cleanup_enforcer(ename) end)

      :ok = EnforcerServer.add_policy(ename, {:p, ["user1", "data1", "read"]})
      
      # Verify policy exists in this enforcer
      assert EnforcerServer.allow?(ename, ["user1", "data1", "read"]) == true
      
      # Should not affect other enforcers
      policies = EnforcerServer.list_policies(ename, %{sub: "user1"})
      assert length(policies) == 1
    end

    test "test 2 - isolated enforcer" do
      ename = TestHelper.unique_enforcer_name("async_2")
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)
      on_exit(fn -> TestHelper.cleanup_enforcer(ename) end)

      :ok = EnforcerServer.add_policy(ename, {:p, ["user2", "data2", "write"]})
      
      # Verify policy exists in this enforcer
      assert EnforcerServer.allow?(ename, ["user2", "data2", "write"]) == true
      
      # Should not see user1's policies
      policies = EnforcerServer.list_policies(ename, %{sub: "user1"})
      assert length(policies) == 0
    end

    test "test 3 - isolated enforcer" do
      ename = TestHelper.unique_enforcer_name("async_3")
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)
      on_exit(fn -> TestHelper.cleanup_enforcer(ename) end)

      :ok = EnforcerServer.add_policy(ename, {:p, ["user3", "data3", "delete"]})
      
      # Verify policy exists in this enforcer
      assert EnforcerServer.allow?(ename, ["user3", "data3", "delete"]) == true
      
      # Should not see other users' policies
      assert EnforcerServer.list_policies(ename, %{sub: "user1"}) == []
      assert EnforcerServer.list_policies(ename, %{sub: "user2"}) == []
    end
  end

  describe "stress test with many concurrent enforcers" do
    test "handles many parallel enforcers" do
      # Create and use multiple enforcers concurrently
      tasks = 
        1..50
        |> Enum.map(fn i ->
          Task.async(fn ->
            ename = TestHelper.unique_enforcer_name("stress_#{i}")
            {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)
            
            # Add a unique policy
            :ok = EnforcerServer.add_policy(ename, {:p, ["user#{i}", "resource#{i}", "read"]})
            
            # Verify it works
            result = EnforcerServer.allow?(ename, ["user#{i}", "resource#{i}", "read"])
            
            # Clean up
            TestHelper.cleanup_enforcer(ename)
            
            {ename, result}
          end)
        end)
        |> Enum.map(&Task.await(&1, 10_000))

      # All should succeed
      assert Enum.all?(tasks, fn {_name, result} -> result == true end)
      
      # All names should be unique
      names = Enum.map(tasks, fn {name, _result} -> name end)
      assert length(Enum.uniq(names)) == 50
    end
  end
end
