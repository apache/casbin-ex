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

defmodule Casbin.Persist.ReadonlyFileAdapter do
  @moduledoc """
  A read-only file adapter for loading policies from files.
  """
  alias Casbin.Persist.PersistAdapter

  defstruct policy_file: nil

  def new do
    %__MODULE__{policy_file: nil}
  end

  def new(pfile) do
    %__MODULE__{policy_file: pfile}
  end

  defimpl PersistAdapter, for: Casbin.Persist.ReadonlyFileAdapter do
    # Position of each `vN` filter key within a rule's value list.
    @value_indexes %{v0: 0, v1: 1, v2: 2, v3: 3, v4: 4, v5: 5, v6: 6}

    def load_policies(%Casbin.Persist.ReadonlyFileAdapter{policy_file: nil}) do
      {:ok, []}
    end

    def load_policies(adapter) do
      policies =
        adapter.policy_file
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.map(&String.split(&1, ~r{,\s*}))

      {:ok, policies}
    end

    def load_policies(_adapter, pfile) do
      policies =
        File.read!(pfile)
        |> String.split("\n", trim: true)
        |> Enum.map(&String.split(&1, ~r{,\s*}))

      {:ok, policies}
    end

    @doc """
    Loads filtered policies from a file.

    The filter is applied in-memory after loading all policies.
    Note: For file-based adapters, filtering does not improve performance
    as all data must be read from disk anyway.

    ## Examples

        filter = %{ptype: "p", v3: "org:tenant_123"}
        PersistAdapter.load_filtered_policy(adapter, filter)
    """
    def load_filtered_policy(%Casbin.Persist.ReadonlyFileAdapter{policy_file: nil}, _filter) do
      {:ok, []}
    end

    def load_filtered_policy(adapter, filter) when is_map(filter) do
      case load_policies(adapter) do
        {:ok, policies} ->
          filtered_policies = apply_filter(policies, filter)
          {:ok, filtered_policies}

        error ->
          error
      end
    end

    defp apply_filter(policies, filter) do
      Enum.filter(policies, fn policy ->
        matches_filter?(policy, filter)
      end)
    end

    defp matches_filter?(policy, filter) do
      Enum.all?(filter, fn {key, value} ->
        policy_value = get_policy_value(policy, key)
        matches_value?(policy_value, value)
      end)
    end

    defp get_policy_value([ptype | _values], :ptype), do: ptype

    defp get_policy_value([_ptype | values], key) do
      case Map.fetch(@value_indexes, key) do
        {:ok, index} -> Enum.at(values, index)
        :error -> nil
      end
    end

    defp matches_value?(policy_value, filter_value) when is_list(filter_value) do
      policy_value in filter_value
    end

    defp matches_value?(policy_value, filter_value) do
      policy_value == filter_value
    end

    def add_policy(adapter, _policy) do
      {:ok, adapter}
    end

    def save_policies(adapter, _policies) do
      {:ok, adapter}
    end

    def remove_policy(adapter, _policy) do
      {:ok, adapter}
    end

    def remove_filtered_policy(adapter, _key, _idx, _attrs) do
      {:ok, adapter}
    end
  end
end
