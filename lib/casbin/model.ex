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

defmodule Casbin.Model do
  @moduledoc """
  This module defines the structure to represent a PERM (Policy, Effect,
  Request, Matchers) meta model. See [1] for more information.

  TODO

  [1] - https://casbin.org/docs/how-it-works
  """

  defstruct request: nil,
            policies: [],
            matcher: nil,
            effect: nil,
            role_mappings: []

  alias Casbin.Model.{
    Config,
    Matcher,
    Policy,
    PolicyDefinition,
    PolicyEffect,
    Request,
    RequestDefinition
  }

  @type t() :: %__MODULE__{
          request: RequestDefinition.t(),
          policies: [PolicyDefinition.t()],
          matcher: Matcher.t(),
          effect: PolicyEffect.t(),
          role_mappings: [atom()]
        }

  @doc """
  Initializes a model given the config file `cfile`.

  ## Examples

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> %Model{request: rd} = m
      ...> %RequestDefinition{key: :r, attrs: attrs} = rd
      ...> attrs
      [:sub, :obj, :act]

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> %Model{policies: definitions} = m
      ...> [%PolicyDefinition{key: :p, attrs: attrs}] = definitions
      ...> attrs
      [:sub, :obj, :act, :eft]

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> %Model{effect: %PolicyEffect{rule: rule}} = m
      ...> rule
      "some(where(p.eft==allow))"

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> %Model{role_mappings: mappings} = m
      ...> mappings
      []

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> %Model{matcher: %Matcher{prog: prog}} = m
      ...> prog
      [
        {:fetch_attr, %{attr: :sub, key: :r}},
        {:fetch_attr, %{attr: :sub, key: :p}},
        {:eq},
        {:fetch_attr, %{attr: :obj, key: :r}},
        {:fetch_attr, %{attr: :obj, key: :p}},
        {:eq},
        {:and},
        {:fetch_attr, %{attr: :act, key: :r}},
        {:fetch_attr, %{attr: :act, key: :p}},
        {:eq},
        {:and}
      ]

      iex> cfile = "../../test/data/kv.conf" |> Path.expand(__DIR__)
      ...> {:error, reason} = Model.init(cfile)
      ...> reason
      "missing `request_definition` section in the config file"
  """
  @spec init(String.t()) :: {:ok, t()} | {:error, String.t()}
  def init(cfile) when is_binary(cfile) do
    case Config.new(cfile) do
      {:error, reason} ->
        {:error, reason}

      %Config{sections: sections} ->
        %__MODULE__{}
        |> validate_required_sections(sections)
        |> build(:request)
        |> build(:policies)
        |> build(:effect)
        |> build(:matcher)
        |> build(:role_mappings)
        |> case do
          {:error, reason} ->
            {:error, reason}

          {:ok, model, _} ->
            {:ok, model}
        end
    end
  end

  @doc """
  Creates a new request.

  ## Examples

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> valid_request = ["alice", "data1", "read"]
      ...> {:ok, r} = m |> Model.create_request(valid_request)
      ...> %Request{key: :r, attrs: attrs} = r
      ...> attrs
      [sub: "alice", obj: "data1", act: "read"]

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> invalid_request = ["alice", "data1"]
      ...> {:error, reason} = m |> Model.create_request(invalid_request)
      ...> reason
      "invalid request"
  """
  @spec create_request(t(), [String.t()]) ::
          {:ok, Request.t()}
          | {:error, String.t()}
  def create_request(%__MODULE__{request: rd}, attr_values) do
    RequestDefinition.create_request(rd, attr_values)
  end

  @doc """
  Creates a new policy.

  ## Examples

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> valid_policy = {:p, ["alice", "data1", "read"]}
      ...> {:ok, p} = m |> Model.create_policy(valid_policy)
      ...> %Policy{key: :p, attrs: attrs} = p
      ...> attrs
      [sub: "alice", obj: "data1", act: "read", eft: "allow"]

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> valid_policy = {:p, ["alice", "data1", "read", "allow"]}
      ...> {:ok, p} = m |> Model.create_policy(valid_policy)
      ...> %Policy{key: :p, attrs: attrs} = p
      ...> attrs
      [sub: "alice", obj: "data1", act: "read", eft: "allow"]

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> valid_policy = {:p, ["alice", "data1", "read", "deny"]}
      ...> {:ok, p} = m |> Model.create_policy(valid_policy)
      ...> %Policy{key: :p, attrs: attrs} = p
      ...> attrs
      [sub: "alice", obj: "data1", act: "read", eft: "deny"]

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> invalid_policy = {:q, ["alice", "data1", "read"]}
      ...> {:error, reason} = m |> Model.create_policy(invalid_policy)
      ...> reason
      "policy with key `q` is undefined"

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> invalid_policy = {:p, ["alice", "data1", "read", "foo"]}
      ...> {:error, reason} = m |> Model.create_policy(invalid_policy)
      ...> reason
      "invalid value for the `eft` attribute: `foo`"

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> invalid_policy = {:p, ["alice", "data1", :read]}
      ...> {:error, reason} = m |> Model.create_policy(invalid_policy)
      ...> reason
      "invalid attribute value type"
  """
  @spec create_policy(t(), [String.t()]) ::
          {:ok, Policy.t()}
          | {:error, String.t()}
  def create_policy(
        %__MODULE__{policies: definitions},
        {key, attr_values}
      ) do
    found_matched_definition =
      definitions
      |> Enum.find(fn %PolicyDefinition{key: k} -> k === key end)

    case found_matched_definition do
      nil ->
        {:error, "policy with key `#{key}` is undefined"}

      definition ->
        PolicyDefinition.create_policy(definition, attr_values)
    end
  end

  def create_policy(%__MODULE__{}, _), do: {:error, "invalid policy"}

  @doc """
  Creates a new policy.
  """
  def create_policy!(%__MODULE__{} = m, {key, attr_values}) do
    case create_policy(m, {key, attr_values}) do
      {:error, reason} ->
        raise ArgumentError, message: reason

      {:ok, policy} ->
        policy
    end
  end

  @doc """
  Returns `true` if there is a policy definition with the given key
  `key` in the model.

  Returns `false`, otherwise.

  ## Examples

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> m |> Model.has_policy_key?(:p)
      true

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> m |> Model.has_policy_key?(:q)
      false
  """
  @spec has_policy_key?(t(), atom()) :: boolean()
  def has_policy_key?(%__MODULE__{policies: definitions}, key) do
    definitions
    |> Enum.find(fn %PolicyDefinition{key: k} -> k === key end)
    |> case do
      nil ->
        false

      _ ->
        true
    end
  end

  @doc """
  Returns `true` if the given model has a role mapping of the given name.

  Returns `false`, otherwise.

  ## Examples

      iex> cfile = "../../test/data/rbac.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> false = m |> Model.has_role_mapping?(:g2)
      ...> m |> Model.has_role_mapping?(:g)
      true
  """
  @spec has_role_mapping?(t(), atom()) :: boolean()
  def has_role_mapping?(%__MODULE__{role_mappings: mappings}, name) do
    name in mappings
  end

  @doc """
  Returns `true` if the given request matches the given policy.

  Returns `false`, otherwise.

  ## Examples

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> rule = ["alice", "data1", "read"]
      ...> {:ok, p} = m |> Model.create_policy({:p, rule})
      ...> {:ok, r} =  m |> Model.create_request(rule)
      ...> m |> Model.match?(r, p)
      true

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> rule = ["alice", "data1", "read"]
      ...> {:ok, p} = m |> Model.create_policy({:p, rule})
      ...> request = ["alice", "data1", "write"]
      ...> {:ok, r} =  m |> Model.create_request(request)
      ...> m |> Model.match?(r, p)
      false
  """
  @spec match?(t(), Request.t(), Policy.t(), map()) :: boolean()
  def match?(
        %__MODULE__{matcher: matcher},
        %Request{key: r, attrs: r_attrs},
        %Policy{key: p, attrs: p_attrs},
        env \\ %{}
      ) do
    environment =
      env
      |> Map.put(p, p_attrs)
      |> Map.put(r, r_attrs)

    !!Matcher.eval!(matcher, environment)
  end

  @doc """
  Takes a list of matched policies and determines whether the final effect
  is `allow` or `deny` based on the `policy_effect`.

  ## Examples

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> m |> Model.allow?([])
      false

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> allowed_rule = {:p, ["alice", "data1", "read"]}
      ...> {:ok, p} = m |> Model.create_policy(allowed_rule)
      ...> m |> Model.allow?([p])
      true

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> denied_rule = {:p, ["alice", "data1", "write", "deny"]}
      ...> {:ok, p} = m |> Model.create_policy(denied_rule)
      ...> m |> Model.allow?([p])
      false

      iex> cfile = "../../test/data/acl.conf" |> Path.expand(__DIR__)
      ...> {:ok, m} = Model.init(cfile)
      ...> allowed_rule = {:p, ["alice", "data1", "read"]}
      ...> denied_rule = {:p, ["alice", "data1", "write", "deny"]}
      ...> {:ok, p1} = m |> Model.create_policy(allowed_rule)
      ...> {:ok, p2} = m |> Model.create_policy(denied_rule)
      ...> m |> Model.allow?([p1, p2])
      true
  """
  def allow?(%__MODULE__{effect: pe}, matched_policies) do
    pe |> PolicyEffect.allow?(matched_policies)
  end

  #
  # Helpers.
  #

  defp validate_required_sections(model, sections) do
    cond do
      sections[:request_definition] == nil ->
        missing_section_error("request_definition")

      sections[:policy_definition] == nil ->
        missing_section_error("policy_definition")

      sections[:policy_effect] == nil ->
        missing_section_error("policy_effect")

      sections[:matchers] == nil ->
        missing_section_error("matchers")

      true ->
        {:ok, model, sections}
    end
  end

  defp build({:error, msg}, _), do: {:error, msg}

  # Build request definition
  defp build({:ok, model, sections}, :request) do
    sections
    |> validate_request_definition()
    |> case do
      {:error, reason} ->
        {:error, reason}

      {:ok, rd} ->
        model = %{model | request: rd}
        {:ok, model, sections}
    end
  end

  # Build policy definition
  defp build({:ok, model, sections}, :policies) do
    sections
    |> validate_policy_definition()
    |> case do
      {:error, reason} ->
        {:error, reason}

      {:ok, definitions} ->
        model = %{model | policies: definitions}
        {:ok, model, sections}
    end
  end

  # Build policy effect
  defp build({:ok, model, sections}, :effect) do
    sections
    |> validate_effect_rule()
    |> case do
      {:error, reason} ->
        {:error, reason}

      {:ok, pe} ->
        model = %{model | effect: pe}
        {:ok, model, sections}
    end
  end

  # Build matcher program
  defp build({:ok, model, sections}, :matcher) do
    sections
    |> validate_matchers()
    |> case do
      {:error, reason} ->
        {:error, reason}

      {:ok, m} ->
        model = %{model | matcher: m}
        {:ok, model, sections}
    end
  end

  # Build role definitions
  defp build({:ok, model, sections}, :role_mappings) do
    sections
    |> validate_role_mappings()
    |> case do
      {:error, reason} ->
        {:error, reason}

      {:ok, mappings} ->
        model = %{model | role_mappings: mappings}
        {:ok, model, sections}
    end
  end

  defp missing_section_error(section_name) do
    {
      :error,
      "missing `#{section_name}` section in the config file"
    }
  end

  # Validate request definition
  defp validate_request_definition(sections) do
    case sections[:request_definition] do
      [{key, value}] when is_atom(key) and value !== "" ->
        {:ok, RequestDefinition.new(key, value)}

      _ ->
        {:error, "invalid request definition"}
    end
  end

  # Validate policy definition
  defp validate_policy_definition(sections) do
    sections[:policy_definition]
    |> Enum.map(fn {key, value} -> PolicyDefinition.new(key, value) end)
    |> case do
      [] ->
        {:error, "policy definition required"}

      definitions ->
        {:ok, definitions}
    end
  end

  # Validate policy effect rule
  @effect_rules ["some(where(p.eft==allow))", "!some(where(p.eft==deny))"]
  defp validate_effect_rule(sections) do
    case sections[:policy_effect] do
      [{_key, rule}] when rule in @effect_rules ->
        {:ok, PolicyEffect.new(rule)}

      _ ->
        {:error, "invalid policy effect rule"}
    end
  end

  # Validate matchers
  defp validate_matchers(sections) do
    case sections[:matchers] do
      [{_key, value}] when value !== "" ->
        case Matcher.new(value) do
          {:error, reason} ->
            {:error, reason}

          %Matcher{} = m ->
            {:ok, m}
        end

      _ ->
        {:error, "invalid matchers"}
    end
  end

  # Validate role mappings (a.k.a role definition)

  defp validate_role_mappings(sections) do
    case sections[:role_definition] do
      nil ->
        {:ok, []}

      definitions ->
        case check_role_definition(definitions) do
          {:error, reason} ->
            {:error, reason}

          :ok ->
            {:ok, Keyword.keys(definitions)}
        end
    end
  end

  # A valid role definition should be `{key, "_,_"}` in which
  # `key` must be an atom.
  defp check_role_definition([]), do: :ok

  defp check_role_definition([{_key, "_,_"} | rest]) do
    check_role_definition(rest)
  end

  defp check_role_definition([{_key, "_,_,_"} | rest]) do
    check_role_definition(rest)
  end

  defp check_role_definition([{key, val} | _]) do
    {:error, "invalid role definition: `#{key}=#{val}`"}
  end
end
