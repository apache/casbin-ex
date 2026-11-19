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

defmodule Casbin.Enforcer.MatcherFunctionsTest do
  use ExUnit.Case, async: true
  alias Casbin.Enforcer

  describe "key_match?/2" do
    @test_cases [
      {"/foo", "/foo", true},
      {"/foo", "/foo*", true},
      {"/foo", "/foo/*", false},
      {"/foo/bar", "/foo", false},
      {"/foo/bar", "/foo*", true},
      {"/foo/bar", "/foo/*", true},
      {"/foobar", "/foo", false},
      {"/foobar", "/foo*", true},
      {"/foobar", "/foo/*", false}
    ]

    Enum.each(@test_cases, fn {key1, key2, expected} ->
      test "key_match?(#{inspect(key1)}, #{inspect(key2)}) returns #{expected}" do
        assert Enforcer.key_match?(unquote(key1), unquote(key2)) === unquote(expected)
      end
    end)
  end

  describe "key_get/2" do
    @test_cases [
      {"/foo", "/foo", ""},
      {"/foo", "/foo*", ""},
      {"/foo", "/foo/*", ""},
      {"/foo/bar", "/foo", ""},
      {"/foo/bar", "/foo*", "/bar"},
      {"/foo/bar", "/foo/*", "bar"},
      {"/foobar", "/foo", ""},
      {"/foobar", "/foo*", "bar"},
      {"/foobar", "/foo/*", ""}
    ]

    Enum.each(@test_cases, fn {key1, key2, expected} ->
      test "key_get(#{inspect(key1)}, #{inspect(key2)}) returns #{inspect(expected)}" do
        assert Enforcer.key_get(unquote(key1), unquote(key2)) === unquote(expected)
      end
    end)
  end

  describe "key_get2/3" do
    @test_cases [
      {"/foo", "/foo", "id", ""},
      {"/foo", "/foo*", "id", ""},
      {"/foo", "/foo/*", "id", ""},
      {"/foo/bar", "/foo", "id", ""},
      {"/foo/bar", "/foo*", "id", ""},
      {"/foo/bar", "/foo/*", "id", ""},
      {"/foobar", "/foo", "id", ""},
      {"/foobar", "/foo*", "id", ""},
      {"/foobar", "/foo/*", "id", ""},
      {"/", "/:resource", "resource", ""},
      {"/resource1", "/:resource", "resource", "resource1"},
      {"/myid", "/:id/using/:resId", "id", ""},
      {"/myid/using/myresid", "/:id/using/:resId", "id", "myid"},
      {"/myid/using/myresid", "/:id/using/:resId", "resId", "myresid"},
      {"/proxy/myid", "/proxy/:id/*", "id", ""},
      {"/proxy/myid/", "/proxy/:id/*", "id", "myid"},
      {"/proxy/myid/res", "/proxy/:id/*", "id", "myid"},
      {"/proxy/myid/res/res2", "/proxy/:id/*", "id", "myid"},
      {"/proxy/myid/res/res2/res3", "/proxy/:id/*", "id", "myid"},
      {"/proxy/", "/proxy/:id/*", "id", ""},
      {"/alice", "/:id", "id", "alice"},
      {"/alice/all", "/:id/all", "id", "alice"},
      {"/alice", "/:id/all", "id", ""},
      {"/alice/all", "/:id", "id", ""}
    ]

    Enum.each(@test_cases, fn {key1, key2, path_var, expected} ->
      test "key_get2(#{inspect(key1)}, #{inspect(key2)}, #{inspect(path_var)}) returns #{inspect(expected)}" do
        assert Enforcer.key_get2(unquote(key1), unquote(key2), unquote(path_var)) ===
                 unquote(expected)
      end
    end)
  end

  describe "key_match3?/2" do
    @test_cases [
      {"/foo", "/foo", true},
      {"/foo", "/foo*", true},
      {"/foo", "/foo/*", false},
      {"/foo/bar", "/foo", false},
      {"/foo/bar", "/foo*", false},
      {"/foo/bar", "/foo/*", true},
      {"/foobar", "/foo", false},
      {"/foobar", "/foo*", false},
      {"/foobar", "/foo/*", false},
      {"/", "/{resource}", false},
      {"/resource1", "/{resource}", true},
      {"/myid", "/{id}/using/{resId}", false},
      {"/myid/using/myresid", "/{id}/using/{resId}", true},
      {"/proxy/myid", "/proxy/{id}/*", false},
      {"/proxy/myid/", "/proxy/{id}/*", true},
      {"/proxy/myid/res", "/proxy/{id}/*", true},
      {"/proxy/myid/res/res2", "/proxy/{id}/*", true},
      {"/proxy/myid/res/res2/res3", "/proxy/{id}/*", true},
      {"/proxy/", "/proxy/{id}/*", false}
    ]

    Enum.each(@test_cases, fn {key1, key2, expected} ->
      test "key_match3?(#{inspect(key1)}, #{inspect(key2)}) returns #{expected}" do
        assert Enforcer.key_match3?(unquote(key1), unquote(key2)) === unquote(expected)
      end
    end)
  end

  describe "key_match4?/2" do
    @test_cases [
      {"/parent/123/child/123", "/parent/{id}/child/{id}", true},
      {"/parent/123/child/456", "/parent/{id}/child/{id}", false},
      {"/parent/123/child/123", "/parent/{id}/child/{another_id}", true},
      {"/parent/123/child/456", "/parent/{id}/child/{another_id}", true},
      {"/parent/123/child/123/book/123", "/parent/{id}/child/{id}/book/{id}", true},
      {"/parent/123/child/123/book/456", "/parent/{id}/child/{id}/book/{id}", false},
      {"/parent/123/child/456/book/123", "/parent/{id}/child/{id}/book/{id}", false},
      {"/parent/123/child/456/book/", "/parent/{id}/child/{id}/book/{id}", false},
      {"/parent/123/child/456", "/parent/{id}/child/{id}/book/{id}", false}
    ]

    Enum.each(@test_cases, fn {key1, key2, expected} ->
      test "key_match4?(#{inspect(key1)}, #{inspect(key2)}) returns #{expected}" do
        assert Enforcer.key_match4?(unquote(key1), unquote(key2)) === unquote(expected)
      end
    end)
  end

  describe "ip_match?/2" do
    @test_cases [
      {"192.168.2.123", "192.168.2.0/24", true},
      {"192.168.2.123", "192.168.3.0/24", false},
      {"192.168.2.123", "192.168.2.0/16", true},
      {"192.168.2.123", "192.168.2.123", true},
      {"192.168.2.123", "192.168.2.123/32", true},
      {"10.0.0.11", "10.0.0.0/8", true},
      {"11.0.0.123", "10.0.0.0/8", false}
    ]

    Enum.each(@test_cases, fn {ip1, ip2, expected} ->
      test "ip_match?(#{inspect(ip1)}, #{inspect(ip2)}) returns #{expected}" do
        assert Enforcer.ip_match?(unquote(ip1), unquote(ip2)) === unquote(expected)
      end
    end)
  end

  describe "glob_match?/2" do
    @test_cases [
      {"/foo", "/foo", true},
      {"/foo", "/foo*", true},
      {"/foo", "/foo/*", false},
      {"/foo/bar", "/foo", false},
      {"/foo/bar", "/foo*", false},
      {"/foo/bar", "/foo/*", true},
      {"/foobar", "/foo", false},
      {"/foobar", "/foo*", true},
      {"/foobar", "/foo/*", false},
      {"/foo", "*/foo", true},
      {"/foo", "*/foo*", true},
      {"/foo", "*/foo/*", false},
      {"/foo/bar", "*/foo", false},
      {"/foo/bar", "*/foo*", false},
      {"/foo/bar", "*/foo/*", true},
      {"/foobar", "*/foo", false},
      {"/foobar", "*/foo*", true},
      {"/foobar", "*/foo/*", false}
    ]

    Enum.each(@test_cases, fn {key1, key2, expected} ->
      test "glob_match?(#{inspect(key1)}, #{inspect(key2)}) returns #{expected}" do
        assert Enforcer.glob_match?(unquote(key1), unquote(key2)) === unquote(expected)
      end
    end)
  end
end
