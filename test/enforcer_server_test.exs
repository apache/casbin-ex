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

defmodule Casbin.EnforcerServerTest do
  use ExUnit.Case, async: true

  alias Casbin.{EnforcerServer, EnforcerSupervisor}

  @cfile "data/acl.conf" |> Path.expand(__DIR__)
  @pfile "data/acl.csv" |> Path.expand(__DIR__)

  # Every test gets its own enforcer name, so tests never share state.
  setup do
    ename = "enforcer_server_test_#{:erlang.unique_integer([:positive])}"
    on_exit(fn -> EnforcerSupervisor.stop_enforcer(ename) end)
    {:ok, ename: ename}
  end

  describe "stop_enforcer/1" do
    test "stops the running enforcer", %{ename: ename} do
      {:ok, pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)
      ref = Process.monitor(pid)

      assert EnforcerServer.running?(ename)
      assert :ok === EnforcerSupervisor.stop_enforcer(ename)

      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
      refute EnforcerServer.running?(ename)
    end

    test "is not restarted by the supervisor", %{ename: ename} do
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)
      :ok = EnforcerSupervisor.stop_enforcer(ename)

      refute ename in EnforcerSupervisor.list_enforcers()
    end

    test "drops the stored state", %{ename: ename} do
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)
      :ok = EnforcerServer.load_policies(ename, @pfile)
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "create"]) === true

      :ok = EnforcerSupervisor.stop_enforcer(ename)

      # An enforcer started under the same name is built from `@cfile`
      # again instead of inheriting the policies of the previous one.
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)
      assert EnforcerServer.list_policies(ename, %{}) === []
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "create"]) === false
    end

    test "is a no-op when no enforcer is running", %{ename: ename} do
      assert :ok === EnforcerSupervisor.stop_enforcer(ename)
      assert :ok === EnforcerSupervisor.stop_enforcer(ename)
    end
  end

  describe "crash recovery" do
    test "a restarted enforcer keeps the policies it had", %{ename: ename} do
      {:ok, pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)
      :ok = EnforcerServer.add_policy(ename, {:p, ["alice", "blog_post", "read"]})

      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

      wait_until_restarted(ename, pid)
      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "read"]) === true
    end
  end

  describe "isolation between enforcers" do
    test "policies added to one enforcer are invisible to another", %{ename: ename} do
      other = ename <> "_other"
      on_exit(fn -> EnforcerSupervisor.stop_enforcer(other) end)

      {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)
      {:ok, _pid} = EnforcerSupervisor.start_enforcer(other, @cfile)

      :ok = EnforcerServer.add_policy(ename, {:p, ["alice", "blog_post", "read"]})

      assert EnforcerServer.allow?(ename, ["alice", "blog_post", "read"]) === true
      assert EnforcerServer.allow?(other, ["alice", "blog_post", "read"]) === false
    end
  end

  # The registry drops a dead enforcer asynchronously, so waiting for *a*
  # process under `ename` can still hand back the pid that was just killed.
  # Wait for the replacement instead.
  defp wait_until_restarted(ename, old_pid, attempts \\ 50) do
    case EnforcerServer.whereis(ename) do
      pid when is_pid(pid) and pid !== old_pid ->
        :ok

      _ when attempts === 0 ->
        flunk("enforcer '#{ename}' was not restarted")

      _ ->
        Process.sleep(10)
        wait_until_restarted(ename, old_pid, attempts - 1)
    end
  end
end
