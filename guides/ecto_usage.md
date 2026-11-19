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

# Using Casbin with Ecto

This guide explains how to use Casbin-Ex with Ecto to store policies in a database instead of CSV files.

## Overview

While Casbin-Ex examples in the README use CSV files for simplicity, in production applications you'll typically want to store your policies in a database. The `Casbin.Persist.EctoAdapter` allows you to persist and load policies from any database supported by Ecto.

**Benefits of using Ecto:**
- Persistent storage across application restarts
- Dynamic policy management (add/remove policies at runtime)
- Integration with your existing database
- Support for filtered policy loading (useful for multi-tenant applications)
- Transaction support for atomic policy updates

## Prerequisites

This guide assumes you have:
- An Elixir/Phoenix application with Ecto already configured
- Basic understanding of Casbin concepts (models, policies, enforcers)
- A working Ecto repository in your application

## Database Setup

### Step 1: Create the Migration

First, create a migration to add the `casbin_rule` table to your database:

```bash
mix ecto.gen.migration create_casbin_rule
```

Edit the generated migration file:

```elixir
defmodule MyApp.Repo.Migrations.CreateCasbinRule do
  use Ecto.Migration

  def change do
    create table(:casbin_rule) do
      add :ptype, :string, null: false
      add :v0, :string
      add :v1, :string
      add :v2, :string
      add :v3, :string
      add :v4, :string
      add :v5, :string
      add :v6, :string
    end

    create index(:casbin_rule, [:ptype])
    create index(:casbin_rule, [:v0])
    create index(:casbin_rule, [:v1])
  end
end
```

The `casbin_rule` table stores all policy rules with:
- `ptype`: Policy type (e.g., "p" for policies, "g" for role mappings)
- `v0` to `v6`: Flexible columns for policy attributes (subject, object, action, etc.)

Run the migration:

```bash
mix ecto.migrate
```

### Step 2: Configure Your Model

Create a Casbin model configuration file (e.g., `priv/casbin/model.conf`):

```ini
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[role_definition]
g = _, _

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
```

This is a standard RBAC model. See the [Casbin documentation](https://casbin.org/docs/overview) for other model types.

## Basic Usage

### Stateless Approach (Using Enforcer Module)

For simple use cases, you can use the `Casbin.Enforcer` module directly:

```elixir
alias Casbin.Enforcer
alias Casbin.Persist.EctoAdapter

# Create an adapter with your repo
adapter = EctoAdapter.new(MyApp.Repo)

# Initialize the enforcer with your model and adapter
{:ok, enforcer} = Enforcer.init("priv/casbin/model.conf", adapter)

# Load policies from the database
enforcer = Enforcer.load_policies!(enforcer)

# Check permissions
if Enforcer.allow?(enforcer, ["alice", "data1", "read"]) do
  # Access granted
else
  # Access denied
end
```

### Stateful Approach (Using EnforcerServer)

The `EnforcerServer` approach is useful when you need to manage policies dynamically and access the enforcer from multiple parts of your application by name:

```elixir
alias Casbin.{EnforcerSupervisor, EnforcerServer}
alias Casbin.Persist.EctoAdapter

# Start the enforcer with your model
{:ok, _pid} = EnforcerSupervisor.start_enforcer("my_enforcer", "priv/casbin/model.conf")

# Set the Ecto adapter
adapter = EctoAdapter.new(MyApp.Repo)
:ok = EnforcerServer.set_persist_adapter("my_enforcer", adapter)

# Add policies (these are automatically persisted to the database)
EnforcerServer.add_policy("my_enforcer", {:p, ["alice", "data1", "read"]})
EnforcerServer.add_policy("my_enforcer", {:g, ["alice", "admin"]})

# Check permissions anywhere in your application
EnforcerServer.allow?("my_enforcer", ["alice", "data1", "read"])
# => true or false
```

With `EnforcerServer`, policies added via `add_policy` are automatically persisted to the database through the EctoAdapter. This makes it ideal for applications that need to manage permissions dynamically at runtime.

## Managing Policies

### Adding Policies

Add individual policies to the database:

```elixir
# Add a policy: alice can read data1
:ok = EnforcerServer.add_policy("my_enforcer", {:p, ["alice", "data1", "read"]})

# Add a role mapping: alice has role admin
:ok = EnforcerServer.add_policy("my_enforcer", {:g, ["alice", "admin"]})
```

### Removing Policies

```elixir
# Remove a specific policy
:ok = EnforcerServer.remove_policy("my_enforcer", {:p, ["alice", "data1", "read"]})

# Remove all policies for a subject
:ok = EnforcerServer.remove_filtered_policy("my_enforcer", :p, 0, ["alice"])
```

### Listing Policies

```elixir
# Get all policies
policies = EnforcerServer.list_policies("my_enforcer", %{})

# Get policies matching a filter
policies = EnforcerServer.list_policies("my_enforcer", %{sub: "alice"})
```

## Filtered Policy Loading

For multi-tenant applications or large policy sets, you can load only the policies you need:

```elixir
# Load only policies for a specific tenant
filter = %{v3: "tenant:acme_corp"}
{:ok, enforcer} = Enforcer.init("priv/casbin/model.conf", adapter)
enforcer = Enforcer.load_filtered_policies!(enforcer, filter)

# Or with EnforcerServer
:ok = EnforcerServer.load_filtered_policies("my_enforcer", %{v3: "tenant:acme_corp"})
```

The filter is a map where keys correspond to columns in the `casbin_rule` table (`:ptype`, `:v0`, `:v1`, `:v2`, `:v3`, etc.):

```elixir
# Load policies for multiple tenants
filter = %{v3: ["tenant:acme_corp", "tenant:widgets_inc"]}
EnforcerServer.load_filtered_policies("my_enforcer", filter)

# Load only "p" type policies
filter = %{ptype: "p"}
EnforcerServer.load_filtered_policies("my_enforcer", filter)
```

## Complete Example

Here's a complete example of setting up an authorization system for a blog application:

### Model Configuration (`priv/casbin/blog_model.conf`)

```ini
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[role_definition]
g = _, _

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
```

### Application Setup

```elixir
defmodule MyApp.Authorization do
  @moduledoc """
  Authorization module using Casbin with Ecto persistence.
  """
  alias Casbin.Enforcer
  alias Casbin.Persist.EctoAdapter

  @model_path "priv/casbin/blog_model.conf"

  def init do
    adapter = EctoAdapter.new(MyApp.Repo)
    {:ok, enforcer} = Enforcer.init(@model_path, adapter)
    
    # Load existing policies from database
    enforcer = Enforcer.load_policies!(enforcer)
    
    # Seed initial policies if database is empty
    enforcer = seed_initial_policies(enforcer)
    
    # Store enforcer in application state (e.g., ETS, Agent, or pass it around)
    :persistent_term.put(__MODULE__, enforcer)
    
    {:ok, enforcer}
  end

  defp seed_initial_policies(enforcer) do
    # Check if we already have policies
    case Enforcer.list_policies(enforcer, %{}) do
      [] -> 
        # Add default role permissions
        enforcer
        |> Enforcer.add_policy({:p, ["admin", "blog_post", "create"]})
        |> Enforcer.add_policy({:p, ["admin", "blog_post", "read"]})
        |> Enforcer.add_policy({:p, ["admin", "blog_post", "update"]})
        |> Enforcer.add_policy({:p, ["admin", "blog_post", "delete"]})
        |> Enforcer.add_policy({:p, ["author", "blog_post", "create"]})
        |> Enforcer.add_policy({:p, ["author", "blog_post", "read"]})
        |> Enforcer.add_policy({:p, ["author", "blog_post", "update"]})
        |> Enforcer.add_policy({:p, ["reader", "blog_post", "read"]})
        # Role inheritance
        |> Enforcer.add_mapping_policy({:g, ["admin", "author"]})
        |> Enforcer.add_mapping_policy({:g, ["author", "reader"]})
        # Persist to database
        |> tap(&Enforcer.save_policies!/1)
        
      _ -> 
        enforcer
    end
  end

  def can?(user_id, resource, action) do
    enforcer = :persistent_term.get(__MODULE__)
    Enforcer.allow?(enforcer, [user_id, resource, action])
  end

  def assign_role(user_id, role) do
    enforcer = :persistent_term.get(__MODULE__)
    new_enforcer = Enforcer.add_mapping_policy(enforcer, {:g, [user_id, role]})
    :persistent_term.put(__MODULE__, new_enforcer)
    :ok
  end

  def revoke_role(user_id, role) do
    enforcer = :persistent_term.get(__MODULE__)
    new_enforcer = Enforcer.remove_mapping_policy(enforcer, {:g, [user_id, role]})
    :persistent_term.put(__MODULE__, new_enforcer)
    :ok
  end

  def user_roles(user_id) do
    enforcer = :persistent_term.get(__MODULE__)
    # Get role mappings for the user (where user_id is at index 1, after the :g key)
    Enforcer.list_mapping_policies(enforcer, 1, [user_id])
    |> Enum.map(fn {:g, [_user, role]} -> role end)
  end
end
```

**Alternative: Using EnforcerServer**

For a supervised, process-based approach:

```elixir
defmodule MyApp.Authorization do
  @moduledoc """
  Authorization module using Casbin with EnforcerServer.
  """
  alias Casbin.{EnforcerSupervisor, EnforcerServer}
  alias Casbin.Persist.EctoAdapter

  @enforcer_name "blog_enforcer"
  @model_path "priv/casbin/blog_model.conf"

  def setup do
    # Start the enforcer
    {:ok, _pid} = EnforcerSupervisor.start_enforcer(@enforcer_name, @model_path)
    
    # Set the adapter
    adapter = EctoAdapter.new(MyApp.Repo)
    :ok = EnforcerServer.set_persist_adapter(@enforcer_name, adapter)
    
    # Seed initial policies if needed
    seed_initial_policies()
  end

  defp seed_initial_policies do
    # Check if we already have policies
    case EnforcerServer.list_policies(@enforcer_name, %{}) do
      [] -> 
        # Add default role permissions
        EnforcerServer.add_policy(@enforcer_name, {:p, ["admin", "blog_post", "create"]})
        EnforcerServer.add_policy(@enforcer_name, {:p, ["admin", "blog_post", "read"]})
        EnforcerServer.add_policy(@enforcer_name, {:p, ["admin", "blog_post", "update"]})
        EnforcerServer.add_policy(@enforcer_name, {:p, ["admin", "blog_post", "delete"]})
        
        EnforcerServer.add_policy(@enforcer_name, {:p, ["author", "blog_post", "create"]})
        EnforcerServer.add_policy(@enforcer_name, {:p, ["author", "blog_post", "read"]})
        EnforcerServer.add_policy(@enforcer_name, {:p, ["author", "blog_post", "update"]})
        
        EnforcerServer.add_policy(@enforcer_name, {:p, ["reader", "blog_post", "read"]})
        
        # Role inheritance (using add_policy with :g type)
        EnforcerServer.add_policy(@enforcer_name, {:g, ["admin", "author"]})
        EnforcerServer.add_policy(@enforcer_name, {:g, ["author", "reader"]})
        
      _ -> 
        :ok
    end
  end

  def can?(user_id, resource, action) do
    EnforcerServer.allow?(@enforcer_name, [user_id, resource, action])
  end

  def assign_role(user_id, role) do
    EnforcerServer.add_policy(@enforcer_name, {:g, [user_id, role]})
  end

  def revoke_role(user_id, role) do
    EnforcerServer.remove_policy(@enforcer_name, {:g, [user_id, role]})
  end

  def user_roles(user_id) do
    # For EnforcerServer, we need to filter policies since list_mapping_policies
    # is not available in EnforcerServer
    EnforcerServer.list_policies(@enforcer_name, %{})
    |> Enum.filter(fn
      %{key: :g, attrs: [^user_id, _role]} -> true
      _ -> false
    end)
    |> Enum.map(fn %{attrs: [_user, role]} -> role end)
  end
end
```

### Using in a Phoenix Controller

```elixir
defmodule MyAppWeb.BlogPostController do
  use MyAppWeb, :controller
  alias MyApp.Authorization

  def create(conn, %{"post" => post_params}) do
    user_id = get_current_user_id(conn)
    
    if Authorization.can?(user_id, "blog_post", "create") do
      # User has permission to create posts
      # ... create the post
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "You don't have permission to create posts"})
    end
  end

  def update(conn, %{"id" => id, "post" => post_params}) do
    user_id = get_current_user_id(conn)
    
    if Authorization.can?(user_id, "blog_post", "update") do
      # User has permission to update posts
      # ... update the post
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "You don't have permission to update posts"})
    end
  end

  defp get_current_user_id(conn) do
    # Your logic to get the current user ID
    conn.assigns[:current_user].id
  end
end
```

### Using as a Plug

Create a plug for authorization checks:

```elixir
defmodule MyAppWeb.Plugs.Authorize do
  import Plug.Conn
  alias MyApp.Authorization

  def init(opts), do: opts

  def call(conn, resource: resource, action: action) do
    user_id = conn.assigns[:current_user].id

    if Authorization.can?(user_id, resource, action) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{error: "Access denied"})
      |> halt()
    end
  end
end

# Usage in router or controller:
# plug MyAppWeb.Plugs.Authorize, resource: "blog_post", action: "create"
```

## Dynamic Policy Management

You can manage policies dynamically at runtime:

```elixir
defmodule MyApp.RoleManager do
  alias Casbin.EnforcerServer

  @enforcer "blog_enforcer"

  def create_custom_role(role_name, permissions) do
    # Add permissions for the custom role
    Enum.each(permissions, fn %{resource: resource, action: action} ->
      EnforcerServer.add_policy(@enforcer, {:p, [role_name, resource, action]})
    end)
    
    {:ok, role_name}
  end

  def grant_permission(role, resource, action) do
    EnforcerServer.add_policy(@enforcer, {:p, [role, resource, action]})
  end

  def revoke_permission(role, resource, action) do
    EnforcerServer.remove_policy(@enforcer, {:p, [role, resource, action]})
  end

  def delete_role(role_name) do
    # Remove all policies for this role
    EnforcerServer.remove_filtered_policy(@enforcer, :p, 0, [role_name])
    
    # Remove role mappings
    EnforcerServer.remove_filtered_policy(@enforcer, :g, 1, [role_name])
  end
end
```

## Testing

When testing applications that use Casbin with Ecto, you may need special configuration for database transactions. See our guide on [Testing with Ecto.Adapters.SQL.Sandbox and Transactions](sandbox_testing.md) for detailed information on:

- Using shared mode for tests with transactions
- Proper connection handling with EnforcerServer
- Best practices for test isolation

## Migrating from CSV Files

If you're migrating from CSV-based policies to Ecto:

1. **Create the database table** using the migration above
2. **Load your existing CSV policies** into the database:

```elixir
# One-time migration script
alias Casbin.Enforcer
alias Casbin.Persist.{EctoAdapter, ReadonlyFileAdapter}

# Load from CSV
csv_adapter = ReadonlyFileAdapter.new("priv/casbin/policies.csv")
{:ok, enforcer} = Enforcer.init("priv/casbin/model.conf", csv_adapter)
enforcer = Enforcer.load_policies!(enforcer)

# Get all policies
policies = Enforcer.list_policies(enforcer)

# Save to database
db_adapter = EctoAdapter.new(MyApp.Repo)
Casbin.Persist.PersistAdapter.save_policies(db_adapter, policies)
```

3. **Update your application** to use `EctoAdapter` instead of `ReadonlyFileAdapter`
4. **Remove the CSV files** once you've verified the migration

## Advanced: Multi-Tenant Applications

For applications serving multiple tenants, you can use filtered policies with tenant identifiers:

```elixir
# Model with domain/tenant support (priv/casbin/multi_tenant_model.conf)
[request_definition]
r = sub, dom, obj, act

[policy_definition]
p = sub, dom, obj, act

[role_definition]
g = _, _, _

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = g(r.sub, p.sub, r.dom) && r.dom == p.dom && r.obj == p.obj && r.act == p.act
```

```elixir
defmodule MyApp.TenantAuthorization do
  alias Casbin.EnforcerServer

  def can?(tenant_id, user_id, resource, action) do
    # Request includes tenant context
    EnforcerServer.allow?("my_enforcer", [user_id, tenant_id, resource, action])
  end

  def load_tenant_policies(tenant_id) do
    # Load only policies for this tenant
    filter = %{v1: tenant_id}  # v1 corresponds to the domain/tenant column
    EnforcerServer.load_filtered_policies("my_enforcer", filter)
  end
end
```

## Troubleshooting

### Connection Errors in Tests

If you see `DBConnection.ConnectionError` in tests, you need to configure `Ecto.Adapters.SQL.Sandbox` properly. See the [Testing guide](sandbox_testing.md).

### Policies Not Persisting

Ensure you're using `add_policy` with the enforcer server, which automatically persists to the database:

```elixir
# This persists to database ✅
EnforcerServer.add_policy("my_enforcer", {:p, ["alice", "data1", "read"]})

# This only modifies in-memory state ❌
enforcer = Enforcer.add_policy(enforcer, {:p, ["alice", "data1", "read"]})
```

### Performance Considerations

For large policy sets:
- Use filtered policy loading to reduce memory footprint
- Add appropriate database indexes (see migration example)
- Consider caching frequently accessed authorization decisions
- Monitor database query performance

## Further Reading

- [Casbin Documentation](https://casbin.org/docs/overview)
- [Casbin Model Syntax](https://casbin.org/docs/syntax-for-models)
- [Testing with Ecto Sandbox](sandbox_testing.md)
- [Ecto Documentation](https://hexdocs.pm/ecto)
