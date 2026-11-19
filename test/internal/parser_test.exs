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

defmodule Casbin.Internal.ParserTest do
  use ExUnit.Case, async: true
  alias Casbin.Internal.Parser
  doctest Casbin.Internal.Parser

  describe "parse/1 for number" do
    @test_success_cases [
      {"1", [{:num, 1}]},
      {"12", [{:num, 12}]},
      {"0.5", [{:num, 0.5}]},
      {"12.34", [{:num, 12.34}]},
      {" 1 ", [{:num, 1}]},
      {" 12 ", [{:num, 12}]},
      {" 0.5 ", [{:num, 0.5}]},
      {" 12.34 ", [{:num, 12.34}]},
      {"\n1", [{:num, 1}]},
      {"\n12", [{:num, 12}]},
      {"\n0.5", [{:num, 0.5}]},
      {"\n12.34", [{:num, 12.34}]}
    ]

    Enum.each(@test_success_cases, fn {input, expected_output} ->
      test "`#{input}`" do
        assert {:ok, postfix} = Parser.parse(unquote(input))

        assert Enum.map(postfix, fn %{token: token} -> token end) ==
                 unquote(Macro.escape(expected_output))
      end
    end)
  end

  describe "parse/1 for string" do
    @test_success_cases [
      {"\"\"", [{:str, ""}]},
      {"\"a\"", [{:str, "a"}]},
      {"\"baz\"", [{:str, "baz"}]},
      {"\"1\"", [{:str, "1"}]},
      {"\"12\"", [{:str, "12"}]},
      {"\"1.2\"", [{:str, "1.2"}]},
      {"\"12.45\"", [{:str, "12.45"}]},
      {" \"\"", [{:str, ""}]},
      {" \"a\"", [{:str, "a"}]},
      {" \"baz\"", [{:str, "baz"}]},
      {" \"1\"", [{:str, "1"}]},
      {" \"12\"", [{:str, "12"}]},
      {" \"1.2\"", [{:str, "1.2"}]},
      {" \"12.45\"", [{:str, "12.45"}]},
      {"\n\"\"", [{:str, ""}]},
      {"\n\"a\"", [{:str, "a"}]},
      {"\n\"baz\"", [{:str, "baz"}]},
      {"\n\"1\"", [{:str, "1"}]},
      {"\n\"12\"", [{:str, "12"}]},
      {"\n\"1.2\"", [{:str, "1.2"}]},
      {"\n\"12.45\"", [{:str, "12.45"}]},
      {"\n\"hello\nworld!\"", [{:str, "hello\nworld!"}]}
    ]

    @test_failure_cases [
      {"\"a", {:unexpected_token, %{line: 0, col: 0}}},
      {"\n  \"foo", {:unexpected_token, %{line: 1, col: 2}}}
    ]

    Enum.each(@test_success_cases, fn {input, expected_output} ->
      test "`#{input}`" do
        assert {:ok, postfix} = Parser.parse(unquote(input))

        assert Enum.map(postfix, fn %{token: token} -> token end) ==
                 unquote(Macro.escape(expected_output))
      end
    end)

    Enum.each(@test_failure_cases, fn {input, expected_output} ->
      test "`#{input}`" do
        assert {:error, {reason, pos}} = Parser.parse(unquote(input))
        assert {^reason, ^pos} = unquote(Macro.escape(expected_output))
      end
    end)
  end

  describe "parse/1 for variable" do
    @test_success_cases [
      {"x", [{:var, :x}]},
      {"baz", [{:var, :baz}]},
      {"  x ", [{:var, :x}]},
      {" baz ", [{:var, :baz}]}
    ]

    Enum.each(@test_success_cases, fn {input, expected_output} ->
      test "`#{input}`" do
        assert {:ok, postfix} = Parser.parse(unquote(input))

        assert Enum.map(postfix, fn %{token: token} -> token end) ==
                 unquote(Macro.escape(expected_output))
      end
    end)
  end

  describe "parse/1 for function" do
    @test_success_cases [
      {"f()", [{:fun, %{name: :f, arity: 0}}]},
      {"foo()", [{:fun, %{name: :foo, arity: 0}}]},
      {"baz()", [{:fun, %{name: :baz, arity: 0}}]},
      {"f( )", [{:fun, %{name: :f, arity: 0}}]},
      {"foo(  )", [{:fun, %{name: :foo, arity: 0}}]},
      {"baz(   )", [{:fun, %{name: :baz, arity: 0}}]},
      {"f(1)", [{:num, 1}, {:fun, %{name: :f, arity: 1}}]},
      {"f(0.5)", [{:num, 0.5}, {:fun, %{name: :f, arity: 1}}]},
      {"f(\"baz\")", [{:str, "baz"}, {:fun, %{name: :f, arity: 1}}]},
      {"f(x)", [{:var, :x}, {:fun, %{name: :f, arity: 1}}]},
      {
        "f(1, 2)",
        [{:num, 1}, {:num, 2}, {:fun, %{name: :f, arity: 2}}]
      },
      {
        "f(0.5, 15.24)",
        [{:num, 0.5}, {:num, 15.24}, {:fun, %{name: :f, arity: 2}}]
      },
      {
        "f(\"foo\", \"baz\")",
        [{:str, "foo"}, {:str, "baz"}, {:fun, %{name: :f, arity: 2}}]
      },
      {
        "f(x, y)",
        [{:var, :x}, {:var, :y}, {:fun, %{name: :f, arity: 2}}]
      },
      {
        "f(g())",
        [{:fun, %{name: :g, arity: 0}}, {:fun, %{name: :f, arity: 1}}]
      },
      {
        "f(g(1))",
        [
          {:num, 1},
          {:fun, %{name: :g, arity: 1}},
          {:fun, %{name: :f, arity: 1}}
        ]
      },
      {
        "f(g(0.5))",
        [
          {:num, 0.5},
          {:fun, %{name: :g, arity: 1}},
          {:fun, %{name: :f, arity: 1}}
        ]
      },
      {
        "f(g(\"baz\"))",
        [
          {:str, "baz"},
          {:fun, %{name: :g, arity: 1}},
          {:fun, %{name: :f, arity: 1}}
        ]
      },
      {
        "f(g(x))",
        [
          {:var, :x},
          {:fun, %{name: :g, arity: 1}},
          {:fun, %{name: :f, arity: 1}}
        ]
      },
      {
        "f(g(1), 2)",
        [
          {:num, 1},
          {:fun, %{name: :g, arity: 1}},
          {:num, 2},
          {:fun, %{name: :f, arity: 2}}
        ]
      },
      {
        "f(g(0.5), 1.15)",
        [
          {:num, 0.5},
          {:fun, %{name: :g, arity: 1}},
          {:num, 1.15},
          {:fun, %{name: :f, arity: 2}}
        ]
      },
      {
        "f(g(\"foo\"), \"baz\")",
        [
          {:str, "foo"},
          {:fun, %{name: :g, arity: 1}},
          {:str, "baz"},
          {:fun, %{name: :f, arity: 2}}
        ]
      },
      {
        "f(g(x), my_var)",
        [
          {:var, :x},
          {:fun, %{name: :g, arity: 1}},
          {:var, :my_var},
          {:fun, %{name: :f, arity: 2}}
        ]
      },
      {
        "f(g1(1), g2())",
        [
          {:num, 1},
          {:fun, %{name: :g1, arity: 1}},
          {:fun, %{name: :g2, arity: 0}},
          {:fun, %{name: :f, arity: 2}}
        ]
      }
    ]

    Enum.each(@test_success_cases, fn {input, expected_output} ->
      test "`#{input}`" do
        assert {:ok, postfix} = Parser.parse(unquote(input))

        assert Enum.map(postfix, fn %{token: token} -> token end) ==
                 unquote(Macro.escape(expected_output))
      end
    end)
  end

  describe "parse/1 for unary + and -" do
    @test_success_cases [
      {"-1", [{:num, 1}, :neg]},
      {"- 1", [{:num, 1}, :neg]},
      {"-12", [{:num, 12}, :neg]},
      {"- 12", [{:num, 12}, :neg]},
      {"-1.2", [{:num, 1.2}, :neg]},
      {"- 1.2", [{:num, 1.2}, :neg]},
      {"+1", [{:num, 1}, :pos]},
      {"+ 1", [{:num, 1}, :pos]},
      {"+12", [{:num, 12}, :pos]},
      {"+ 12", [{:num, 12}, :pos]},
      {"+1.2", [{:num, 1.2}, :pos]},
      {"+ 1.2", [{:num, 1.2}, :pos]},
      {
        "f(-1)",
        [
          {:num, 1},
          :neg,
          {:fun, %{name: :f, arity: 1}}
        ]
      },
      {
        "f(+1)",
        [
          {:num, 1},
          :pos,
          {:fun, %{name: :f, arity: 1}}
        ]
      },
      {
        "f(-0.5)",
        [
          {:num, 0.5},
          :neg,
          {:fun, %{name: :f, arity: 1}}
        ]
      },
      {
        "f(+0.5)",
        [
          {:num, 0.5},
          :pos,
          {:fun, %{name: :f, arity: 1}}
        ]
      }
    ]

    Enum.each(@test_success_cases, fn {input, expected_output} ->
      test "`#{input}`" do
        assert {:ok, postfix} = Parser.parse(unquote(input))

        assert Enum.map(postfix, fn %{token: token} -> token end) ==
                 unquote(Macro.escape(expected_output))
      end
    end)
  end

  describe "parse/1 dot operator" do
    @test_success_cases [
      {"foo.bar", [{:var, :foo}, {:var, :bar}, :dot]},
      {"r.obj.owner", [{:var, :r}, {:var, :obj}, :dot, {:var, :owner}, :dot]}
    ]

    Enum.each(@test_success_cases, fn {input, expected_output} ->
      test "`#{input}`" do
        assert {:ok, postfix} = Parser.parse(unquote(input))

        assert Enum.map(postfix, fn %{token: token} -> token end) ==
                 unquote(Macro.escape(expected_output))
      end
    end)
  end

  describe "parse/1 integer binary arithmetic" do
    @test_success_cases [
      {"1+2", [{:num, 1}, {:num, 2}, :add]},
      {"(1+2)", [{:num, 1}, {:num, 2}, :add]},
      {"1 + 2", [{:num, 1}, {:num, 2}, :add]},
      {"(1 + 2)", [{:num, 1}, {:num, 2}, :add]},
      {"1-2", [{:num, 1}, {:num, 2}, :sub]},
      {"(1-2)", [{:num, 1}, {:num, 2}, :sub]},
      {"1 - 2", [{:num, 1}, {:num, 2}, :sub]},
      {"(1 - 2)", [{:num, 1}, {:num, 2}, :sub]},
      {"1*2", [{:num, 1}, {:num, 2}, :mul]},
      {"(1*2)", [{:num, 1}, {:num, 2}, :mul]},
      {"1 * 2", [{:num, 1}, {:num, 2}, :mul]},
      {"(1 * 2)", [{:num, 1}, {:num, 2}, :mul]},
      {"1/2", [{:num, 1}, {:num, 2}, :div]},
      {"(1/2)", [{:num, 1}, {:num, 2}, :div]},
      {"1 / 2", [{:num, 1}, {:num, 2}, :div]},
      {"(1 / 2)", [{:num, 1}, {:num, 2}, :div]},
      {"-10+12", [{:num, 10}, :neg, {:num, 12}, :add]},
      {"-10-12", [{:num, 10}, :neg, {:num, 12}, :sub]},
      {"-10*12", [{:num, 10}, :neg, {:num, 12}, :mul]},
      {"-10/12", [{:num, 10}, :neg, {:num, 12}, :div]},
      {"- 10 + 12", [{:num, 10}, :neg, {:num, 12}, :add]},
      {"- 10 - 12", [{:num, 10}, :neg, {:num, 12}, :sub]},
      {"- 10 * 12", [{:num, 10}, :neg, {:num, 12}, :mul]},
      {"- 10 / 12", [{:num, 10}, :neg, {:num, 12}, :div]},
      {"(-10) + 12", [{:num, 10}, :neg, {:num, 12}, :add]},
      {"(-10) - 12", [{:num, 10}, :neg, {:num, 12}, :sub]},
      {"(-10) * 12", [{:num, 10}, :neg, {:num, 12}, :mul]},
      {"(-10) / 12", [{:num, 10}, :neg, {:num, 12}, :div]},
      {"+10+35", [{:num, 10}, :pos, {:num, 35}, :add]},
      {"+10-35", [{:num, 10}, :pos, {:num, 35}, :sub]},
      {"+10*35", [{:num, 10}, :pos, {:num, 35}, :mul]},
      {"+10/35", [{:num, 10}, :pos, {:num, 35}, :div]},
      {"+ 10 + 35", [{:num, 10}, :pos, {:num, 35}, :add]},
      {"+ 10 - 35", [{:num, 10}, :pos, {:num, 35}, :sub]},
      {"+ 10 * 35", [{:num, 10}, :pos, {:num, 35}, :mul]},
      {"+ 10 / 35", [{:num, 10}, :pos, {:num, 35}, :div]}
    ]

    Enum.each(@test_success_cases, fn {input, expected_output} ->
      test "`#{input}`" do
        assert {:ok, postfix} = Parser.parse(unquote(input))

        assert Enum.map(postfix, fn %{token: token} -> token end) ==
                 unquote(Macro.escape(expected_output))
      end
    end)
  end

  describe "parse/1 float binary arithmetic" do
    @test_success_cases [
      {"0.5 + 12.15", [{:num, 0.5}, {:num, 12.15}, :add]},
      {"0.5 - 12.15", [{:num, 0.5}, {:num, 12.15}, :sub]},
      {"0.5 * 12.15", [{:num, 0.5}, {:num, 12.15}, :mul]},
      {"0.5 / 12.15", [{:num, 0.5}, {:num, 12.15}, :div]},
      {"-0.5 + 12.15", [{:num, 0.5}, :neg, {:num, 12.15}, :add]},
      {"-0.5 - 12.15", [{:num, 0.5}, :neg, {:num, 12.15}, :sub]},
      {"-0.5 * 12.15", [{:num, 0.5}, :neg, {:num, 12.15}, :mul]},
      {"-0.5 / 12.15", [{:num, 0.5}, :neg, {:num, 12.15}, :div]},
      {"+0.5 + 12.15", [{:num, 0.5}, :pos, {:num, 12.15}, :add]},
      {"+0.5 - 12.15", [{:num, 0.5}, :pos, {:num, 12.15}, :sub]},
      {"+0.5 * 12.15", [{:num, 0.5}, :pos, {:num, 12.15}, :mul]},
      {"+0.5 / 12.15", [{:num, 0.5}, :pos, {:num, 12.15}, :div]}
    ]

    Enum.each(@test_success_cases, fn {input, expected_output} ->
      test "`#{input}`" do
        assert {:ok, postfix} = Parser.parse(unquote(input))

        assert Enum.map(postfix, fn %{token: token} -> token end) ==
                 unquote(Macro.escape(expected_output))
      end
    end)
  end

  describe "parse/1 variable binary arithmetic" do
    @test_success_cases [
      {"x + y", [{:var, :x}, {:var, :y}, :add]},
      {"x - y", [{:var, :x}, {:var, :y}, :sub]},
      {"x * y", [{:var, :x}, {:var, :y}, :mul]},
      {"x / y", [{:var, :x}, {:var, :y}, :div]},
      {"-x + y", [{:var, :x}, :neg, {:var, :y}, :add]},
      {"-x - y", [{:var, :x}, :neg, {:var, :y}, :sub]},
      {"-x * y", [{:var, :x}, :neg, {:var, :y}, :mul]},
      {"-x / y", [{:var, :x}, :neg, {:var, :y}, :div]},
      {"+x + y", [{:var, :x}, :pos, {:var, :y}, :add]},
      {"+x - y", [{:var, :x}, :pos, {:var, :y}, :sub]},
      {"+x * y", [{:var, :x}, :pos, {:var, :y}, :mul]},
      {"+x / y", [{:var, :x}, :pos, {:var, :y}, :div]}
    ]

    Enum.each(@test_success_cases, fn {input, expected_output} ->
      test "`#{input}`" do
        assert {:ok, postfix} = Parser.parse(unquote(input))

        assert Enum.map(postfix, fn %{token: token} -> token end) ==
                 unquote(Macro.escape(expected_output))
      end
    end)
  end

  describe "parse/1 for binary relational expression" do
    @test_success_cases [
      {"1 > 2", [{:num, 1}, {:num, 2}, :gt]},
      {"1 >= 2", [{:num, 1}, {:num, 2}, :ge]},
      {"1 < 2", [{:num, 1}, {:num, 2}, :lt]},
      {"1 <= 2", [{:num, 1}, {:num, 2}, :le]},
      {"1 == 2", [{:num, 1}, {:num, 2}, :eq]},
      {"1 != 2", [{:num, 1}, {:num, 2}, :ne]},
      {"-1 > 2", [{:num, 1}, :neg, {:num, 2}, :gt]},
      {"-1 >= 2", [{:num, 1}, :neg, {:num, 2}, :ge]},
      {"-1 < 2", [{:num, 1}, :neg, {:num, 2}, :lt]},
      {"-1 <= 2", [{:num, 1}, :neg, {:num, 2}, :le]},
      {"-1 == 2", [{:num, 1}, :neg, {:num, 2}, :eq]},
      {"-1 != 2", [{:num, 1}, :neg, {:num, 2}, :ne]},
      {"x > 2", [{:var, :x}, {:num, 2}, :gt]},
      {"x >= 2", [{:var, :x}, {:num, 2}, :ge]},
      {"x < 2", [{:var, :x}, {:num, 2}, :lt]},
      {"x <= 2", [{:var, :x}, {:num, 2}, :le]},
      {"x == 2", [{:var, :x}, {:num, 2}, :eq]},
      {"x != 2", [{:var, :x}, {:num, 2}, :ne]},
      {"x > y", [{:var, :x}, {:var, :y}, :gt]},
      {"x >= y", [{:var, :x}, {:var, :y}, :ge]},
      {"x < y", [{:var, :x}, {:var, :y}, :lt]},
      {"x <= y", [{:var, :x}, {:var, :y}, :le]},
      {"x == y", [{:var, :x}, {:var, :y}, :eq]},
      {"x != y", [{:var, :x}, {:var, :y}, :ne]}
    ]

    Enum.each(@test_success_cases, fn {input, expected_output} ->
      test "`#{input}`" do
        assert {:ok, postfix} = Parser.parse(unquote(input))

        assert Enum.map(postfix, fn %{token: token} -> token end) ==
                 unquote(Macro.escape(expected_output))
      end
    end)
  end

  describe "parse/1 for complex arithmetic expression" do
    @test_success_cases [
      {"1 + 2 + 3", [{:num, 1}, {:num, 2}, :add, {:num, 3}, :add]},
      {"1 + 2 - 3", [{:num, 1}, {:num, 2}, :add, {:num, 3}, :sub]},
      {"1 + 2 * 3", [{:num, 1}, {:num, 2}, {:num, 3}, :mul, :add]},
      {"1 + 2 / 3", [{:num, 1}, {:num, 2}, {:num, 3}, :div, :add]},
      {"(1 + 2) + 3", [{:num, 1}, {:num, 2}, :add, {:num, 3}, :add]},
      {"(1 + 2) - 3", [{:num, 1}, {:num, 2}, :add, {:num, 3}, :sub]},
      {"(1 + 2) * 3", [{:num, 1}, {:num, 2}, :add, {:num, 3}, :mul]},
      {"(1 + 2) / 3", [{:num, 1}, {:num, 2}, :add, {:num, 3}, :div]},
      {
        "3 + 4 * 2 / ( 1 - 5 )",
        [
          {:num, 3},
          {:num, 4},
          {:num, 2},
          :mul,
          {:num, 1},
          {:num, 5},
          :sub,
          :div,
          :add
        ]
      }
    ]

    Enum.each(@test_success_cases, fn {input, expected_output} ->
      test "`#{input}`" do
        assert {:ok, postfix} = Parser.parse(unquote(input))

        assert Enum.map(postfix, fn %{token: token} -> token end) ==
                 unquote(Macro.escape(expected_output))
      end
    end)
  end

  describe "parse/1 for matcher expression" do
    @test_success_cases [
      {
        "b(r.sub, p.sub) && g2(r.obj, p.obj) && r.act == p.act",
        [
          {:var, :r},
          {:var, :sub},
          :dot,
          {:var, :p},
          {:var, :sub},
          :dot,
          {:fun, %{name: :b, arity: 2}},
          {:var, :r},
          {:var, :obj},
          :dot,
          {:var, :p},
          {:var, :obj},
          :dot,
          {:fun, %{name: :g2, arity: 2}},
          :and,
          {:var, :r},
          {:var, :act},
          :dot,
          {:var, :p},
          {:var, :act},
          :dot,
          :eq,
          :and
        ]
      },
      {
        "r.sub == p.sub && r.obj == p.obj && r.act == p.act ||
        r.sub == \"root\"",
        [
          {:var, :r},
          {:var, :sub},
          :dot,
          {:var, :p},
          {:var, :sub},
          :dot,
          :eq,
          {:var, :r},
          {:var, :obj},
          :dot,
          {:var, :p},
          {:var, :obj},
          :dot,
          :eq,
          :and,
          {:var, :r},
          {:var, :act},
          :dot,
          {:var, :p},
          {:var, :act},
          :dot,
          :eq,
          :and,
          {:var, :r},
          {:var, :sub},
          :dot,
          {:str, "root"},
          :eq,
          :or
        ]
      },
      {
        "some( where (p.eft == \"allow\") )",
        [
          {:var, :p},
          {:var, :eft},
          :dot,
          {:str, "allow"},
          :eq,
          {:fun, %{name: :where, arity: 1}},
          {:fun, %{name: :some, arity: 1}}
        ]
      }
    ]

    Enum.each(@test_success_cases, fn {input, expected_output} ->
      test "`#{input}`" do
        assert {:ok, postfix} = Parser.parse(unquote(input))

        assert Enum.map(postfix, fn %{token: token} -> token end) ==
                 unquote(Macro.escape(expected_output))
      end
    end)
  end
end
