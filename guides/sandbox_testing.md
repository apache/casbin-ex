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

# Testing with Ecto.Adapters.SQL.Sandbox and Transactions

This guide explains how to use Casbin-Ex with `Ecto.Adapters.SQL.Sandbox` when you need to wrap Casbin operations in database transactions.

## The Problem

When using `Ecto.Adapters.SQL.Sandbox` in checkout mode (the default), database connections are restricted to the process that checked them out. The Casbin `EnforcerServer` runs in a separate process, which causes issues when:

1. Your test wraps Casbin operations in a `Repo.transaction`
2. The transaction locks the connection to the test process
3. The `EnforcerServer` process cannot access the locked connection, even with `Sandbox.allow/3`

This results in the error:
```
** (DBConnection.ConnectionError) could not checkout the connection owned by #PID<...>
```

## Solution: Use Shared Mode

The recommended solution is to use Ecto's **shared mode** for tests that need to call Casbin within transactions:

```elixir
defmodule MyApp.RolesTest do
  use MyApp.DataCase
  use MyApp.CasbinCase

  setup do
    # Check out a connection
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)
    
    # Enable shared mode - this allows the EnforcerServer to use the connection
    Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, {:shared, self()})
    
    # Allow the EnforcerServer process to access the connection
    case Registry.lookup(Casbin.EnforcerRegistry, "my_enforcer") do
      [{enforcer_pid, _}] ->
        Ecto.Adapters.SQL.Sandbox.allow(MyApp.Repo, self(), enforcer_pid)
      [] ->
        :ok
    end
    
    :ok
  end

  test "create role with permissions in transaction" do
    permissions = [
      %{resource: "orgs", action: "read"},
      %{resource: "users", action: "read"}
    ]

    # This now works because of shared mode
    assert {:ok, :created} = 
      MyApp.Repo.transaction(fn ->
        Enum.each(permissions, fn %{resource: resource, action: action} ->
          case Casbin.EnforcerServer.add_policy("my_enforcer", {:p, ["analyst", resource, action]}) do
            :ok -> :ok
            {:error, reason} -> MyApp.Repo.rollback(reason)
          end
        end)
        
        {:ok, :created}
      end)
  end
end
```

## Important Notes

### About Shared Mode

- **Shared mode** allows multiple processes to access the same database connection
- All tests in a module using shared mode will share the connection
- This may reduce test isolation compared to the default checkout mode
- It's still safe because each test gets a clean transaction that's rolled back

### When to Use Shared Mode

Use shared mode when you need to:
- Wrap Casbin operations in application-level transactions
- Test rollback behavior with Casbin
- Test atomic operations that involve both Casbin and other database changes

### Alternative Approaches

If you don't need transactions in your tests, you can:

1. **Avoid wrapping in transactions**: Call Casbin operations directly without `Repo.transaction`
2. **Test transactions separately**: Test transaction logic separately from Casbin operations
3. **Use async: false**: Use `async: false` to run tests serially with shared connections

## Example Test Module

Here's a complete example of a test module using shared mode:

```elixir
defmodule MyApp.Authorization.RolesTest do
  use MyApp.DataCase, async: false  # async: false for shared mode
  
  alias MyApp.Repo
  alias MyApp.Authorization.Roles
  
  setup do
    # Set up sandbox in shared mode
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    
    # Allow EnforcerServer to access the connection
    case Registry.lookup(Casbin.EnforcerRegistry, "my_enforcer") do
      [{pid, _}] -> Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      [] -> :ok
    end
    
    :ok
  end

  test "creates role with permissions atomically" do
    permissions = [
      %{resource: "users", action: "read"},
      %{resource: "users", action: "write"}
    ]

    # This transaction includes Casbin operations
    result = Repo.transaction(fn ->
      # Create database record
      {:ok, role} = Roles.create_role_record("admin")
      
      # Add Casbin policies
      Enum.each(permissions, fn perm ->
        case Casbin.EnforcerServer.add_policy(
          "my_enforcer",
          {:p, ["admin", perm.resource, perm.action]}
        ) do
          :ok -> :ok
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      
      {:ok, role}
    end)

    assert {:ok, _role} = result
  end

  test "rolls back Casbin operations on error" do
    result = Repo.transaction(fn ->
      # Add a policy
      :ok = Casbin.EnforcerServer.add_policy(
        "my_enforcer",
        {:p, ["temp_role", "resource", "action"]}
      )
      
      # Simulate an error
      Repo.rollback(:simulated_error)
    end)

    assert {:error, :simulated_error} = result
    
    # Verify the policy was not persisted
    policies = Casbin.EnforcerServer.list_policies("my_enforcer", %{sub: "temp_role"})
    assert policies == []
  end
end
```

## Further Reading

- [Ecto.Adapters.SQL.Sandbox Documentation](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html)
- [Ecto.Adapters.SQL.Sandbox Shared Mode](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html#module-shared-mode)
- [Testing with Ecto](https://hexdocs.pm/ecto/testing-with-ecto.html)
