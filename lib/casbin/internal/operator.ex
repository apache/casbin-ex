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

defmodule Casbin.Internal.Operator do
  @moduledoc """
  This module defines a set of operators and helper functions used when
  parsing operators in a matcher expression.
  """

  @type result() :: number() | String.t() | boolean()
  @type t() ::
          :dot
          | :not
          | :pos
          | :neg
          | :mul
          | :div
          | :add
          | :sub
          | :lt
          | :le
          | :gt
          | :ge
          | :eq
          | :ne
          | :and
          | :or

  @operators [
    :dot,
    :not,
    :pos,
    :neg,
    :mul,
    :div,
    :add,
    :sub,
    :lt,
    :le,
    :gt,
    :ge,
    :eq,
    :ne,
    :and,
    :or
  ]

  @doc """
  Converts a charlist to an operator based on the type of previous token.
  """
  @spec charlist_to_operator(charlist(), atom()) :: t()
  def charlist_to_operator(~c"+", prev)
      when prev not in [:operand, :variable, :right_paren],
      do: :pos

  def charlist_to_operator(~c"-", prev)
      when prev not in [:operand, :variable, :right_paren],
      do: :neg

  def charlist_to_operator(list, _), do: charlist_to_operator(list)

  @doc """
  Converts an operator to its textual representation.
  """
  @spec operator_to_charlist(t()) :: charlist()
  def operator_to_charlist(:dot), do: ~c"."
  def operator_to_charlist(:not), do: ~c"!"
  def operator_to_charlist(:pos), do: ~c"+"
  def operator_to_charlist(:neg), do: ~c"-"
  def operator_to_charlist(:mul), do: ~c"*"
  def operator_to_charlist(:div), do: ~c"/"
  def operator_to_charlist(:add), do: ~c"+"
  def operator_to_charlist(:sub), do: ~c"-"
  def operator_to_charlist(:lt), do: ~c"<"
  def operator_to_charlist(:le), do: ~c"<="
  def operator_to_charlist(:gt), do: ~c">"
  def operator_to_charlist(:ge), do: ~c">="
  def operator_to_charlist(:eq), do: ~c"=="
  def operator_to_charlist(:ne), do: ~c"!="
  def operator_to_charlist(:and), do: ~c"&&"
  def operator_to_charlist(:or), do: ~c"||"

  @doc """
  Returns `true` if `op1` has higher precedence than `op2`, or `false`
  otherwise.
  """
  @spec higher_precedence?(t(), t()) :: boolean()
  def higher_precedence?(op1, op2), do: precedence(op1) > precedence(op2)

  @doc """
  Returns `true` if two operators `op1` and `op2` have the same
  precedence, or `false` otherwise.
  """
  @spec same_precedence?(t(), t()) :: boolean()
  def same_precedence?(op1, op2), do: precedence(op1) == precedence(op2)

  @doc """
  Returns `true` if the operator `op` is left associative, or `false`
  otherwise.
  """
  @spec left_associative?(t()) :: boolean()
  def left_associative?(op) when op in [:not, :pos, :neg], do: false
  def left_associative?(_op), do: true

  @doc """
  Returns `true` if atom `a` represents an operator in our system, or
  `false` otherwise.
  """
  @spec operator?(atom()) :: boolean()
  def operator?(a) when a in @operators, do: true
  def operator?(_), do: false

  @doc """
  Apply an operator to the given list of operands
  """
  @spec apply(t(), [result()]) :: result()

  # Unary operator

  def apply(:not, [x]) do
    {:ok, !x}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": !#{x}"}
  end

  def apply(:pos, [x]) do
    {:ok, +x}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": +#{x}"}
  end

  def apply(:neg, [x]) do
    {:ok, -x}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": -#{x}"}
  end

  # Binary operator.

  def apply(:mul, [x, y]) do
    {:ok, x * y}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": #{x} * #{y}"}
  end

  def apply(:div, [x, y]) do
    {:ok, x / y}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": #{x} / #{y}"}
  end

  def apply(:add, [x, y]) do
    {:ok, x + y}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": #{x} + #{y}"}
  end

  def apply(:sub, [x, y]) do
    {:ok, x - y}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": #{x} - #{y}"}
  end

  def apply(:lt, [x, y]) do
    {:ok, x < y}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": #{x} < #{y}"}
  end

  def apply(:le, [x, y]) do
    {:ok, x <= y}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": #{x} <= #{y}"}
  end

  def apply(:gt, [x, y]) do
    {:ok, x > y}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": #{x} > #{y}"}
  end

  def apply(:ge, [x, y]) do
    {:ok, x >= y}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": #{x} >= #{y}"}
  end

  def apply(:eq, [x, y]) do
    {:ok, x == y}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": #{x} == #{y}"}
  end

  def apply(:ne, [x, y]) do
    {:ok, x != y}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": #{x} != #{y}"}
  end

  def apply(:and, [x, y]) do
    {:ok, x && y}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": #{x} && #{y}"}
  end

  def apply(:or, [x, y]) do
    {:ok, x || y}
  rescue
    e in ArithmeticError ->
      {:error, e.message <> ": #{x} || #{y}"}
  end

  #
  # Helpers
  #

  # Returns a precedence for an operator.
  defp precedence(:dot), do: 8
  defp precedence(:not), do: 7
  defp precedence(:pos), do: 7
  defp precedence(:neg), do: 7
  defp precedence(:mul), do: 6
  defp precedence(:div), do: 6
  defp precedence(:add), do: 5
  defp precedence(:sub), do: 5
  defp precedence(:lt), do: 4
  defp precedence(:le), do: 4
  defp precedence(:gt), do: 4
  defp precedence(:ge), do: 4
  defp precedence(:eq), do: 3
  defp precedence(:ne), do: 3
  defp precedence(:and), do: 2
  defp precedence(:or), do: 1

  # Converts from charlist to an operator.
  defp charlist_to_operator(~c"."), do: :dot
  defp charlist_to_operator(~c"!"), do: :not
  defp charlist_to_operator(~c"*"), do: :mul
  defp charlist_to_operator(~c"/"), do: :div
  defp charlist_to_operator(~c"+"), do: :add
  defp charlist_to_operator(~c"-"), do: :sub
  defp charlist_to_operator(~c"<"), do: :lt
  defp charlist_to_operator(~c"<="), do: :le
  defp charlist_to_operator(~c">"), do: :gt
  defp charlist_to_operator(~c">="), do: :ge
  defp charlist_to_operator(~c"=="), do: :eq
  defp charlist_to_operator(~c"!="), do: :ne
  defp charlist_to_operator(~c"&&"), do: :and
  defp charlist_to_operator(~c"||"), do: :or
end
