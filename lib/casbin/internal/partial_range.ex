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

defmodule Casbin.Internal.PartialRange do
  @moduledoc """
  PartialRange represents one of the following mathematical objects:

  - A partial half-open interval up to, but not including,
    an upper bound.

  - A partial interval up to, and including, an upper bound.

  - A partial interval extending upward from a lower bound.

  The PartialRange struct is structured like so:

  - A partial range type (`type`). Possible values that `type` can take are
    `:from`, `:up_to` and `:through`.

    A partial range with the type of `:from` is a partial interval
    extending upward and from a lower bound (included).

    A partial range with the type of `:up_to` is a partial half-open
    interval up to, but not including an upper bound.

    A partial range with type of `:through` is a partial interval up to,
    and including, an upper bound.

  - An integer or a float value (`bound`).
  """

  defstruct type: nil, bound: nil

  @type partial_range_type() :: :from | :up_to | :through
  @type value() :: integer() | float()
  @type t() :: %__MODULE__{type: partial_range_type(), bound: value()}
  @type t(type, bound) :: %__MODULE__{type: type, bound: bound}

  @partial_range_types [:from, :up_to, :through]

  @doc """
  Creates a new partial range from the given type and the given bound.

  ## Examples

      iex> PartialRange.new(:from, 5)
      %PartialRange{type: :from, bound: 5}

      iex> PartialRange.new(:up_to, 5)
      %PartialRange{type: :up_to, bound: 5}

      iex> PartialRange.new(:through, 5)
      %PartialRange{type: :through, bound: 5}
  """
  @spec new(partial_range_type(), value()) :: t()
  def new(type, bound)
      when (is_integer(bound) or is_float(bound)) and
             type in @partial_range_types do
    %__MODULE__{type: type, bound: bound}
  end

  @doc """
  Returns `true` if `value` is contained in the given range.

  Returns `false`, otherwise.

  ## Examples

      iex> range = PartialRange.new(:from, 5)
      ...> range |> PartialRange.contains?(5)
      true

      iex> range = PartialRange.new(:from, 5)
      ...> range |> PartialRange.contains?(5.1)
      true

      iex> range = PartialRange.new(:from, 5)
      ...> range |> PartialRange.contains?(4.9)
      false

      iex> range = PartialRange.new(:up_to, 5)
      ...> range |> PartialRange.contains?(5)
      false

      iex> range = PartialRange.new(:up_to, 5)
      ...> range |> PartialRange.contains?(5.1)
      false

      iex> range = PartialRange.new(:up_to, 5)
      ...> range |> PartialRange.contains?(4.9)
      true

      iex> range = PartialRange.new(:through, 5)
      ...> range |> PartialRange.contains?(5)
      true

      iex> range = PartialRange.new(:through, 5)
      ...> range |> PartialRange.contains?(4.9)
      true

      iex> range = PartialRange.new(:through, 5)
      ...> range |> PartialRange.contains?(5.1)
      false
  """
  @spec contains?(t(), value()) :: boolean()
  def contains?(%__MODULE__{type: type, bound: bound}, val)
      when is_integer(val) or is_float(val) do
    case type do
      :from ->
        val >= bound

      :up_to ->
        val < bound

      :through ->
        val <= bound
    end
  end

  @doc """
  Converts a string representation of a partial range to the
  `PartialRange` struct.

  Valid string represenations must be one of:

    "bound...": represents partial range of type `:from`

    "...bound": represents partial range of type `:through`

    "..<bound": represents partial range of type `:up_to`

  ## Examples

      iex> {:ok, range} = PartialRange.compile("5...")
      ...> range
      %PartialRange{type: :from, bound: 5}

      iex> {:ok, range} = PartialRange.compile("...5")
      ...> range
      %PartialRange{type: :through, bound: 5}

      iex> {:ok, range} = PartialRange.compile("..<5")
      ...> range
      %PartialRange{type: :up_to, bound: 5}

      iex> {:error, reason} = PartialRange.compile("5..")
      ...> reason
      "invalid string representation"
  """
  @spec compile(String.t()) :: {:ok, t()} | {:error, String.t()}
  def compile(str) do
    compile(:from, str)
  end

  defp compile(:from, str) do
    case parse(:from, str) do
      nil ->
        compile(:through, str)

      num ->
        {:ok, new(:from, num)}
    end
  end

  defp compile(:through, str) do
    case parse(:through, str) do
      nil ->
        compile(:up_to, str)

      num ->
        {:ok, new(:through, num)}
    end
  end

  defp compile(:up_to, str) do
    case parse(:up_to, str) do
      nil ->
        {:error, "invalid string representation"}

      num ->
        {:ok, new(:up_to, num)}
    end
  end

  @from_pattern ~r/^(?<number>[+,-]?\d+((?<has_dot>\.)\d+)?)\.{3}$/
  defp parse(:from, str) do
    case Regex.named_captures(@from_pattern, str) do
      %{"number" => value, "has_dot" => ""} ->
        {i, ""} = Integer.parse(value)
        i

      %{"number" => value, "has_dot" => "."} ->
        {f, ""} = Float.parse(value)
        f

      _ ->
        nil
    end
  end

  @through_pattern ~r/^\.{3}(?<number>[+,-]?\d+((?<has_dot>\.)\d+)?)$/
  defp parse(:through, str) do
    case Regex.named_captures(@through_pattern, str) do
      %{"number" => value, "has_dot" => ""} ->
        {i, ""} = Integer.parse(value)
        i

      %{"number" => value, "has_dot" => "."} ->
        {f, ""} = Float.parse(value)
        f

      _ ->
        nil
    end
  end

  @up_to_pattern ~r/^\.{2}<(?<number>[+,-]?\d+((?<has_dot>\.)\d+)?)$/
  defp parse(:up_to, str) do
    case Regex.named_captures(@up_to_pattern, str) do
      %{"number" => value, "has_dot" => ""} ->
        {i, ""} = Integer.parse(value)
        i

      %{"number" => value, "has_dot" => "."} ->
        {f, ""} = Float.parse(value)
        f

      _ ->
        nil
    end
  end
end
