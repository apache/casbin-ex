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

defmodule Casbin.Model.PolicyEffect do
  @moduledoc """
  This module defines a structure to represent a policy effect in a model.
  Policy effect defines whether the access should be approved or denied
  if multiple policy rules match the request.

  For now, only the following policy effect rules are valid:

  1. `"some(where(p.eft==allow))"`: if there's any matched policy rule of
    type `allow`, the final effect is `allow`. Which means if there's no
    match or all matches are of type `deny`, the final effect is `deny`.

  2. `"!some(where(p.eft==deny))"`: if there's no matched policy rules of
    type `deny`, the final effect is `allow`.
  """

  defstruct rule: nil

  @type rule() :: String.t()
  @type t() :: %__MODULE__{
          rule: rule()
        }

  @allow_override "some(where(p.eft==allow))"
  @deny_override "!some(where(p.eft==deny))"

  alias Casbin.Model.Policy

  @doc """
  Create a new policy effect based on the given `rule` string.

  ## Examples

      iex> pe = PolicyEffect.new("some(where(p.eft==allow))")
      ...> %PolicyEffect{rule: rule} = pe
      ...> rule
      "some(where(p.eft==allow))"

      iex> pe = PolicyEffect.new("!some(where(p.eft==deny))")
      ...> %PolicyEffect{rule: rule} = pe
      ...> rule
      "!some(where(p.eft==deny))"
  """
  @spec new(String.t()) :: t()
  def new(rule) when rule in [@allow_override, @deny_override] do
    %__MODULE__{rule: rule}
  end

  @doc """
  Determine whether a request is approved or denied when there are
  multiple policy rules match the request.

  ## Examples

      iex> pe = PolicyEffect.new("some(where(p.eft==allow))")
      ...> pe |> PolicyEffect.allow?([])
      false

      iex> pe = PolicyEffect.new("some(where(p.eft==allow))")
      ...> pd = PolicyDefinition.new(:p, "sub, obj, act")
      ...> values = ["alice", "data1", "read"]
      ...> {:ok, p1} = pd |> PolicyDefinition.create_policy(values)
      ...> {:ok, p2} = pd |> PolicyDefinition.create_policy(values++["deny"])
      ...> true = pe |> PolicyEffect.allow?([p1])
      ...> false = pe |> PolicyEffect.allow?([p2])
      ...> pe |> PolicyEffect.allow?([p1, p2])
      true

      iex> pe = PolicyEffect.new("!some(where(p.eft==deny))")
      ...> pe |> PolicyEffect.allow?([])
      true

      iex> pe = PolicyEffect.new("!some(where(p.eft==deny))")
      ...> pd = PolicyDefinition.new(:p, "sub, obj, act")
      ...> values = ["alice", "data1", "read"]
      ...> {:ok, p1} = pd |> PolicyDefinition.create_policy(values)
      ...> {:ok, p2} = pd |> PolicyDefinition.create_policy(values++["deny"])
      ...> true = pe |> PolicyEffect.allow?([p1])
      ...> false = pe |> PolicyEffect.allow?([p2])
      ...> pe |> PolicyEffect.allow?([p1, p2])
      false
  """
  @spec allow?(t(), [Policy.t()]) :: boolean()
  def allow?(%__MODULE__{rule: @allow_override}, matched_policies)
      when is_list(matched_policies) do
    Enum.any?(matched_policies, &Policy.allow?/1)
  end

  def allow?(%__MODULE__{rule: @deny_override}, matched_policies)
      when is_list(matched_policies) do
    Enum.all?(matched_policies, &Policy.allow?/1)
  end
end
