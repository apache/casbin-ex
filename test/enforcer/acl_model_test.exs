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

defmodule Casbin.Enforcer.AclModelTest do
  use ExUnit.Case, async: true
  alias Casbin.Enforcer
  alias Casbin.Model.Policy

  @cfile "../data/acl.conf" |> Path.expand(__DIR__)
  @pfile "../data/acl.csv" |> Path.expand(__DIR__)

  setup do
    {:ok, e} = Enforcer.init(@cfile)
    e = e |> Enforcer.load_policies!(@pfile)
    {:ok, e: e}
  end

  describe "allow?/2" do
    @test_cases [
      {["alice", "blog_post", "create"], true},
      {["alice", "blog_post", "delete"], true},
      {["alice", "blog_post", "modify"], true},
      {["alice", "blog_post", "read"], true},
      {["alice", "blog_post", "foo"], false},
      {["alice", "data", "create"], false},
      {["bob", "blog_post", "read"], true},
      {["bob", "blog_post", "create"], false},
      {["bob", "blog_post", "modify"], false},
      {["bob", "blog_post", "delete"], false},
      {["bob", "blog_post", "foo"], false},
      {["peter", "blog_post", "create"], true},
      {["peter", "blog_post", "modify"], true},
      {["peter", "blog_post", "read"], true},
      {["peter", "blog_post", "delete"], false},
      {["peter", "blog_post", "foo"], false}
    ]

    Enum.each(@test_cases, fn {req, res} ->
      test "response #{res} for request #{inspect(req)}", %{e: e} do
        assert e |> Enforcer.allow?(unquote(req)) === unquote(res)
      end
    end)
  end

  describe "list_policies/2" do
    test "returns all policy rules by default", %{e: e} do
      policies = e |> Enforcer.list_policies()

      assert [
               # peter

               %Policy{
                 key: :p,
                 attrs: [sub: "peter", obj: "blog_post", act: "read", eft: "allow"]
               },
               %Policy{
                 key: :p,
                 attrs: [sub: "peter", obj: "blog_post", act: "modify", eft: "allow"]
               },
               %Policy{
                 key: :p,
                 attrs: [sub: "peter", obj: "blog_post", act: "create", eft: "allow"]
               },

               # bob

               %Policy{
                 key: :p,
                 attrs: [sub: "bob", obj: "blog_post", act: "read", eft: "allow"]
               },

               # alice

               %Policy{
                 key: :p,
                 attrs: [sub: "alice", obj: "blog_post", act: "read", eft: "allow"]
               },
               %Policy{
                 key: :p,
                 attrs: [sub: "alice", obj: "blog_post", act: "modify", eft: "allow"]
               },
               %Policy{
                 key: :p,
                 attrs: [sub: "alice", obj: "blog_post", act: "delete", eft: "allow"]
               },
               %Policy{
                 key: :p,
                 attrs: [sub: "alice", obj: "blog_post", act: "create", eft: "allow"]
               }
             ] === policies
    end

    test "returns all policy rules for alice", %{e: e} do
      policies = e |> Enforcer.list_policies(%{sub: "alice"})

      assert [
               %Policy{
                 key: :p,
                 attrs: [sub: "alice", obj: "blog_post", act: "read", eft: "allow"]
               },
               %Policy{
                 key: :p,
                 attrs: [sub: "alice", obj: "blog_post", act: "modify", eft: "allow"]
               },
               %Policy{
                 key: :p,
                 attrs: [sub: "alice", obj: "blog_post", act: "delete", eft: "allow"]
               },
               %Policy{
                 key: :p,
                 attrs: [sub: "alice", obj: "blog_post", act: "create", eft: "allow"]
               }
             ] === policies
    end

    test "returns all policy rules for bob", %{e: e} do
      policies = e |> Enforcer.list_policies(%{sub: "bob"})

      assert [
               %Policy{
                 key: :p,
                 attrs: [sub: "bob", obj: "blog_post", act: "read", eft: "allow"]
               }
             ] === policies
    end

    test "returns all policy rules for peter", %{e: e} do
      policies = e |> Enforcer.list_policies(%{sub: "peter"})

      assert [
               %Policy{
                 key: :p,
                 attrs: [sub: "peter", obj: "blog_post", act: "read", eft: "allow"]
               },
               %Policy{
                 key: :p,
                 attrs: [sub: "peter", obj: "blog_post", act: "modify", eft: "allow"]
               },
               %Policy{
                 key: :p,
                 attrs: [sub: "peter", obj: "blog_post", act: "create", eft: "allow"]
               }
             ] === policies
    end

    test "returns all policy rules where `act` is `create`", %{e: e} do
      policies = e |> Enforcer.list_policies(%{act: "create"})

      assert [
               %Policy{
                 key: :p,
                 attrs: [sub: "peter", obj: "blog_post", act: "create", eft: "allow"]
               },
               %Policy{
                 key: :p,
                 attrs: [sub: "alice", obj: "blog_post", act: "create", eft: "allow"]
               }
             ] === policies
    end

    test "returns empty list if no policy rules match given criteria",
         %{e: e} do
      assert e |> Enforcer.list_policies(%{sub: "bob", act: "create"}) === []
    end
  end
end
