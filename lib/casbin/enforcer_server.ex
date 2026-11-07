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

defmodule Casbin.EnforcerServer do
  @moduledoc """
  An enforcer process that holds an `Enforcer` struct as its state.
  """

  use GenServer

  require Logger

  alias Casbin.Enforcer

  #
  # Client Public Interface
  #

  @doc """
  Loads and constructs an enforcer from the given config file `cfile`,
  and spawns a new process under the given name `ename` taking the
  (just constructed) enforcer as its initial state.
  """
  def start_link(ename, cfile) do
    GenServer.start_link(
      __MODULE__,
      {ename, cfile},
      name: via_tuple(ename)
    )
  end

  @doc """
  Returns `true` if the given request `req` is allowed under the enforcer
  whose name given by `ename`.

  Returns `false`, otherwise.

  See `Enforcer.allow?/2` for more information.
  """
  def allow?(ename, req) do
    GenServer.call(via_tuple(ename), {:allow?, req})
  end

  @doc """
  Adds a new policy rule with key given by `key` and a list of
  attribute values `attr_values` to the enforcer.

  See `Enforcer.add_policy/2` for more information.
  """
  def add_policy(ename, {key, attrs}) do
    GenServer.call(via_tuple(ename), {:add_policy, {key, attrs}})
  end

  @doc """
  Removes the matching policy rule or rules with key given by `key` and a list of
  attribute values `attr_values` to the enforcer.

  See `Enforcer.remove_policy/2` for more information.
  """
  def remove_policy(ename, {key, attrs}) do
    GenServer.call(via_tuple(ename), {:remove_policy, {key, attrs}})
  end

  @doc """
  Loads policy rules from the configured persist adapter and adds them
  to the enforcer.

  The persist adapter must be set using `set_persist_adapter/2` before
  calling this function, otherwise an error will be returned.

  ## Examples

      # Set an EctoAdapter and load policies from database
      adapter = EctoAdapter.new(MyApp.Repo)
      EnforcerServer.set_persist_adapter("my_enforcer", adapter)
      EnforcerServer.load_policies("my_enforcer")

  See `Enforcer.load_policies!/1` for more details.
  """
  def load_policies(ename) do
    GenServer.call(via_tuple(ename), {:load_policies})
  end

  @doc """
  Loads policy rules from external file given by the name `pfile` and
  adds them to the enforcer.

  See `Enforcer.load_policies!/2` for more details.
  """
  def load_policies(ename, pfile) do
    GenServer.call(via_tuple(ename), {:load_policies, pfile})
  end

  @doc """
  Loads filtered policies from the persist adapter.
  Only policies matching the filter are loaded into the enforcer.

  See `Enforcer.load_filtered_policies!/2` for more details.
  """
  def load_filtered_policies(ename, filter) do
    GenServer.call(via_tuple(ename), {:load_filtered_policies, filter})
  end

  @doc """
  Returns a list of policies in the given enforcer that match the
  given criteria.

  See `Enforcer.list_policies/2` for more details.
  """
  def list_policies(ename, criteria) do
    GenServer.call(via_tuple(ename), {:list_policies, criteria})
  end

  @doc """
  Saves the current set of policies using the configured PersistAdapter.

  See `Enforcer.save_policies/1`
  """
  def save_policies(ename) do
    GenServer.call(via_tuple(ename), {:save_policies})
  end

  @doc """
  Makes `role1` inherit from (or has role ) `role2`. The `mapping_name`
  should be one of the names given in the model configuration file under
  the `role_definition` section. For example if your role definition look
  like this:

  [role_definition]
  g = _, _

  then `mapping_name` should be the atom `:g`.

  See `Enforcer.add_mapping_policy/2` for more details.
  """
  def add_mapping_policy(ename, {mapping_name, role1, role2}) do
    GenServer.call(
      via_tuple(ename),
      {:add_mapping_policy, {mapping_name, role1, role2}}
    )
  end

  def add_mapping_policy(ename, {mapping_name, role1, role2, dom}) do
    GenServer.call(
      via_tuple(ename),
      {:add_mapping_policy, {mapping_name, role1, role2, dom}}
    )
  end

  @doc """
  Removes a mapping policy and its role inheritence. The `mapping_name`
  should be one of the names given in the model configuration file under
  the `role_definition` section. For example if your role definition look
  like this:

  [role_definition]
  g = _, _

  then `mapping_name` should be the atom `:g`.

  See `Enforcer.remove_mapping_policy/2` for more details.
  """
  def remove_mapping_policy(ename, {mapping_name, role1, role2}) do
    GenServer.call(
      via_tuple(ename),
      {:remove_mapping_policy, {mapping_name, role1, role2}}
    )
  end

  def remove_mapping_policy(ename, {mapping_name, role1, role2, dom}) do
    GenServer.call(
      via_tuple(ename),
      {:remove_mapping_policy, {mapping_name, role1, role2, dom}}
    )
  end

  @doc """
  Removes policies with attributes that match the filter fields
  starting at the index.any()

  see `Enforecer.remove_filtered_policy/4
  """
  def remove_filtered_policy(ename, req_key, idx, req) do
    GenServer.call(
      via_tuple(ename),
      {:remove_filtered_policy, req_key, idx, req}
    )
  end

  @doc """
  Loads mapping policies from the configured persist adapter and adds them
  to the enforcer.

  The persist adapter must be set using `set_persist_adapter/2` before
  calling this function, otherwise an error will be returned.

  ## Examples

      # Set an EctoAdapter and load mapping policies from database
      adapter = EctoAdapter.new(MyApp.Repo)
      EnforcerServer.set_persist_adapter("my_enforcer", adapter)
      EnforcerServer.load_mapping_policies("my_enforcer")

  See `Enforcer.load_mapping_policies!/1` for more details.
  """
  def load_mapping_policies(ename) do
    GenServer.call(via_tuple(ename), {:load_mapping_policies})
  end

  @doc """
  Loads mapping policies from a csv file and adds them to the enforcer.

  See `Enforcer.load_mapping_policies!/2` for more details.
  """
  def load_mapping_policies(ename, fname) do
    GenServer.call(via_tuple(ename), {:load_mapping_policies, fname})
  end

  @doc """
  Return a fresh enforcer.

  See `Enforcer.init/1` for more details.
  """
  def reset_configuration(ename, cfile) do
    GenServer.call(via_tuple(ename), {:reset_configuration, cfile})
  end

  @doc """
  Adds a user-defined function to the enforcer.

  See `Enforcer.add_fun/2` for more details.
  """
  def add_fun(ename, {fun_name, fun}) do
    GenServer.call(via_tuple(ename), {:add_fun, {fun_name, fun}})
  end

  @doc """
    Set the persist adapter for the enforcer. If not explicitly set the Enforcer
    will use a read-only file adapter for backwards compatibility.
  """
  def set_persist_adapter(ename, adapter) do
    GenServer.call(via_tuple(ename), {:set_persist_adapter, adapter})
  end

  @doc """
  Returns the pid of the enforcer process registered under `ename`, or
  `nil` when no enforcer is running under that name.
  """
  def whereis(ename) do
    # The registry unregisters a dead process asynchronously, so a lookup
    # right after a shutdown can still return the pid that just went away.
    case Registry.lookup(Casbin.EnforcerRegistry, ename) do
      [{pid, _}] -> if Process.alive?(pid), do: pid, else: nil
      [] -> nil
    end
  end

  @doc """
  Returns `true` if an enforcer process is running under `ename`.
  """
  def running?(ename), do: whereis(ename) !== nil

  #
  # Server Callbacks
  #

  def init({ename, cfile}) do
    # Needed so `terminate/2` runs on a supervised shutdown and can drop
    # the cached state of this enforcer.
    Process.flag(:trap_exit, true)

    case create_new_or_lookup_enforcer(ename, cfile) do
      {:error, reason} ->
        {:stop, reason}

      {:ok, enforcer} ->
        Logger.info("Spawned an enforcer process named '#{ename}'")
        {:ok, enforcer}
    end
  end

  # The ets cache exists so a crashed enforcer is restarted with the state
  # it had before the crash. A deliberate shutdown is not a crash: dropping
  # the entry keeps the state from leaking into the next enforcer that is
  # started under the same name.
  def terminate(reason, _enforcer) do
    if graceful_shutdown?(reason) do
      case self_name() do
        nil -> :ok
        ename -> :ets.delete(:enforcers_table, ename)
      end
    end

    :ok
  end

  def handle_call({:allow?, req}, _from, enforcer) do
    allowed = enforcer |> Enforcer.allow?(req)
    {:reply, allowed, enforcer}
  end

  def handle_call({:add_policy, {key, attrs}}, _from, enforcer) do
    case Enforcer.add_policy(enforcer, {key, attrs}) do
      {:error, reason} ->
        {:reply, {:error, reason}, enforcer}

      {:ok, new_enforcer} ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}

      new_enforcer ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}
    end
  end

  def handle_call({:remove_policy, {key, attrs}}, _from, enforcer) do
    case Enforcer.remove_policy(enforcer, {key, attrs}) do
      {:error, reason} ->
        {:reply, {:error, reason}, enforcer}

      {:ok, new_enforcer} ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}

      new_enforcer ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}
    end
  end

  def handle_call({:load_policies}, _from, enforcer) do
    new_enforcer = enforcer |> Enforcer.load_policies!()
    :ets.insert(:enforcers_table, {self_name(), new_enforcer})
    {:reply, :ok, new_enforcer}
  end

  def handle_call({:load_policies, pfile}, _from, enforcer) do
    new_enforcer = enforcer |> Enforcer.load_policies!(pfile)
    :ets.insert(:enforcers_table, {self_name(), new_enforcer})
    {:reply, :ok, new_enforcer}
  end

  def handle_call({:load_filtered_policies, filter}, _from, enforcer) do
    new_enforcer = enforcer |> Enforcer.load_filtered_policies!(filter)
    :ets.insert(:enforcers_table, {self_name(), new_enforcer})
    {:reply, :ok, new_enforcer}
  end

  def handle_call({:list_policies, criteria}, _from, enforcer) do
    policies = enforcer |> Enforcer.list_policies(criteria)
    {:reply, policies, enforcer}
  end

  def handle_call({:save_policies}, _from, enforcer) do
    new_enforcer = enforcer |> Enforcer.save_policies()
    :ets.insert(:enforcers_table, {self_name(), new_enforcer})
    {:reply, :ok, new_enforcer}
  end

  def handle_call({:add_mapping_policy, mapping}, _from, enforcer) do
    case Enforcer.add_mapping_policy(enforcer, mapping) do
      {:error, reason} ->
        {:reply, {:error, reason}, enforcer}

      {:ok, new_enforcer} ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}

      new_enforcer ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}
    end
  end

  def handle_call({:load_mapping_policies}, _from, enforcer) do
    new_enforcer = enforcer |> Enforcer.load_mapping_policies!()
    :ets.insert(:enforcers_table, {self_name(), new_enforcer})
    {:reply, :ok, new_enforcer}
  end

  def handle_call({:load_mapping_policies, fname}, _from, enforcer) do
    new_enforcer = enforcer |> Enforcer.load_mapping_policies!(fname)
    :ets.insert(:enforcers_table, {self_name(), new_enforcer})
    {:reply, :ok, new_enforcer}
  end

  def handle_call({:remove_mapping_policy, mapping}, _from, enforcer) do
    case Enforcer.remove_mapping_policy(enforcer, mapping) do
      {:error, reason} ->
        {:reply, {:error, reason}, enforcer}

      {:ok, new_enforcer} ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}

      new_enforcer ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}
    end
  end

  def handle_call({:remove_filtered_policy, key, idx, attrs}, _from, enforcer) do
    case Enforcer.remove_filtered_policy(enforcer, key, idx, attrs) do
      {:error, reason} ->
        {:reply, {:error, reason}, enforcer}

      new_enforcer ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}
    end
  end

  def handle_call({:reset_configuration, cfile}, _from, enforcer) do
    case Enforcer.init(cfile) do
      {:error, reason} ->
        {:reply, {:error, reason}, enforcer}

      {:ok, new_enforcer} ->
        :ets.insert(:enforcers_table, {self_name(), new_enforcer})
        {:reply, :ok, new_enforcer}
    end
  end

  def handle_call({:add_fun, {fun_name, fun}}, _from, enforcer) do
    new_enforcer = enforcer |> Enforcer.add_fun({fun_name, fun})
    :ets.insert(:enforcers_table, {self_name(), new_enforcer})
    {:reply, :ok, new_enforcer}
  end

  def handle_call({:set_persist_adapter, adapter}, _from, enforcer) do
    new_enforcer = Enforcer.set_persist_adapter(enforcer, adapter)
    :ets.insert(:enforcers_table, {self_name(), new_enforcer})
    {:reply, :ok, new_enforcer}
  end

  #
  # Helpers
  #

  # Returns a tuple used to register and lookup an enforcer process
  # by name
  defp via_tuple(ename) do
    {:via, Registry, {Casbin.EnforcerRegistry, ename}}
  end

  # Returns the name of `self`.
  defp self_name do
    Registry.keys(Casbin.EnforcerRegistry, self()) |> List.first()
  end

  # Returns `true` when the process was stopped on purpose rather than
  # having crashed.
  defp graceful_shutdown?(:normal), do: true
  defp graceful_shutdown?(:shutdown), do: true
  defp graceful_shutdown?({:shutdown, _reason}), do: true
  defp graceful_shutdown?(_reason), do: false

  # Creates a new enforcer or lookups existing one in the ets table.
  defp create_new_or_lookup_enforcer(ename, cfile) do
    case :ets.lookup(:enforcers_table, ename) do
      [] ->
        case Enforcer.init(cfile) do
          {:error, reason} ->
            {:error, reason}

          {:ok, enforcer} ->
            :ets.insert(:enforcers_table, {ename, enforcer})
            {:ok, enforcer}
        end

      [{^ename, enforcer}] ->
        {:ok, enforcer}
    end
  end
end
