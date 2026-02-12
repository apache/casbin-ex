# Testing with Async Mode

This guide explains how to write Casbin tests that can safely run with `async: true`, preventing race conditions and test interference.

## The Problem

When using EnforcerServer with a fixed enforcer name, all tests share the same global state, causing race conditions in async tests:

```elixir
# ❌ This fails with async: true
defmodule MyApp.AclTest do
  use ExUnit.Case, async: true  # Tests interfere with each other
  
  @enforcer_name "my_enforcer"
  
  setup do
    # All tests use the same enforcer!
    EnforcerServer.add_policy(@enforcer_name, {:p, ["admin", "data", "read"]})
    
    on_exit(fn ->
      # This cleanup affects ALL running tests
      EnforcerServer.remove_policy(@enforcer_name, {:p, ["admin", "data", "read"]})
    end)
  end
  
  test "admin has permissions" do
    # Another test's cleanup might delete this policy mid-test!
    assert EnforcerServer.allow?(@enforcer_name, ["admin", "data", "read"])
  end
end
```

**Symptoms:**
- `Policies.list()` returns `[]` even after adding policies
- `add_policy` returns `{:error, :already_existed}` but policies aren't in memory
- Tests pass individually but fail when run together
- Tests fail randomly depending on execution order

## Solution 1: Use Casbin.AsyncCase (Recommended)

The easiest solution is to use `Casbin.AsyncCase`, which automatically handles enforcer isolation:

```elixir
# ✅ This works with async: true
defmodule MyApp.AclTest do
  use Casbin.AsyncCase, async: true
  
  alias Casbin.EnforcerServer
  
  @config_file "path/to/model.conf"
  
  setup do
    # Creates a unique enforcer for THIS test
    enforcer_name = start_test_enforcer(@config_file)
    
    {:ok, enforcer_name: enforcer_name}
  end
  
  test "admin has permissions", %{enforcer_name: ename} do
    EnforcerServer.add_policy(ename, {:p, ["admin", "data", "read"]})
    assert EnforcerServer.allow?(ename, ["admin", "data", "read"])
  end
  
  test "user has limited permissions", %{enforcer_name: ename} do
    # This test has its own isolated enforcer
    EnforcerServer.add_policy(ename, {:p, ["user", "data", "read"]})
    assert EnforcerServer.allow?(ename, ["user", "data", "read"])
    assert EnforcerServer.allow?(ename, ["user", "data", "write"]) == false
  end
end
```

### With Pre-loaded Policies

```elixir
defmodule MyApp.PermissionsTest do
  use Casbin.AsyncCase, async: true
  
  @config_file Application.app_dir(:my_app, "priv/casbin/model.conf")
  @policy_file Application.app_dir(:my_app, "priv/casbin/policy.csv")
  
  setup do
    ename = start_test_enforcer(@config_file)
    
    # Load pre-defined policies
    :ok = EnforcerServer.load_policies(ename, @policy_file)
    
    {:ok, enforcer_name: ename}
  end
  
  test "existing policies work", %{enforcer_name: ename} do
    assert EnforcerServer.allow?(ename, ["alice", "blog_post", "read"])
  end
  
  test "can add new policies", %{enforcer_name: ename} do
    :ok = EnforcerServer.add_policy(ename, {:p, ["bob", "data", "write"]})
    assert EnforcerServer.allow?(ename, ["bob", "data", "write"])
  end
end
```

## Solution 2: Use Casbin.TestHelper (More Control)

For more control, use `Casbin.TestHelper` functions directly:

```elixir
defmodule MyApp.CustomAclTest do
  use ExUnit.Case, async: true
  
  import Casbin.TestHelper
  alias Casbin.{EnforcerSupervisor, EnforcerServer}
  
  @config_file "path/to/model.conf"
  
  setup do
    # Generate a unique enforcer name
    ename = unique_enforcer_name("custom_acl")
    
    # Start the enforcer
    {:ok, _pid} = EnforcerSupervisor.start_enforcer(ename, @config_file)
    
    # Register cleanup
    on_exit(fn -> cleanup_enforcer(ename) end)
    
    {:ok, enforcer_name: ename}
  end
  
  test "can use custom enforcer", %{enforcer_name: ename} do
    EnforcerServer.add_policy(ename, {:p, ["alice", "data", "read"]})
    assert EnforcerServer.allow?(ename, ["alice", "data", "read"])
  end
end
```

### Using create_test_enforcer

For even less boilerplate:

```elixir
defmodule MyApp.MinimalTest do
  use ExUnit.Case, async: true
  
  import Casbin.TestHelper
  alias Casbin.EnforcerServer
  
  test "quick test with enforcer" do
    {:ok, ename} = create_test_enforcer("path/to/model.conf", "minimal")
    
    EnforcerServer.add_policy(ename, {:p, ["user", "resource", "action"]})
    assert EnforcerServer.allow?(ename, ["user", "resource", "action"])
  end
end
```

## Solution 3: Use async: false (Simplest, but Slower)

If you don't need parallel execution, you can disable async mode:

```elixir
# ✅ This works but runs slower
defmodule MyApp.AclTest do
  use ExUnit.Case, async: false  # Tests run sequentially
  
  @enforcer_name "my_enforcer"
  
  # Now safe to use a fixed enforcer name
end
```

**Trade-offs:**
- ✅ Simple - no code changes needed
- ❌ Slower - tests run sequentially instead of in parallel
- ❌ Doesn't scale - more tests = longer test suite runtime

## Using with EctoAdapter and SQL.Sandbox

When using `EctoAdapter` with `Ecto.Adapters.SQL.Sandbox`, you need to allow the enforcer process to access the database connection:

```elixir
defmodule MyApp.DatabaseAclTest do
  use MyApp.DataCase, async: true
  use Casbin.AsyncCase
  
  alias Casbin.{EnforcerServer, Persist.EctoAdapter}
  
  @config_file Application.app_dir(:my_app, "priv/casbin/model.conf")
  
  setup do
    # Check out a database connection
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)
    
    # Start isolated enforcer
    ename = start_test_enforcer(@config_file)
    
    # Allow enforcer process to access the database
    case Registry.lookup(Casbin.EnforcerRegistry, ename) do
      [{pid, _}] -> 
        Ecto.Adapters.SQL.Sandbox.allow(MyApp.Repo, self(), pid)
      [] -> 
        :ok
    end
    
    # Set up the adapter
    adapter = EctoAdapter.new(MyApp.Repo)
    :ok = EnforcerServer.set_persist_adapter(ename, adapter)
    
    {:ok, enforcer_name: ename}
  end
  
  test "policies persist to database", %{enforcer_name: ename} do
    :ok = EnforcerServer.add_policy(ename, {:p, ["user", "data", "read"]})
    
    # Policies are automatically saved with EctoAdapter
    assert EnforcerServer.allow?(ename, ["user", "data", "read"])
    
    # Verify it was persisted
    policies = EnforcerServer.list_policies(ename, %{sub: "user"})
    assert length(policies) == 1
  end
end
```

For transactional tests with Ecto, see the [Sandbox Testing Guide](sandbox_testing.md).

## Best Practices

### 1. Always Use Unique Enforcer Names

```elixir
# ❌ Bad - shared state
@enforcer_name "my_enforcer"

# ✅ Good - unique per test
ename = unique_enforcer_name("my_test")
```

### 2. Clean Up Enforcers

```elixir
# Always register cleanup
on_exit(fn -> cleanup_enforcer(ename) end)

# Or use AsyncCase/create_test_enforcer which handles this automatically
```

### 3. Use Module Attributes for Config Files

```elixir
defmodule MyApp.AclTest do
  use Casbin.AsyncCase, async: true
  
  # ✅ Good - easy to update
  @config_file Application.app_dir(:my_app, "priv/casbin/model.conf")
  @policy_file Application.app_dir(:my_app, "priv/casbin/policy.csv")
  
  setup do
    ename = start_test_enforcer(@config_file)
    :ok = EnforcerServer.load_policies(ename, @policy_file)
    {:ok, enforcer_name: ename}
  end
end
```

### 4. Organize Tests by Resource

```elixir
# Organize by what you're testing
defmodule MyApp.BlogPermissionsTest do
  use Casbin.AsyncCase, async: true
  # Tests for blog post permissions
end

defmodule MyApp.DataPermissionsTest do
  use Casbin.AsyncCase, async: true
  # Tests for data permissions
end
```

## Troubleshooting

### "Policy not found" errors in async tests

**Problem:** Policies disappear mid-test or `list_policies` returns `[]`

**Solution:** Make sure each test uses a unique enforcer name:

```elixir
# Use AsyncCase or unique_enforcer_name()
ename = unique_enforcer_name("my_test")
```

### "{:error, :already_existed}" but policy isn't there

**Problem:** `add_policy` fails with `:already_existed` but the policy doesn't show in `list_policies`

**Solution:** Another test is using the same enforcer. Use unique names:

```elixir
# In setup
ename = start_test_enforcer(@config_file)  # Unique per test
```

### Tests pass individually but fail together

**Problem:** `mix test path/to/test.exs` passes but `mix test` fails

**Solution:** Tests are sharing state. Use `async: true` with unique enforcers:

```elixir
use Casbin.AsyncCase, async: true
```

### Database connection errors with EctoAdapter

**Problem:** `DBConnection.ConnectionError` when using `EctoAdapter`

**Solution:** Allow the enforcer process to access the connection:

```elixir
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)
  ename = start_test_enforcer(@config_file)
  
  [{pid, _}] = Registry.lookup(Casbin.EnforcerRegistry, ename)
  Ecto.Adapters.SQL.Sandbox.allow(MyApp.Repo, self(), pid)
  
  {:ok, enforcer_name: ename}
end
```

## Migration Guide

If you have existing tests using a fixed enforcer name:

### Before

```elixir
defmodule MyApp.AclTest do
  use ExUnit.Case  # async: false by default
  
  @enforcer_name "my_enforcer"
  
  test "admin permissions" do
    EnforcerServer.add_policy(@enforcer_name, {:p, ["admin", "data", "read"]})
    assert EnforcerServer.allow?(@enforcer_name, ["admin", "data", "read"])
  end
end
```

### After

```elixir
defmodule MyApp.AclTest do
  use Casbin.AsyncCase, async: true
  
  @config_file "path/to/model.conf"
  
  setup do
    {:ok, enforcer_name: start_test_enforcer(@config_file)}
  end
  
  test "admin permissions", %{enforcer_name: ename} do
    EnforcerServer.add_policy(ename, {:p, ["admin", "data", "read"]})
    assert EnforcerServer.allow?(ename, ["admin", "data", "read"])
  end
end
```

## Summary

- Use `Casbin.AsyncCase` for automatic enforcer isolation in async tests
- Use `Casbin.TestHelper` for more control over enforcer lifecycle
- Always use unique enforcer names to prevent race conditions
- Clean up enforcers in `on_exit` callbacks (or use AsyncCase/create_test_enforcer)
- Allow enforcer processes to access database connections when using EctoAdapter

With these patterns, you can safely run Casbin tests in parallel with `async: true`, making your test suite faster and more reliable.
