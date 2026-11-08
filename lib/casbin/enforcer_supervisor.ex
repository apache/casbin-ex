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

defmodule Casbin.EnforcerSupervisor do
  @moduledoc """
  A supervisor that starts `Enforcer` processes dynamically.
  """

  use DynamicSupervisor

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new `Enforcer` process and supervises it.

  A crashed enforcer is restarted with the state it had before the crash.
  An enforcer stopped with `stop_enforcer/1` is not restarted.
  """
  def start_enforcer(ename, cfile) do
    child_spec = %{
      id: Casbin.EnforcerServer,
      start: {Casbin.EnforcerServer, :start_link, [ename, cfile]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Stops the enforcer registered under `ename` and drops its state.

  Starting another enforcer under the same name afterwards builds a fresh
  one from its configuration file, which makes it safe to give every test
  (or tenant, or request) its own enforcer name and tear it down when done.

  Always returns `:ok`, whether or not an enforcer was running, so it can
  be called from an `on_exit/1` callback without a guard.
  """
  def stop_enforcer(ename) do
    case Casbin.EnforcerServer.whereis(ename) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end

    # `terminate/2` already drops the entry on a clean shutdown; doing it here
    # too covers the enforcer that never got there (killed on a shutdown
    # timeout) and the one that was gone before this call.
    :ets.delete(:enforcers_table, ename)
    :ok
  end

  @doc """
  Returns the names of all running enforcers.
  """
  def list_enforcers do
    Casbin.EnforcerRegistry
    |> Registry.select([{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.filter(fn {_ename, pid} -> Process.alive?(pid) end)
    |> Enum.map(fn {ename, _pid} -> ename end)
  end
end
