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

defmodule Casbin.Internal.Parser do
  @moduledoc """
  `Parser` is responsible for converting a string representing a
  boolean expression:

    `<boolean_expr>(variables, constants, functions)`

  into a postfix representation.

  - `constants` in `<boolean_expr>` must be either string or number
  (both integer and floating-point numbers are supported).

  - All `variables` and `functions` must start with a letter,
  and must contains only alpha-numeric characters, optionally an
  underscore `_`, or a question-mark `?`.

   - Supported operators in `<boolean_expr>` including arithmetic
   operators: `*, /, +, -`; relational operators: `==, !=, <, <=, >, >=`;
   and logical operators: `&&(and), ||(or), !(not)`.
  """

  alias Casbin.Internal.{Helpers, Operator}

  @operators [
    ~c".",
    ~c"!",
    ~c"-",
    ~c"+",
    ~c"*",
    ~c"/",
    ~c"<",
    ~c"<=",
    ~c">",
    ~c">=",
    ~c"==",
    ~c"!=",
    ~c"&&",
    ~c"||"
  ]

  @type postfix_term() ::
          {:num, number()}
          | {:str, String.t()}
          | {:var, atom()}
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
          | {:fun, %{name: atom(), arity: non_neg_integer()}}

  @type postfix_term_with_location() :: %{
          token: postfix_term(),
          location: %{line: non_neg_integer(), col: non_neg_integer()}
        }

  @type postfix_expr() :: [postfix_term_with_location()]

  @doc """
  Converts a matcher string into a postfix expression.
  """
  @spec parse(String.t()) ::
          {:ok, postfix_expr()}
          | {:error, {atom(), map()}}
  def parse(matcher_str) when is_binary(matcher_str) do
    list = String.to_charlist(matcher_str)
    init_pos = %{line: 0, col: 0}
    parse(list, [], [], [], [], nil, init_pos)
  end

  #
  # We've already exhausted the the infix list.
  #

  # Nothing left in the symbol stack
  defp parse([], [], _, _, postfix, _, _) do
    {:ok, Enum.reverse(postfix)}
  end

  # Top of symbol stack is a left parenthesis
  defp parse([], [%{token: 40, position: p} | _], _, _, _, _, _) do
    {:error, {:mismatched_parenthesis, p}}
  end

  # Top of symbol stack is an operator.
  defp parse([], [op | rest], val, arg, postfix, prev, pos) do
    parse([], rest, val, arg, [op | postfix], prev, pos)
  end

  #
  # See a whitespace or a new line character.
  #

  # Whitespace
  defp parse([32 | rest], sym, val, arg, postfix, prev, pos) do
    new_pos = next_col(pos)
    parse(rest, sym, val, arg, postfix, prev, new_pos)
  end

  # New line
  defp parse([10 | rest], sym, val, arg, postfix, prev, pos) do
    new_pos = next_line(pos)
    parse(rest, sym, val, arg, postfix, prev, new_pos)
  end

  #
  # See a numeric character?
  #

  # Interger or floating point
  defp parse([ch | rest], sym, val, arg, postfix, _prev, pos)
       when ?0 <= ch and ch <= ?9 do
    {num_type, succeeds, rem, count} = parse_number(rest)

    t =
      make_token(
        {:num, list_to_number({num_type, [ch | succeeds]})},
        pos
      )

    new_pos = next_col(pos, count + 1)

    case val do
      [] ->
        parse(rem, sym, [], arg, [t | postfix], :operand, new_pos)

      [_ | tail] ->
        parse(rem, sym, [true | tail], arg, [t | postfix], :operand, new_pos)
    end
  end

  #
  # See a double quote `"`?
  #

  # Double quoted String
  defp parse([?" | rest], sym, val, arg, postfix, _prev, pos) do
    case parse_str(rest, pos) do
      {:error, :close_double_quote_not_found} ->
        {:error, {:unexpected_token, pos}}

      {:ok, succeeds, rem, new_pos} ->
        t = make_token({:str, List.to_string(succeeds)}, pos)

        case val do
          [] ->
            parse(rem, sym, val, arg, [t | postfix], :operand, new_pos)

          [_ | tail] ->
            parse(rem, sym, [true | tail], arg, [t | postfix], :operand, new_pos)
        end
    end
  end

  #
  #  See one of these `==`, `!=`, '>=', '<=', '&&', '||'
  #

  # The symbol stack is empty.
  defp parse([ch1, ch2 | rest], [], arg, val, postfix, prev, pos)
       when [ch1, ch2] in @operators do
    t = make_token(Operator.charlist_to_operator([ch1, ch2], prev), pos)
    new_pos = next_col(pos, 2)
    parse(rest, [t], arg, val, postfix, :operator, new_pos)
  end

  # Top of the symbol stack is a left parenthesis
  defp parse([ch1, ch2 | rest], [%{token: 40} = lp | sym], val, arg, postfix, prev, pos)
       when [ch1, ch2] in @operators do
    t = make_token(Operator.charlist_to_operator([ch1, ch2], prev), pos)
    new_pos = next_col(pos, 2)
    parse(rest, [t, lp | sym], val, arg, postfix, :operator, new_pos)
  end

  # Top of symbol stack is a function
  defp parse([ch1, ch2 | rest], [%{token: {:fun, _}} = fun | sym], val, arg, postfix, prev, pos)
       when [ch1, ch2] in @operators do
    parse([ch1, ch2 | rest], sym, val, arg, [fun | postfix], prev, pos)
  end

  # Top of stack is an operator
  defp parse([ch1, ch2 | rest], [o | sym], val, arg, postfix, prev, pos)
       when [ch1, ch2] in @operators do
    op = Operator.charlist_to_operator([ch1, ch2], prev)
    {succeeds, rem, _} = pop_operators([o | sym], op)
    t = make_token(op, pos)
    new_pos = next_col(pos, 2)
    parse(rest, [t | rem], val, arg, succeeds ++ postfix, :operator, new_pos)
  end

  #
  # See one of these `.`, `!`, `+`, `-`, `*`, `/`, '>', '<'
  #

  # symbol stack is empty
  defp parse([ch | rest], [], val, arg, postfix, prev, pos)
       when [ch] in @operators do
    t = make_token(Operator.charlist_to_operator([ch], prev), pos)
    new_pos = next_col(pos, 1)
    parse(rest, [t], arg, val, postfix, :operator, new_pos)
  end

  # Top of symbol stack is a left parenthesis
  defp parse([ch | rest], [%{token: 40} = lp | sym], val, arg, postfix, prev, pos)
       when [ch] in @operators do
    t = make_token(Operator.charlist_to_operator([ch], prev), pos)
    new_pos = next_col(pos, 1)
    parse(rest, [t, lp | sym], val, arg, postfix, :operator, new_pos)
  end

  # Top of symbol stack is a function
  defp parse([ch | rest], [%{token: {:fun, _}} = fun | sym], val, arg, postfix, prev, pos)
       when [ch] in @operators do
    parse([ch | rest], sym, val, arg, [fun | postfix], prev, pos)
  end

  # Top of symbol stack is an operator
  defp parse([ch | rest], [o | sym], val, arg, postfix, prev, pos)
       when [ch] in @operators do
    op = Operator.charlist_to_operator([ch], prev)
    {succeeds, rem, _} = pop_operators([o | sym], op)
    t = make_token(op, pos)
    new_pos = next_col(pos, 1)
    parse(rest, [t | rem], val, arg, succeeds ++ postfix, :operator, new_pos)
  end

  #
  # See a left parenthesis?
  #

  defp parse([40 | rest], sym, val, arg, postfix, _prev, pos) do
    t = make_token(40, pos)
    new_pos = next_col(pos, 1)
    parse(rest, [t | sym], val, arg, postfix, :left_paren, new_pos)
  end

  #
  # See a right parenthesis.
  #

  # Symbol stack is empty.
  defp parse([41 | _rest], [], _val, _arg, _postfix, _prev, pos) do
    {:error, {:unexpected_token, pos}}
  end

  # Symbol stack has a left parenthesis followed by a function.
  # And the previous value stack has a `true` on top of it.
  defp parse(
         [41 | rest],
         [%{token: 40}, %{token: {:fun, _}} = fun | sym],
         [true | val],
         [a | arg],
         postfix,
         _prev,
         pos
       ) do
    %{
      token: {:fun, %{name: name}},
      position: position
    } = fun

    t = %{
      position: position,
      token: {:fun, %{name: name, arity: a + 1}}
    }

    new_pos = next_col(pos, 1)
    parse(rest, sym, val, arg, [t | postfix], :right_paren, new_pos)
  end

  # Symbol stack has a left parenthesis followed by a function.
  # And the previous value stack has a `false` on top of it.
  defp parse(
         [41 | rest],
         [%{token: 40}, %{token: {:fun, _}} = fun | sym],
         [false | val],
         [a | arg],
         postfix,
         _prev,
         pos
       ) do
    %{
      token: {:fun, %{name: name}},
      position: position
    } = fun

    t = %{
      token: {:fun, %{name: name, arity: a}},
      position: position
    }

    new_pos = next_col(pos, 1)
    parse(rest, sym, val, arg, [t | postfix], :right_paren, new_pos)
  end

  # Symbol stack has a left parenthesis on top of it.
  defp parse([41 | rest], [%{token: 40} | sym], val, arg, postfix, _prev, pos) do
    new_pos = next_col(pos, 1)
    parse(rest, sym, val, arg, postfix, :right_paren, new_pos)
  end

  # Symbol stack has operator on it.
  defp parse([41 | rest], [op | sym], val, arg, postfix, prev, pos) do
    parse([41 | rest], sym, val, arg, [op | postfix], prev, pos)
  end

  #
  # See a comma `,`
  #

  # Symbol stack is empty
  defp parse([?, | _rest], [], _val, _arg, _postfix, _prev, pos) do
    # No left parentheses found, either this comma is misplaced
    # or parentheses mismatched.
    {:error, {:unexpected_token, pos}}
  end

  # Top of symbol stack is a left parenthesis and the previous value
  # stack has a `true` on top of it.
  defp parse([?, | rest], [%{token: 40} = lp | sym], [true | val], [a | arg], postfix, _prev, pos) do
    new_pos = next_col(pos, 1)
    parse(rest, [lp | sym], [false | val], [a + 1 | arg], postfix, :comma, new_pos)
  end

  # Top of symbol stack is a left parenthesis.
  defp parse([?, | rest], [%{token: 40} = lp | sym], val, arg, postfix, _prev, pos) do
    new_pos = next_col(pos, 1)
    parse(rest, [lp | sym], val, arg, postfix, :comma, new_pos)
  end

  # Top of symbol stack is an operator
  defp parse([?, | rest], [op | sym], val, arg, postfix, prev, pos) do
    parse([?, | rest], sym, val, arg, [op | postfix], prev, pos)
  end

  #
  # See a lowercase character.
  #

  # previous value stack is empty.
  defp parse([ch | rest], sym, [], arg, postfix, _prev, pos)
       when (?a <= ch and ch <= ?z) or (?A <= ch and ch <= ?Z) do
    case parse_function_or_var(rest) do
      {:fun, succeeds, rem, count} ->
        name = :erlang.list_to_atom([ch | succeeds])
        t = make_token({:fun, %{name: name}}, pos)
        new_pos = next_col(pos, count + 1)
        parse(rem, [t | sym], [false], [0 | arg], postfix, :function, new_pos)

      {:var, succeeds, rem, count} ->
        t = make_token({:var, :erlang.list_to_atom([ch | succeeds])}, pos)
        new_pos = next_col(pos, count + 1)
        parse(rem, sym, [], arg, [t | postfix], :variable, new_pos)
    end
  end

  # Previous value stack is not empty
  defp parse([ch | rest], sym, [_ | val], arg, postfix, _prev, pos)
       when (?a <= ch and ch <= ?z) or (?A <= ch and ch <= ?Z) do
    case parse_function_or_var(rest) do
      {:fun, succeeds, rem, count} ->
        name = :erlang.list_to_atom([ch | succeeds])
        t = make_token({:fun, %{name: name}}, pos)
        new_pos = next_col(pos, count + 1)
        parse(rem, [t | sym], [false, true | val], [0 | arg], postfix, :function, new_pos)

      {:var, succeeds, rem, count} ->
        t = make_token({:var, :erlang.list_to_atom([ch | succeeds])}, pos)
        new_pos = next_col(pos, count + 1)
        parse(rem, sym, [true | val], arg, [t | postfix], :variable, new_pos)
    end
  end

  #
  # Current token is non of the above.
  #

  defp parse([_ | _], _sym, _val, _arg, _postfix, _prev, pos) do
    {:error, {:unexpected_token, pos}}
  end

  #
  # Parse the rest of a postive integer or a floating point given
  # that we know one digit in advance, i.g '2xxxx' -> list = 'xxxx'
  #

  defp parse_number(list) do
    parse_number(list, [], 0, false)
  end

  # See a numeric character?
  defp parse_number([ch | rest], succeeds, count, is_float)
       when ?0 <= ch and ch <= ?9 do
    parse_number(rest, [ch | succeeds], count + 1, is_float)
  end

  # See a dot `.` followed by a numeric character?
  defp parse_number([?., ch | rest], succeeds, count, _is_float)
       when ?0 <= ch and ch <= ?9 do
    parse_number(rest, [ch, ?. | succeeds], count + 2, true)
  end

  # See none of the above
  defp parse_number(list, succeeds, count, is_float) do
    case is_float do
      true ->
        {:float, Enum.reverse(succeeds), list, count}

      false ->
        {:integer, Enum.reverse(succeeds), list, count}
    end
  end

  #
  # Parse the remaining of a double quoted string,
  # e.g '"xxxx"' -> list = 'xxxx"'
  #

  defp parse_str(list, pos), do: parse_str(list, [], pos)

  # See closing double quote.
  defp parse_str([?" | rest], succeeds, pos) do
    {:ok, Enum.reverse(succeeds), rest, next_col(pos)}
  end

  # See a new line char
  defp parse_str([10 | rest], succeeds, pos) do
    new_pos = next_line(pos)
    parse_str(rest, [10 | succeeds], new_pos)
  end

  # See any other character.
  defp parse_str([ch | rest], succeeds, pos) do
    new_pos = next_col(pos)
    parse_str(rest, [ch | succeeds], new_pos)
  end

  # Reach the end but didn't see any double quote so far.
  defp parse_str([], _, _) do
    {:error, :close_double_quote_not_found}
  end

  #
  # Parse a function or a variable
  #

  defp parse_function_or_var(list) do
    parse_function_or_var(list, [], 0)
  end

  # Exhausted the input list. It must be a variable.
  defp parse_function_or_var([], succeeds, count) do
    {:var, Enum.reverse(succeeds), [], count}
  end

  # See an alphanumeric character. Continue
  defp parse_function_or_var([ch | rest], succeeds, count)
       when (?0 <= ch and ch <= ?9) or
              (?a <= ch and ch <= ?z) or
              (?A <= ch and ch <= ?Z) or
              ch == ?_ or
              ch == ?? do
    parse_function_or_var(rest, [ch | succeeds], count + 1)
  end

  # See a left parenthesis. It must be part of a function name
  defp parse_function_or_var([40 | rest], succeeds, count) do
    {:fun, Enum.reverse(succeeds), [40 | rest], count}
  end

  # See a whitespace followed by a left parenthesis?
  defp parse_function_or_var([32, 40 | rest], succeeds, count) do
    {:fun, Enum.reverse(succeeds), [32, 40 | rest], count}
  end

  # See a whitespace only?
  defp parse_function_or_var([32 | rest], succeeds, count) do
    parse_function_or_var(rest, succeeds, count + 1)
  end

  # See anything else, terminate the search.
  defp parse_function_or_var(list, succeeds, count) do
    {:var, Enum.reverse(succeeds), list, count}
  end

  # Converts from a list of character to a number, either integer or
  # floating point.
  defp list_to_number({:integer, list}) do
    :erlang.list_to_integer(list)
  end

  defp list_to_number({:float, list}) do
    :erlang.list_to_float(list)
  end

  # Make token.
  defp make_token(token, position) do
    %{
      token: token,
      position: position
    }
  end

  # Pop the operators out of the symbol stack given the `current_operator`
  # to compare with.
  defp pop_operators(symbol_stack, current_operator) do
    Helpers.get_while(
      fn %{token: op} ->
        Operator.operator?(op) &&
          (Operator.higher_precedence?(op, current_operator) ||
             (Operator.same_precedence?(op, current_operator) &&
                Operator.left_associative?(current_operator)))
      end,
      symbol_stack,
      # reverse
      true
    )
  end

  #
  # Update position.
  #

  # Update the current position by `n` number of lines.
  defp next_line(%{line: l, col: _c}, n \\ 1), do: %{line: l + n, col: 0}

  # Update the current position by `n` number of columns.
  defp next_col(%{line: l, col: c}, n \\ 1), do: %{line: l, col: c + n}
end
