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

defmodule Casbin.Model.PolicyDefinition do
  @moduledoc """
  This module defines the structure to represent a policy definition in
  a model. A policy definition has two parts:

    - A key, typically the atom `:p`.
    - And a list of attributes in which each attibute is an atom.
    - The atom `:eft` is the common attribute of all policy definitions.
  """

  defstruct key: nil, attrs: []

  @type key() :: atom()
  @type attr() :: atom()
  @type attr_value() :: String.t() | number()
  @type t() :: %__MODULE__{
          key: key(),
          attrs: [attr()]
        }

  alias Casbin.Model.Policy

  @doc """
  Creates a new policy definition based on the given `key` and a comma
  separated string of attributes.

  ## Examples

      iex> PolicyDefinition.new(:p, "sub, obj, act")
      %PolicyDefinition{key: :p, attrs: [:sub, :obj, :act, :eft]}

      iex> PolicyDefinition.new(:p, "  sub, obj, act, eft ")
      %PolicyDefinition{key: :p, attrs: [:sub, :obj, :act, :eft]}

      iex> PolicyDefinition.new(:p2, "sub, obj, act, act")
      %PolicyDefinition{key: :p2, attrs: [:sub, :obj, :act, :eft]}
  """
  @spec new(key(), String.t()) :: t()
  @reserved_attr :eft
  def new(key, attr_str) when is_atom(key) and is_binary(attr_str) do
    attrs =
      attr_str
      |> String.trim()
      |> String.split(~r{,\s*}, trim: true)
      |> Enum.map(&String.to_atom/1)
      |> Enum.uniq()
      |> Enum.filter(fn a -> a != @reserved_attr end)

    %__MODULE__{key: key, attrs: attrs ++ [@reserved_attr]}
  end

  @doc """
  Creates a new policy based on the given policy definition `pd`,
  and the given list of values for attributes.

  The value of the `eft` attribute must be either `"allow"` or `"deny"`.
  If the value of the `eft` attribute is not provided, it'll be
  defaulted to `"allow"`.

  ## Examples

      iex> pd = PolicyDefinition.new(:p, "sub, obj, act")
      ...> values = ["alice", "data1", "read"]
      ...> {:ok, p} = pd |> PolicyDefinition.create_policy(values)
      ...> %Policy{key: :p, attrs: attrs} = p
      ...> attrs
      [sub: "alice", obj: "data1", act: "read", eft: "allow"]

      iex> pd = PolicyDefinition.new(:p, "sub, obj, act")
      ...> values = ["alice", "data1", "read", "allow"]
      ...> {:ok, p} = pd |> PolicyDefinition.create_policy(values)
      ...> %Policy{key: :p, attrs: attrs} = p
      ...> attrs
      [sub: "alice", obj: "data1", act: "read", eft: "allow"]

      iex> pd = PolicyDefinition.new(:p, "sub, obj, act")
      ...> values = ["alice", "data1", "read", "deny"]
      ...> {:ok, p} = pd |> PolicyDefinition.create_policy(values)
      ...> %Policy{key: :p, attrs: attrs} = p
      ...> attrs
      [sub: "alice", obj: "data1", act: "read", eft: "deny"]

      iex> pd = PolicyDefinition.new(:p, "sub, obj, act")
      ...> values = ["alice", "data1"]
      ...> {:error, r} = pd |> PolicyDefinition.create_policy(values)
      ...> r
      "invalid policy"

      iex> pd = PolicyDefinition.new(:p, "sub, obj, act")
      ...> values = ["alice", "data1", "read", "foo"]
      ...> {:error, r} = pd |> PolicyDefinition.create_policy(values)
      ...> r
      "invalid value for the `eft` attribute: `foo`"

      iex> pd = PolicyDefinition.new(:p, "sub, obj, act")
      ...> values = ["alice", "data1", :read]
      ...> {:error, r} = pd |> PolicyDefinition.create_policy(values)
      ...> r
      "invalid attribute value type"
  """
  @spec create_policy(t(), [attr_value()]) ::
          {:ok, Policy.t()}
          | {:error, String.t()}
  def create_policy(%__MODULE__{} = pd, values) when is_list(values) do
    case validate_policy(pd, values) do
      {:error, reason} ->
        {:error, reason}

      {:ok, attrs} ->
        {:ok, Policy.new(pd.key, attrs)}
    end
  end

  # Validate the new policy against the given policy definition.
  @valid_eft ["allow", "deny"]
  defp validate_policy(%__MODULE__{attrs: attrs}, values) do
    attrs_len = length(attrs)
    values_len = length(values)

    cond do
      values_len != attrs_len && values_len != attrs_len - 1 ->
        {:error, "invalid policy"}

      values_len == attrs_len && List.last(values) not in @valid_eft ->
        {
          :error,
          "invalid value for the `eft` attribute: `#{List.last(values)}`"
        }

      !Enum.all?(values, &valid_attr_value_type?/1) ->
        {:error, "invalid attribute value type"}

      values_len == attrs_len ->
        {:ok, Enum.zip(attrs, values)}

      true ->
        {:ok, Enum.zip(attrs, values ++ ["allow"])}
    end
  end

  defp valid_attr_value_type?(value) do
    is_binary(value) || is_number(value)
  end
end
