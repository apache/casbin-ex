<!--
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

  https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
-->

# Isolating enforcers in tests (`async: true`)

An enforcer is a named, long-lived process. Every caller that passes the same
name talks to the same process and therefore to the same set of policies:

```elixir
EnforcerServer.add_policy("my_enforcer", {:p, ["alice", "blog_post", "read"]})
```

That is what you want in production, where one enforcer serves the whole
application. It is not what you want in a test suite: with `async: true`,
ExUnit runs test modules concurrently, so one test adding policies to
`"my_enforcer"` and another test removing them from `"my_enforcer"` will step
on each other. Typical symptoms are policies disappearing mid-test,
`list_policies/2` returning `[]` right after a successful `add_policy/2`, and
tests that pass on their own but fail when the suite runs.

The enforcer name is the isolation boundary. Give each test its own name and
the tests stop interfering, no matter how many run at once.

## The pattern

```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case, async: true

  alias Casbin.{EnforcerServer, EnforcerSupervisor}

  @cfile "priv/casbin/model.conf"

  setup do
    # Unique per test, so concurrent tests never share an enforcer.
    ename = "acl_test_#{:erlang.unique_integer([:positive])}"

    {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @cfile)
    on_exit(fn -> EnforcerSupervisor.stop_enforcer(ename) end)

    {:ok, ename: ename}
  end

  test "admin can read", %{ename: ename} do
    :ok = EnforcerServer.add_policy(ename, {:p, ["admin", "blog_post", "read"]})
    assert EnforcerServer.allow?(ename, ["admin", "blog_post", "read"])
  end
end
```

## Why `stop_enforcer/1` matters

Enforcer state is cached in an ETS table so that a *crashed* enforcer is
restarted with the policies it had before the crash. The cache is keyed by
enforcer name and outlives the process.

`EnforcerSupervisor.stop_enforcer/1` shuts the process down and drops that
cached state, which gives you two things:

- **No leak.** Without it, every unique name you use adds a process and an ETS
  entry that live until the VM stops. Over a large suite that adds up.
- **A clean slate.** Starting an enforcer under a name that was stopped builds
  it fresh from its configuration file. Without the stop, a new enforcer under
  a previously used name silently inherits the old policies and ignores the
  config file you passed.

It is safe to call whether or not an enforcer is running, so it needs no guard
in `on_exit/1`.

## If you must share one enforcer

Sometimes the enforcer is started once by your application supervision tree and
the name is baked into the code under test. In that case the tests touching it
cannot be async:

```elixir
use ExUnit.Case, async: false
```

`async: false` only serializes against *other* modules that are also
`async: false`, so it is a real constraint, not a formality: a shared enforcer
means the whole suite must agree not to run those tests concurrently. Prefer
making the enforcer name a parameter of the code under test so each test can
supply its own.

## Related

- [Testing with Ecto.Adapters.SQL.Sandbox and Transactions](sandbox_testing.md) —
  isolating the *database* connection an enforcer uses.
