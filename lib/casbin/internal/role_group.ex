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

defmodule Casbin.Internal.RoleGroup do
  @moduledoc """
  This module defines a structure to manage the roles and their inheritances
  in the (H)RBAC model.

  The `RoleGroup` struct is structured like so:
  - An atom to represent the name of the group (`name`).
  - A directed graph to manage the roles and their inheritances (`role_graph`)
  """

  defstruct name: nil, role_graph: nil

  alias Casbin.Internal.Digraph

  @type role_type() :: term()

  @type t() :: %__MODULE__{
          name: atom(),
          role_graph: Digraph.t()
        }

  @doc """
  Creates a new role group
  """
  @spec new(atom()) :: t()
  def new(a), do: %__MODULE__{name: a, role_graph: Digraph.new()}

  @doc """
  Returns the list of all roles in the given role group.

  ## Examples

      iex> g = RoleGroup.new(:g) |> RoleGroup.add_roles(["admin", "member"])
      ...> RoleGroup.list_roles(g) -- ["admin", "member"]
      []
  """
  @spec list_roles(t()) :: [role_type()]
  def list_roles(%__MODULE__{role_graph: g}) do
    g |> Digraph.list_vertices()
  end

  @doc """
  Adds a new role to the group. If the given role is already present, this
  is a no-op.

  ## Examples

      iex> g = RoleGroup.new(:g) |> RoleGroup.add_role("admin")
      ...> g = g |> RoleGroup.add_role("admin")
      ...> g |> RoleGroup.list_roles()
      ["admin"]
  """
  @spec add_role(t(), role_type()) :: t()
  def add_role(%__MODULE__{role_graph: g} = group, new_role) do
    %{group | role_graph: g |> Digraph.add_vertex(new_role)}
  end

  @doc """
  Like `add_role/1`, but takes a list of roles.

  ## Examples

      iex> g = RoleGroup.new(:g) |> RoleGroup.add_roles(["admin", "member"])
      ...> RoleGroup.list_roles(g) -- ["admin", "member"]
      []
  """
  @spec add_roles(t(), [role_type()]) :: t()
  def add_roles(%__MODULE__{role_graph: g} = group, roles)
      when is_list(roles) do
    %{group | role_graph: g |> Digraph.add_vertices(roles)}
  end

  @doc """
  Makes role `r1` inherits from role `r2`. If any of the two roles `r1`,
  `r2` is not present in the group, it'll be created and new inheritance
  will be added.

  If role `r1` already inherits from role `r2`, this is a no-op.

  ## Examples

      iex> pair = {"admin", "member"}
      ...> g = RoleGroup.new(:g) |> RoleGroup.add_inheritance(pair)
      ...> true = g |> RoleGroup.inherit_from?("admin", "member")
      ...> g |> RoleGroup.inherit_from?("member", "admin")
      false
  """
  @spec add_inheritance(t(), {role_type(), role_type()}) :: t()
  def add_inheritance(%__MODULE__{role_graph: g} = group, {r1, r2}) do
    %{group | role_graph: g |> Digraph.add_edge({r1, r2})}
  end

  @doc """
  Removes the inheritance connection between roles

  ## Examples

      iex> pair = {"admin", "member"}
      ...> g = RoleGroup.new(:g) |> RoleGroup.add_inheritance(pair)
      ...> true = g |> RoleGroup.inherit_from?("admin", "member")
      ...> false = g |> RoleGroup.inherit_from?("member", "admin")
      ...> g = g |> RoleGroup.remove_inheritance(pair)
      ...> false = g |> RoleGroup.inherit_from?("admin", "member")
  """
  @spec remove_inheritance(t(), {role_type(), role_type()}) :: t()
  def remove_inheritance(%__MODULE__{role_graph: g} = group, {r1, r2}) do
    %{group | role_graph: g |> Digraph.remove_edge({r1, r2})}
  end

  @doc """
  Returns `true` if role `r1` inherits from role `r2`.
  Returns `false`, otherwise.

  NOTE: role inheritance is transitive, meaning if `A` inherits from `B`,
  `B` inherits from `C`, then `A` inherits from `C`.

  ## Examples

      iex> g = RoleGroup.new(:g)
      ...> g = g |> RoleGroup.add_inheritance({"author", "reader"})
      ...> g = g |> RoleGroup.add_inheritance({"admin", "author"})
      ...> true = g |> RoleGroup.inherit_from?("author","author")
      ...> true = g |> RoleGroup.inherit_from?("author", "reader")
      ...> false = g |> RoleGroup.inherit_from?("reader", "author")
      ...> true = g |> RoleGroup.inherit_from?("admin", "author")
      ...> false = g |> RoleGroup.inherit_from?("author", "admin")
      ...> false = g |> RoleGroup.inherit_from?("reader", "admin")
      ...> g |> RoleGroup.inherit_from?("admin", "reader")
      true
  """
  @spec inherit_from?(t(), role_type(), role_type()) :: boolean()
  def inherit_from?(%__MODULE__{role_graph: g}, r1, r2) do
    r1 === r2 || g |> Digraph.has_path?(r1, r2)
  end

  @doc """
  Returns a function used when evaluating a matcher program.

  ## Examples

      iex> g = RoleGroup.new(:g)
      ...> g = g |> RoleGroup.add_inheritance({"admin", "member"})
      ...> f = g |> RoleGroup.stub_2
      ...> false = f.("member", "admin")
      ...> false = f.(1, 2)
      ...> f.("admin", "member")
      true
      ...> g = g |> RoleGroup.add_inheritance({{"admin", "domain"}, {"member", "domain"}})
      ...> f = g |> RoleGroup.stub_3
      ...> false = f.("member", "admin", "domain")
      ...> f.("admin", "member", "domain")
      true
  """
  def stub_2(%__MODULE__{} = group) do
    fn
      arg1, arg2 ->
        group |> inherit_from?(arg1, arg2)
    end
  end

  def stub_3(%__MODULE__{} = group) do
    fn
      arg1, arg2, arg3 ->
        group |> inherit_from?({arg1, arg3}, {arg2, arg3})
    end
  end
end
