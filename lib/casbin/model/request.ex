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

defmodule Casbin.Model.Request do
  @moduledoc """
  This module defines a structure to represent a request.
  A request has two parts:

  - A key, typically the atom `:r`.
  - A list of key-value pairs, in which `key` is the name of one of
  the attributes of the request, and `value` is the value of such
  attribute.
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
  Creates a new request based on the given `key` and a list of attributes.
  """
  def new(key, attrs) do
    %__MODULE__{key: key, attrs: attrs}
  end
end
