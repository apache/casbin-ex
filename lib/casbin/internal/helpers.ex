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

defmodule Casbin.Internal.Helpers do
  @moduledoc """
  Helper functions used internally by Casbin.
  """
  @doc """
  Returns a tuple `{succeeds, remainder, count}` where `succeeds` is
  the initial segment of the given `list`, in which all elements have
  the property `p`, `remainder` is the remainder of the `list`, and `count`
  is the number of items in `succeeds`.

  If `reverse` is set to `true` the `succeeds` list will be reversed
  (default).

  ## Examples

      iex> Helpers.get_while(&is_atom/1, [])
      {[], [], 0}

      iex> Helpers.get_while(&is_atom/1, [:a, :b, 1, :c, :d])
      {[:b, :a], [1, :c, :d], 2}

      iex> Helpers.get_while(&is_atom/1, [:a, :b, 1, :c, :d], false)
      {[:a, :b], [1, :c, :d], 2}
  """
  def get_while(p, list, reverse \\ true)
      when is_function(p, 1) and is_list(list) do
    {succeeds, remainder, count} = get_while_reverse(p, list, [], 0)

    case reverse do
      true ->
        {succeeds, remainder, count}

      false ->
        {Enum.reverse(succeeds), remainder, count}
    end
  end

  defp get_while_reverse(p, [head | tail], ret, count) do
    case p.(head) do
      false ->
        {ret, [head | tail], count}

      true ->
        get_while_reverse(p, tail, [head | ret], count + 1)
    end
  end

  defp get_while_reverse(_p, [], ret, count) do
    {ret, [], count}
  end

  @doc """
  Pops `n` number of items from the given stack.

  ## Examples

      iex> Helpers.pop_stack([], 0)
      {:ok, [], []}

      iex> Helpers.pop_stack([:a, :b, :c, :d], 2)
      {:ok, [:b, :a], [:c, :d]}

      iex> Helpers.pop_stack([:a, :b, :c, :d], 3)
      {:ok, [:c, :b, :a], [:d]}

      iex> Helpers.pop_stack([:a, :b, :c, :d], 4)
      {:ok, [:d, :c, :b, :a], []}

      iex> Helpers.pop_stack([:a, :b, :c, :d], 5)
      {:error, :not_enough_items}
  """
  def pop_stack(stack, n) when is_list(stack) and is_integer(n) and n >= 0 do
    pop_stack(stack, [], n)
  end

  defp pop_stack(rem, succeeds, 0), do: {:ok, succeeds, rem}

  defp pop_stack([], _, _), do: {:error, :not_enough_items}

  defp pop_stack([head | tail], succeeds, n) do
    pop_stack(tail, [head | succeeds], n - 1)
  end

  @doc """
  Returns `true` if the given keyword list has duplicate keys in it,
  `false` otherwise.
  """
  def has_duplicate_key?(list) do
    keys = Keyword.keys(list)
    length(keys) != length(Enum.uniq(keys))
  end
end
