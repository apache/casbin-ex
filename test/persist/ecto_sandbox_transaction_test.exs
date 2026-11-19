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

defmodule Casbin.Persist.EctoSandboxTransactionTest do
  @moduledoc """
  This test module demonstrates how to use Casbin with Ecto.Adapters.SQL.Sandbox
  when wrapping operations in transactions.

  These tests are marked as skip by default because they require a real database
  connection. To run them, set up a test database and remove the @moduletag :skip.
  """
  use ExUnit.Case, async: false

  @moduletag :skip

  alias Casbin.Enforcer
  alias Casbin.EnforcerServer
  alias Casbin.Persist.EctoAdapter

  # NOTE: Replace MyApp.Repo with your actual Repo module
  # @repo MyApp.Repo
  # @enforcer_name "test_enforcer"

  setup do
    # IMPORTANT: This setup demonstrates the correct pattern for using
    # Casbin with SQL.Sandbox when operations are wrapped in transactions

    # Step 1: Check out a connection from the sandbox
    # :ok = Ecto.Adapters.SQL.Sandbox.checkout(@repo)

    # Step 2: Enable shared mode - this allows the EnforcerServer process
    # to access the connection checked out by the test process
    # Ecto.Adapters.SQL.Sandbox.mode(@repo, {:shared, self()})

    # Step 3: Start an enforcer with the EctoAdapter
    # cfile = "../data/rbac.conf" |> Path.expand(__DIR__)
    # {:ok, _pid} = EnforcerServer.start_link(@enforcer_name, cfile)
    # adapter = EctoAdapter.new(@repo)
    # :ok = EnforcerServer.set_persist_adapter(@enforcer_name, adapter)

    # Step 4: Allow the EnforcerServer to access the connection
    # case Registry.lookup(Casbin.EnforcerRegistry, @enforcer_name) do
    #   [{pid, _}] -> Ecto.Adapters.SQL.Sandbox.allow(@repo, self(), pid)
    #   [] -> :ok
    # end

    # on_exit(fn ->
    #   if Process.whereis(@enforcer_name), do: GenServer.stop(@enforcer_name)
    # end)

    :ok
  end

  @tag :skip
  test "add policy within a transaction succeeds" do
    # This test demonstrates adding Casbin policies within a database transaction.
    # With shared mode enabled in setup, this works correctly.

    # result = @repo.transaction(fn ->
    #   # Add multiple policies atomically
    #   :ok = EnforcerServer.add_policy(@enforcer_name, {:p, ["alice", "data1", "read"]})
    #   :ok = EnforcerServer.add_policy(@enforcer_name, {:p, ["alice", "data1", "write"]})
    #
    #   {:ok, :success}
    # end)
    #
    # assert {:ok, :success} = result
    #
    # # Verify policies were added
    # policies = EnforcerServer.list_policies(@enforcer_name, %{sub: "alice"})
    # assert length(policies) == 2
  end

  @tag :skip
  test "transaction rollback also rolls back Casbin policies" do
    # This test demonstrates that Casbin policy changes are rolled back
    # when the containing transaction is rolled back.

    # result = @repo.transaction(fn ->
    #   # Add a policy
    #   :ok = EnforcerServer.add_policy(@enforcer_name, {:p, ["bob", "data2", "read"]})
    #
    #   # Simulate a failure that causes rollback
    #   @repo.rollback(:simulated_error)
    # end)
    #
    # assert {:error, :simulated_error} = result
    #
    # # Verify the policy was NOT persisted
    # policies = EnforcerServer.list_policies(@enforcer_name, %{sub: "bob"})
    # assert policies == []
  end

  @tag :skip
  test "mixed database and casbin operations in transaction" do
    # This test demonstrates using both regular database operations
    # and Casbin operations within the same transaction.

    # result = @repo.transaction(fn ->
    #   # Insert a user record (example - replace with your schema)
    #   # {:ok, user} = @repo.insert(%User{name: "charlie"})
    #
    #   # Add corresponding Casbin policies
    #   :ok = EnforcerServer.add_policy(@enforcer_name, {:p, ["charlie", "data3", "read"]})
    #   :ok = EnforcerServer.add_policy(@enforcer_name, {:p, ["charlie", "data3", "write"]})
    #
    #   {:ok, :complete}
    # end)
    #
    # assert {:ok, :complete} = result
  end

  @tag :skip
  test "without shared mode, transaction operations fail" do
    # This test demonstrates what happens WITHOUT shared mode.
    # Uncomment to see the error (but don't check this in as passing).

    # First, disable shared mode
    # Ecto.Adapters.SQL.Sandbox.mode(@repo, :manual)
    #
    # # Now try to add a policy in a transaction - this will fail
    # assert_raise DBConnection.ConnectionError, fn ->
    #   @repo.transaction(fn ->
    #     EnforcerServer.add_policy(@enforcer_name, {:p, ["dave", "data4", "read"]})
    #   end)
    # end
  end
end
