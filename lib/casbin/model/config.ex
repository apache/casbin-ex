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

defmodule Casbin.Model.Config do
  @moduledoc """
  A configuration file is a text files divided into named sections
  (optional). Brackets enclose each section name.

  A valid section name must starts with a lowercase letter and must
  contain only alphanumeric characters and optionally an underscore `_`.

  Each section contains key/value pairs separated by an equal sing(=).

  If there is no section specified, all the key-value pairs will be
  put under the default section `:undefined_section`.

  An example of a valid configuration file:

    [section_1]
    key1 = value
    key2 = value

    [section_2]
    key1 = value
    key2 = value
  """

  defstruct sections: []

  @type key() :: atom()
  @type value() :: String.t()
  @type section_name() :: atom()
  @type section() :: {section_name(), [{key(), value()}]}
  @type t() :: %__MODULE__{
          sections: [section()]
        }

  @whitespace 32
  @new_line 10
  @eq 61
  @default_section :undefined_section

  @doc """
  Reads a config file, parses it and converts it into a Config struct.
  """
  @spec new(String.t()) :: t() | {:error, String.t()}
  def new(cfile) when is_binary(cfile) do
    cfile
    |> File.read!()
    |> parse()
    |> convert()
    |> validate_sections()
    |> case do
      {:error, reason} ->
        # Enhanced error message includes file path and detailed reason
        {
          :error,
          "error occurred when parsing config file #{cfile}: #{reason}"
        }

      {:ok, sections} ->
        %__MODULE__{sections: sections}
    end
  end

  #
  # Convert parsing result to config list.
  #
  # An example of valid parsing result:
  #
  # `[:section_name, :eq, 'v2', 'k2', :eq, 'v1', 'k1']`
  #
  # The resulting config would be:
  #
  # `[section_name: [k1: "v1", k2: "v2"]]`

  defp convert({:ok, tokens}), do: convert(tokens, [])

  defp convert({:error, {reason, _pos}}), do: {:error, reason}

  defp convert([sec | rest], ret) when is_atom(sec) and sec != :eq do
    next_section = {sec, []}
    convert(rest, [next_section | ret])
  end

  defp convert([:eq | rest], [{sec, data} | ret]) do
    {succeeds, rem} = get_key_val(rest)

    case succeeds do
      [key_str | tokens] ->
        key = :erlang.list_to_atom(key_str)

        value =
          tokens
          |> List.flatten()
          |> :erlang.list_to_binary()

        convert(rem, [{sec, [{key, value} | data]} | ret])

      _ ->
        {:error, "syntax error"}
    end
  end

  defp convert([], final), do: {:ok, final}

  #
  # Validating. (TODO: make this shit more robust and efficient)
  #

  defp validate_sections({:error, reason}), do: {:error, reason}

  defp validate_sections({:ok, sections}) do
    names = sections |> Keyword.keys()

    # What????? Is this the only way to check for duplicate items
    # in a list?
    case names -- Enum.uniq(names) do
      [] ->
        validate_sections(sections, sections)

      _ ->
        {:error, "duplicate section names"}
    end
  end

  defp validate_sections([], sections), do: {:ok, sections}

  defp validate_sections([{section, []} | _], _) do
    {:error, "section `#{section}` is empty"}
  end

  defp validate_sections([{section, key_vals} | rest], sections) do
    keys = key_vals |> Keyword.keys()

    # Again?
    case keys -- Enum.uniq(keys) do
      [] ->
        case validate_pairs(key_vals) do
          {:error, reason} ->
            {:error, reason}

          :ok ->
            validate_sections(rest, sections)
        end

      _ ->
        {:error, "section `#{section}` has duplicate keys"}
    end
  end

  defp validate_pairs([]), do: :ok

  defp validate_pairs([{key, ""} | _]) do
    {:error, "empty value for key `#{key}`"}
  end

  defp validate_pairs([{_key, _val} | tail]), do: validate_pairs(tail)

  #
  # Parsing
  #

  defp parse(str) do
    init_pos = %{line: 0, col: 0}
    parse(String.to_charlist(str), [], [], [], init_pos)
  end

  #
  # See '[ch': starts new section
  #

  # Sections stack is empty.
  defp parse([91, ch | rest], [], eq_stack, tokens, pos)
       when ?a <= ch and ch <= ?z do
    case parse_section(rest) do
      {:error, reason} ->
        {:error, {reason, pos}}

      {:ok, succeeds, rem, count} ->
        new_section = :erlang.list_to_atom([ch | succeeds])
        next_pos = next_col(pos, count + 2)
        parse(rem, [new_section], eq_stack, tokens, next_pos)
    end
  end

  # Sections stack is not empty.
  defp parse([91, ch | rest], [prev_section], [:eq], tokens, pos)
       when ?a <= ch and ch <= ?z do
    case parse_section(rest) do
      {:error, reason} ->
        {:error, {reason, pos}}

      {:ok, succeeds, rem, count} ->
        new_section = :erlang.list_to_atom([ch | succeeds])
        next_pos = next_col(pos, count + 2)
        parse(rem, [new_section], [], [prev_section, :eq | tokens], next_pos)
    end
  end

  # See one of thes ==, != , >=, <=

  defp parse([ch, ?= | rest], [], eq_stack, tokens, pos)
       when ch in ~c"=!><" do
    next_token = [ch, ?=]
    next_pos = next_col(pos, 2)
    parse(rest, [@default_section], eq_stack, [next_token | tokens], next_pos)
  end

  defp parse([ch, ?= | rest], secs, eq_stack, tokens, pos)
       when ch in ~c"=!><" do
    next_token = [ch, ?=]
    next_pos = next_col(pos, 2)
    parse(rest, secs, eq_stack, [next_token | tokens], next_pos)
  end

  # See =

  defp parse([?= | rest], [], [], tokens, pos) do
    next_pos = next_col(pos)
    parse(rest, [@default_section], [:eq], tokens, next_pos)
  end

  defp parse([?= | rest], [], [:eq], [head | tail], pos) do
    next_pos = next_col(pos)
    parse(rest, [@default_section], [:eq], [head, :eq | tail], next_pos)
  end

  defp parse([?= | rest], secs, [], tokens, pos) do
    next_pos = next_col(pos)
    parse(rest, secs, [:eq], tokens, next_pos)
  end

  defp parse([?= | rest], secs, [:eq], [head | tail], pos) do
    next_pos = next_col(pos)
    parse(rest, secs, [:eq], [head, :eq | tail], next_pos)
  end

  # See a whitespace or new line

  defp parse([@whitespace | rest], secs, eq_stack, tokens, pos) do
    next_pos = next_col(pos)
    parse(rest, secs, eq_stack, tokens, next_pos)
  end

  defp parse([@new_line | rest], secs, eq_stack, tokens, pos) do
    next_pos = next_line(pos)
    parse(rest, secs, eq_stack, tokens, next_pos)
  end

  # See `#`.
  defp parse([35 | rest], secs, eq_stack, tokens, pos) do
    {rem, count} = skip_comment(rest)
    next_pos = next_col(pos, count + 1)
    parse(rem, secs, eq_stack, tokens, next_pos)
  end

  # See any other character.

  defp parse([ch | rest], [], eq_stack, tokens, pos) do
    {succeeds, rem, count} = parse_token(rest)
    next_token = [ch | succeeds]
    next_pos = next_col(pos, count + 1)
    parse(rem, [@default_section], eq_stack, [next_token | tokens], next_pos)
  end

  defp parse([ch | rest], secs, eq_stack, tokens, pos) do
    {succeeds, rem, count} = parse_token(rest)
    next_token = [ch | succeeds]
    next_pos = next_col(pos, count + 1)
    parse(rem, secs, eq_stack, [next_token | tokens], next_pos)
  end

  # Exhausted the input list

  defp parse([], [], [], tokens, _) do
    {:ok, tokens}
  end

  defp parse([], [s], [:eq], tokens, _) do
    {:ok, [s, :eq | tokens]}
  end

  # None of the above
  defp parse(_, _, _, _, pos), do: {:error, {"syntax error", pos}}

  #
  # Helpers.
  #

  # Consume token.

  defp parse_token(list), do: parse_token(list, 0)

  defp parse_token([], _) do
    {[], [], 0}
  end

  defp parse_token([ch, ?= | rest], count) when ch in ~c"!<>=" do
    {succeeds, rem, c} = parse_token(rest, 0)
    {[ch, ?= | succeeds], rem, count + 2 + c}
  end

  defp parse_token([ch | rest], count) do
    case ch == @new_line || ch == @whitespace || ch == @eq do
      true ->
        {[], [ch | rest], 0}

      false ->
        {succeeds, rem, c} = parse_token(rest, 0)
        {[ch | succeeds], rem, count + 1 + c}
    end
  end

  # Parse section.

  defp parse_section(list), do: parse_section(list, 0)

  # See ']'
  defp parse_section([93 | rest], count) do
    {:ok, [], rest, count + 1}
  end

  # See lowercase character or _
  defp parse_section([ch | rest], count)
       when (?a <= ch and ch <= ?z) or (?0 <= ch and ch <= ?9) or ch == ?_ do
    case parse_section(rest, count + 1) do
      {:error, reason} ->
        {:error, reason}

      {:ok, succeeds, rem, c} ->
        {:ok, [ch | succeeds], rem, c}
    end
  end

  # See any other characters or list is empty.
  defp parse_section(_rest, _count) do
    {:error, "invalid section name"}
  end

  # Skip comment line.

  defp skip_comment(line), do: skip_comment(line, 0)

  defp skip_comment([], count), do: {[], count}

  defp skip_comment([@new_line | rest], count) do
    {[@new_line | rest], count}
  end

  defp skip_comment([_ | rest], count) do
    skip_comment(rest, count + 1)
  end

  # Update position.

  # Update the current position by `n` number of lines.
  defp next_line(%{line: l, col: _c}, n \\ 1), do: %{line: l + n, col: 0}

  # Update the current position by `n` number of columns.
  defp next_col(%{line: l, col: c}, n \\ 1), do: %{line: l, col: c + n}

  # Get key-value pair.

  defp get_key_val(list), do: get_key_val(list, [])

  defp get_key_val([], succeeds), do: {succeeds, []}

  defp get_key_val([token | rest], succeeds) when is_atom(token) do
    {succeeds, [token | rest]}
  end

  defp get_key_val([token | rest], succeeds) do
    get_key_val(rest, [token | succeeds])
  end
end
