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

defmodule Casbin.Internal.Digraph do
  @moduledoc """
  This module defines a simple directed graph structure to model the role
  inheritance in the (H)RBAC ( Hierarchical Role Based Access Control)
  system.

  So, if `A` has role `B` (a.ka `A` inherits from `B`) then `A` and `B`
  are two vertices in our graph, and there is a (directed) edge pointing
  from `A` to `B`.

  If `A` has role `B`, `B` has role `C`, then `A` has role `C`
  (or in graph terms there is a path from `A` to `C`).

  The Digraph struct is structured like so:

  - A map from vertex id to vertices (`vertices`)
  - A map from vertex id to its adjacent vertices (`adj`). A vertex
  `w` that is adjacent to vertex `v` iff there is an edge pointing from
  `v` to `w`.
  """

  defstruct vertices: %{}, adj: %{}

  @type vertex_id() :: non_neg_integer()
  @type vertex() :: term()
  @type t() :: %__MODULE__{
          vertices: %{vertex_id() => vertex()},
          adj: %{vertex_id() => MapSet.t()}
        }

  @doc """
  Creates a new empty digraph.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Returns a list of all the vertices in the digraph. Since the underlying
  data structure is a map, the order of vertices returned by
  `list_vertices/1` doesn't neccessarily the same as the order they got
  inserted in.

  ## Examples

      iex> g = Digraph.new |> Digraph.add_vertices([:a, :b])
      ...> Digraph.list_vertices(g) -- [:a, :b]
      []
  """
  @spec list_vertices(t()) :: [vertex()]
  def list_vertices(%__MODULE__{vertices: vertices}) do
    Map.values(vertices)
  end

  @doc """
  Adds a new vertex to the digraph. If the vertex is already present in the
  digraph, then this is a no-op.

  ## Examples

      iex> g = Digraph.new |> Digraph.add_vertex(:a)
      ...> g = g |> Digraph.add_vertex(:a)
      ...> Digraph.list_vertices(g)
      [:a]
  """
  @spec add_vertex(t(), vertex()) :: t()
  def add_vertex(%__MODULE__{vertices: vertices, adj: adj} = g, v) do
    id = hash(v)

    case Map.get(vertices, id) do
      nil ->
        %{g | vertices: Map.put(vertices, id, v), adj: Map.put(adj, id, MapSet.new())}

      _ ->
        g
    end
  end

  @doc """
  Like `add_vertex/2`, but takes a list of vertices to add to the digraph.

  ## Examples

      iex> g = Digraph.new |> Digraph.add_vertices([:a, :b, :a])
      ...> Digraph.list_vertices(g) -- [:a, :b]
      []
  """
  @spec add_vertices(t(), [vertex()]) :: t()
  def add_vertices(%__MODULE__{} = g, vertices) when is_list(vertices) do
    Enum.reduce(vertices, g, &add_vertex(&2, &1))
  end

  @doc """
  Adds a (directed) edge v -> w to the digraph. If any of the two vertices
  `v`, `w` is not present in the digraph, it'll be created and the edge
  will be added.

  ## Examples

      iex> g = Digraph.new |> Digraph.add_edge({:a, :b})
      ...> [] = Digraph.list_vertices(g) -- [:a, :b]
      ...> [] = g |> Digraph.adj(:b)
      ...> g |> Digraph.adj(:a)
      [:b]
  """
  @spec add_edge(t(), {vertex(), vertex()}) :: t()
  def add_edge(%__MODULE__{} = g, {v, w}) do
    %{adj: adj} = g = g |> add_vertex(v) |> add_vertex(w)
    v_id = hash(v)
    v_adj = Map.get(adj, v_id) |> MapSet.put(hash(w))
    %{g | adj: %{adj | v_id => v_adj}}
  end

  @doc """
  If the edge exists in the digraph, the edge will be removed.

  ## Examples

      iex> g = Digraph.new
      ...>   |> Digraph.add_edge({:a, :b})
      ...>   |> Digraph.add_edge({:b, :c})
      ...>   |> Digraph.add_edge({:a, :c})
      ...> [:c] = Digraph.list_vertices(g) -- [:a, :b]
      ...> [:c] = g |> Digraph.adj(:b)
      ...> [:b, :c] = g |> Digraph.adj(:a)
      ...> g = g |> Digraph.remove_edge({:a, :b})
      ...> [:c] = g |> Digraph.adj(:b)
      ...> [:c] = g |> Digraph.adj(:a)
  """
  @spec remove_edge(t(), {vertex(), vertex()}) :: t()
  def remove_edge(%__MODULE__{adj: adj} = g, {v, w}) do
    with v_id <- hash(v),
         w_id <- hash(w),
         v_adj when not is_nil(v_adj) <- Map.get(adj, v_id) do
      v_adj = v_adj |> MapSet.delete(w_id)
      %{g | adj: %{adj | v_id => v_adj}}
    else
      nil -> g
    end
  end

  @doc """
  Returns a list of vertices that are adjacent to the given vertex `v`.
  Adjacent here means there are direct edges from `v` pointing to those
  vertices.

  ## Examples

      iex> g = Digraph.new |> Digraph.add_vertices([:a, :b])
      ...> g = g |> Digraph.add_edge({:a, :b})
      ...> [] = g |> Digraph.adj(:b)
      ...> g |> Digraph.adj(:a)
      [:b]
  """
  @spec adj(t(), vertex()) :: [vertex()]
  def adj(%__MODULE__{vertices: vertices, adj: adj}, v) do
    v_id = hash(v)

    case Map.get(adj, v_id) do
      nil ->
        []

      v_adj ->
        v_adj |> Enum.map(fn id -> Map.get(vertices, id) end)
    end
  end

  @doc """
  Returns `true` if there is a path from vertex `v` to vertex `w` in
  the given digraph `g`.

  Returns `false`, otherwise.

  ## Examples

      iex> g = Digraph.new |> Digraph.add_vertices([:a, :b, :c])
      ...> g = g |> Digraph.add_edge({:a, :b})
      ...> g = g |> Digraph.add_edge({:b, :c})
      ...> true = g |> Digraph.has_path?(:a, :b)
      ...> false = g |> Digraph.has_path?(:b, :a)
      ...> true = g |> Digraph.has_path?(:b, :c)
      ...> false = g |> Digraph.has_path?(:c, :b)
      ...> false = g |> Digraph.has_path?(:c, :a)
      ...> g |> Digraph.has_path?(:a, :c)
      true
  """
  @spec has_path?(t(), vertex(), vertex()) :: boolean()
  def has_path?(%__MODULE__{} = g, v, w) do
    visited = dfs(g, hash(v))

    case Map.get(visited, hash(w)) do
      nil ->
        false

      true ->
        true
    end
  end

  # Depth-first search algorithm.

  defp dfs(%__MODULE__{adj: adj} = g, v) do
    case Map.get(adj, v) do
      nil ->
        %{}

      _ ->
        dfs(g, v, %{})
    end
  end

  defp dfs(%__MODULE__{adj: adj} = g, v, visited) do
    visited = Map.put(visited, v, true)

    Map.get(adj, v)
    |> Enum.reduce(visited, fn w, acc ->
      !Map.get(acc, w) && dfs(g, w, acc)
    end)
  end

  # 2^32
  @max_phash 4_294_967_296
  defp hash(v), do: :erlang.phash2(v, @max_phash)
end
