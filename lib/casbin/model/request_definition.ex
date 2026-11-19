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

defmodule Casbin.Model.RequestDefinition do
  @moduledoc """
  This module defines a structure to represent a request definition in
  a model. A request definition has two parts:

    - A key, typically the atom `:r`.
    - And a list of attributes in which each attibute is an atom.
  """

  defstruct key: nil, attrs: []

  @type key() :: atom()
  @type attr() :: atom()
  @type attr_value() :: String.t() | number()
  @type t() :: %__MODULE__{
          key: key(),
          attrs: [attr()]
        }

  alias Casbin.Model.Request

  @doc """
  Creates a request definition based on the given `key` and a comma
  separated string of attributes.

  ## Examples

      iex> rd = RequestDefinition.new(:r, "sub, obj, act")
      ...> %RequestDefinition{key: :r, attrs: attrs} = rd
      ...> attrs
      [:sub, :obj, :act]
  """
  @spec new(key(), String.t()) :: t()
  def new(key, attr_str) when is_atom(key) and is_binary(attr_str) do
    attrs =
      attr_str
      |> String.trim()
      |> String.split(~r{,\s*}, trim: true)
      |> Enum.map(&String.to_atom/1)
      |> Enum.uniq()

    %__MODULE__{key: key, attrs: attrs}
  end

  @doc """
  Creates a new request based on the given request definition and a list
  of values for attributes.

  ## Examples

      iex> rd = RequestDefinition.new(:r, "sub, obj, act")
      ...> attr_values = ["alice", "data1", "read"]
      ...> {:ok, req} = rd |> RequestDefinition.create_request(attr_values)
      ...> %Request{key: :r, attrs: attrs} = req
      ...> attrs
      [sub: "alice", obj: "data1", act: "read"]

      iex> rd = RequestDefinition.new(:r, "sub, obj, act")
      ...> values = ["alice", "data1"]
      ...> {:error, reason} = rd |> RequestDefinition.create_request(values)
      ...> reason
      "invalid request"
  """
  @spec create_request(t(), [attr_value()]) ::
          {:ok, Request.t()}
          | {:error, String.t()}
  def create_request(%__MODULE__{} = rd, attr_values)
      when is_list(attr_values) do
    case valid_request?(rd, attr_values) do
      false ->
        {:error, "invalid request"}

      true ->
        %{key: key, attrs: attrs} = rd
        {:ok, Request.new(key, Enum.zip(attrs, attr_values))}
    end
  end

  defp valid_request?(%__MODULE__{attrs: attrs}, attr_values) do
    length(attrs) === length(attr_values) &&
      Enum.all?(attr_values, &valid_attr_value_type?/1)
  end

  defp valid_attr_value_type?(value) do
    is_binary(value) || is_number(value) || is_map(value)
  end
end
