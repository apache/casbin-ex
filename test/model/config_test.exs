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

defmodule Casbin.Model.ConfigTest do
  use ExUnit.Case, async: true
  alias Casbin.Model.Config
  doctest Casbin.Model.Config

  describe "new/1" do
    test "returns the correct key-value pairs under :undefined_section" do
      assert %Config{sections: sections} =
               "../data/kv.conf"
               |> Path.expand(__DIR__)
               |> Config.new()

      assert [{:undefined_section, kvs}] = sections

      assert kvs == [
               r: "sub,obj,act",
               p: "sub,obj,act",
               e: "some(where(p.eft==allow))",
               m: "r.sub==p.sub&&r.obj==p.obj&&r.act==p.act"
             ]
    end

    test "returns correct number of sections for ACL config" do
      assert %Config{sections: sections} =
               "../data/acl.conf"
               |> Path.expand(__DIR__)
               |> Config.new()

      assert [
               request_definition: requests,
               policy_definition: policies,
               policy_effect: effects,
               matchers: matchers
             ] = sections

      assert requests == [r: "sub,obj,act"]
      assert policies == [p: "sub,obj,act"]
      assert effects == [e: "some(where(p.eft==allow))"]
      assert matchers == [m: "r.sub==p.sub&&r.obj==p.obj&&r.act==p.act"]
    end

    test "returns correct number of sections for RBAC config" do
      assert %Config{sections: sections} =
               "../data/rbac.conf"
               |> Path.expand(__DIR__)
               |> Config.new()

      assert [
               request_definition: requests,
               policy_definition: policies,
               role_definition: roles,
               policy_effect: effects,
               matchers: matchers
             ] = sections

      assert requests == [r: "sub,obj,act"]
      assert policies == [p: "sub,obj,act"]
      assert roles == [g: "_,_"]
      assert effects == [e: "some(where(p.eft==allow))"]
      assert matchers == [m: "g(r.sub,p.sub)&&r.obj==p.obj&&r.act==p.act"]
    end
  end
end
