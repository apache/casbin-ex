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

defmodule Casbin.Model.Policy do
  @moduledoc """
  This module defines a structure to represent a policy.
  A policy has two parts:

    - A key, typically the atom `:p`.
    - A list of key-value pairs, in which `key` is the name of one of
      the attributes of the policy, and `value` is the value of such
      attribute.
    - All policies have one common attribute named `:eft` and its value
      can only be either `"allow"` or `"deny"`.

  NOTE:
  """

  defstruct key: nil, attrs: []

  @type key() :: atom()
  @type attr() :: atom()
  @type attr_value() :: String.t() | number()
  @type t() :: %__MODULE__{
          key: key(),
          attrs: [{attr(), attr_value()}]
        }

  @doc """
  Create new policy based on the given `key` and the list of
  attributes `attrs`.
  """
  def new(key, attrs) when is_atom(key) and is_list(attrs) do
    %__MODULE__{key: key, attrs: attrs}
  end

  @doc """
  Returns `true` if the policy is of type `allow`.
  Returns `false` otherwise.
  """
  def allow?(%__MODULE__{attrs: attrs}), do: attrs[:eft] === "allow"
end
