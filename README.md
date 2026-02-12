# Casbin-Ex

[![GitHub Actions](https://github.com/casbin/casbin-ex/actions/workflows/ci.yml/badge.svg)](https://github.com/casbin/casbin-ex/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/casbin.svg)](https://hex.pm/packages/casbin)
[![Release](https://img.shields.io/github/release/casbin/casbin-ex.svg)](https://github.com/casbin/casbin-ex/releases/latest)
[![Discord](https://img.shields.io/discord/1022748306096537660?logo=discord&label=discord&color=5865F2)](https://discord.gg/S5UjpzGZjN)

**News**: still worry about how to write the correct Casbin policy? ``Casbin online editor`` is coming to help! Try it at: https://casbin.org/editor/

Casbin-Ex is a powerful and efficient open-source access control library for Elixir projects. It provides support for enforcing authorization based on various [access control models](https://en.wikipedia.org/wiki/Computer_security_model).

## All the languages supported by Casbin:

| [![golang](https://casbin.org/img/langs/golang.png)](https://github.com/casbin/casbin) | [![java](https://casbin.org/img/langs/java.png)](https://github.com/casbin/jcasbin) | [![nodejs](https://casbin.org/img/langs/nodejs.png)](https://github.com/casbin/node-casbin) | [![php](https://casbin.org/img/langs/php.png)](https://github.com/php-casbin/php-casbin) |
|----------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| [Casbin](https://github.com/casbin/casbin)                                             | [jCasbin](https://github.com/casbin/jcasbin)                                        | [node-Casbin](https://github.com/casbin/node-casbin)                                        | [PHP-Casbin](https://github.com/php-casbin/php-casbin)                                   |
| production-ready                                                                       | production-ready                                                                    | production-ready                                                                            | production-ready                                                                         |

| [![python](https://casbin.org/img/langs/python.png)](https://github.com/casbin/pycasbin) | [![dotnet](https://casbin.org/img/langs/dotnet.png)](https://github.com/casbin-net/Casbin.NET) | [![c++](https://casbin.org/img/langs/cpp.png)](https://github.com/casbin/casbin-cpp) | [![rust](https://casbin.org/img/langs/rust.png)](https://github.com/casbin/casbin-rs) |
|------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| [PyCasbin](https://github.com/casbin/pycasbin)                                           | [Casbin.NET](https://github.com/casbin-net/Casbin.NET)                                         | [Casbin-CPP](https://github.com/casbin/casbin-cpp)                                   | [Casbin-RS](https://github.com/casbin/casbin-rs)                                      |
| production-ready                                                                         | production-ready                                                                               | production-ready                                                                     | production-ready                                                                      |

## Documentation

https://casbin.org/docs/overview

## Installation

The package can be installed by adding `casbin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:casbin, "~> 1.6"}
  ]
end
```

Or install from GitHub:

```elixir
def deps do
  [
    {:casbin, git: "https://github.com/casbin/casbin-ex"}
  ]
end
```

## [Access Control List (ACL)](https://en.wikipedia.org/wiki/Access-control_list)

Let's say we have just built a wonderful blogging system, and now we want
to add the access control feature to it to control **who can do what** with
the resource named `blog_post`. Our system requirements would look something
like this:

|       | blog_post.create | blog_post.read | blog_post.modify | blog_post.delete |
| ----- |:----------------:|:--------------:|:----------------:|:----------------:|
| alice |     yes          |       yes      |        yes       |          yes     |
| bob   |     no           |       yes      |        no        |          yes     |
| peter |     yes          |       yes      |        yes       |          no      |

Based on these requirements, our first step is to choose an appropriate
access control model. Let's say we choose to go with the ACL model.
In Casbin-Ex, an access control model is abstracted into a
config file based on the **[PERM Meta-Model](https://casbin.org/docs/how-it-works)**. The content of the config file for our system would look
like this:

```ini
# blog_ac.conf

# We want each request to be a tuple of three items, in which first item
# associated with the attribute named `sub`, second `obj` and third `act`.
# An example of a valid request based on this definition is
# `["alice, "blog_post", "read"]` (can `alice` `read` `blog_post`?).
[request_definition]
r = sub, obj, act

# Each policy definition should have a key and a list of attributes separated by
# an equal `=` sign. In Casbin-Ex all policy rules have in common the `eft` attribute
# and it can only take value of either `"allow"` or `"deny"`, so you can omit
# it in your policy definition.
[policy_definition]
p = sub, obj, act

# Policy effect defines whether the access should be approved or denied
# if multiple policy rules match the request.
# We use the following policy effect for our blog system to mean that:
# if there's any matched policy rule of type `allow` (i.e `eft` == "allow"),
# the final effect is `allow`. Which also means if there's no match or all
# matches are of type `deny`, the final effect is `deny`.
[policy_effect]
e = some(where (p.eft == allow))

# matchers is just a boolean expression used to determine whether a request
# matches the given policy rule.
[matchers]
m = r.sub == p.sub && r.obj == p.obj && r.act == p.act

```

Done with the model. Our next step is to define policy rules based on the
system requirements and the policy definition. We can choose to put these
rules in a database or in our case a `*.csv` file named `blog_ac.csv`:

```
p, alice, blog_post, create
p, alice, blog_post, read
p, alice, blog_post, modify
p, alice, blog_post, delete

p, bob, blog_post, read

p, peter, blog_post, create
p, peter, blog_post, read
p, peter, blog_post, modify

```

Note that, first of all, since we don't specify the value for the `eft`
attribute for any of the above rules, all of our rules are of type `allow`
(i.e., `yes`) by default. Second, we don't have to define any `deny`
(i.e., `no`) rules for our system.

The final step is to combine the model, the policy rules and Casbin-Ex to
construct our access control system.

```elixir
alias Casbin.{EnforcerSupervisor, EnforcerServer}

# Give our system a name so that we can reference it by its name
# rather than the process ID (a.k.a `pid`).
ename = "blog_ac"

# Starts a new enforcer process and supervises it.
EnforcerSupervisor.start_enforcer(ename, blog_ac.conf)

# Load policy rules.
EnforcerServer.load_policies(ename, blog_ac.csv)

new_req = ["alice", "blog_post", "read"]

case EnforcerServer.allow?(ename, new_req) do
  true ->
    # Yes, this `new_req` is allowed

  false ->
    # Nope, `new_req` is denied (not allowed)
end
```

If you are not a fan of supervision tree or stateful server, read on to
figure out how to use Casbin-Ex without any of those.

## [Role-Based Access Control (RBAC)](https://en.wikipedia.org/wiki/Role-based_access_control)

Our ACL access control system is working just fine for the initial purpose, but
now our business is expanding rapidly, so we need a more flexible access
control model to meet new business requirements. We went back to the
drawing board and came up with this design for our new system:

![rbac diagram](rbac.png)

We assign different roles to different users: `bob` has the role `reader`,
`peter` has the role `author`, and `alice` has the role `admin`, and so on.
We then define mappings from `role` to `permission` (instead of asking
*who can do what* like in the ACL model, now we ask **which role can
do what?**). We also define mappings from role to role to represent
inheritance. In the above diagram, `admin` inherits from `author`,
which in turn inherits from `reader`.

Note that the *has role* or *inherits from* relation is [transitive](https://en.wikipedia.org/wiki/Transitive_relation).

Based on this design, the config file for our new model would look like
this:

```ini
# blog_ac.conf

[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

# This is the name of the mapping we mentioned above. We call it `g`
# to make it compatible with Casbin (which only allows names
# like `g, g2, ...`), but you can name it however you prefer as long as
# you're consistent.
[role_definition]
g = _, _

[policy_effect]
e = some(where (p.eft == allow))

# We change this part `r.sub == p.sub` of our initial matcher expression to
# `g(r.sub, p.sub)` to mean that: if `r.sub` has role (or inherits from)
# `p.sub` and ... and ...
[matchers]
m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act

```

And the content of the file `blog_ac.csv` now become:

```
p, reader, blog_post, read
p, author, blog_post, modify
p, author, blog_post, create
p, admin, blog_post, delete

g, bob, reader
g, peter, author
g, alice, admin

g, author, reader
g, admin, author
```

Finally:

```elixir
alias Casbin.{EnforcerSupervisor, EnforcerServer}

ename = "blog_ac"
EnforcerSupervisor.start_enforcer(ename, blog_ac.conf)
EnforcerServer.load_policies(ename, blog_ac.csv)

# You only have to add this new line to load mapping rules. Unlike other Casbin
# implementations, Casbin-Ex distinguishes between `normal` policy rules and `mapping` rules.
# We've just happened to put the two types of rules in the same `*.csv` file.
EnforcerServer.load_mapping_policies(ename, blog_ac.csv)

new_req = ["alice", "blog_post", "read"]

case EnforcerServer.allow?(ename, new_req) do
  true ->
    # Yes, this `new_req` is allowed

  false ->
    # Nope, `new_req` is denied (not allowed)
end
```

As you can see, the cost of switching or upgrading to another access control
mechanism is as simple as modifying the configuration.

## Persisting Policies to Database with EctoAdapter

Instead of loading policies from CSV files, you can persist them to a database using the `EctoAdapter`. This provides a more dynamic and scalable approach, especially for production environments where policies may change frequently.

### Setup

First, run the migration to create the `casbin_rule` table:

```elixir
# In your migration file
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
  end
end
```

### Loading Policies from Database

```elixir
alias Casbin.{EnforcerSupervisor, EnforcerServer}
alias Casbin.Persist.EctoAdapter

ename = "blog_ac"

# Start the enforcer
EnforcerSupervisor.start_enforcer(ename, "blog_ac.conf")

# Configure the database adapter
adapter = EctoAdapter.new(MyApp.Repo)
EnforcerServer.set_persist_adapter(ename, adapter)

# Load policies from database
EnforcerServer.load_policies(ename)

# For RBAC models, also load mapping policies
EnforcerServer.load_mapping_policies(ename)

# Now you can check permissions
case EnforcerServer.allow?(ename, ["alice", "blog_post", "read"]) do
  true -> # Access granted
  false -> # Access denied
end
```

### Auto-Persist on Policy Changes

Once you set the `EctoAdapter`, any policy modifications are automatically persisted:

```elixir
# This policy is automatically saved to the database
EnforcerServer.add_policy(ename, {:p, ["bob", "data", "write"]})

# This mapping is also auto-saved
EnforcerServer.add_mapping_policy(ename, {:g, "carol", "admin"})
```

### Application Startup Pattern

For production applications, you typically want to load policies from the database on startup:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Repo,
      # ... other children
      {Casbin.EnforcerSupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    # Initialize enforcer with policies from database
    setup_casbin()

    {:ok, pid}
  end

  defp setup_casbin do
    ename = "my_enforcer"
    model_path = Application.app_dir(:my_app, "priv/casbin/model.conf")
    
    # Start enforcer
    Casbin.EnforcerSupervisor.start_enforcer(ename, model_path)
    
    # Configure database adapter
    adapter = Casbin.Persist.EctoAdapter.new(MyApp.Repo)
    Casbin.EnforcerServer.set_persist_adapter(ename, adapter)
    
    # Load policies from database
    Casbin.EnforcerServer.load_policies(ename)
    Casbin.EnforcerServer.load_mapping_policies(ename)
  end
end
```

## RESTful Example

The config file:

```ini
# restful_ac.conf

[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[policy_effect]
e = some(where (p.eft == allow))

# The function named `match?` will be defined later in code.
[matchers]
m = r.sub == p.sub && match?(r.obj, p.obj) && match?(r.act, p.act)
```

Policy rules `restful_ac.csv`:

```
p, alice, /alice_data/.*, GET
p, alice, /alice_data/resource1, POST

p, bob, /alice_data/resource2, GET
p, bob, /bob_data/.*, POST

p, peter, /peter_data, (GET)|(POST)
```

Code:

```elixir
alias Casbin.{EnforcerSupervisor, EnforcerServer}

ename = "restful_ac"
EnforcerSupervisor.start_enforcer(ename, restful_ac.conf)
EnforcerServer.load_policies(ename, restful_ac.csv)

# We have to define the `match?/2` function and add it to our enforcer system.

# This anonymous function is identical to the built-in function
# `regex_match?/2`, but we redefine it here to illustrate the idea of
# how you can customize the system to meet your needs.
fun = fn str, pattern ->
  case Regex.compile("^#{pattern}$") do
    {:error, _} ->
      false

    {:ok, r} ->
      Regex.match?(r, str)
  end
end

# Add `fun` to our system. Note that the name `:match?` is an atom, not
# a string.
EnforcerServer.add_fun(ename, {:match?, fun})

new_req = ["alice", "/alice_data/foo", "GET"]

case EnforcerServer.allow?(ename, new_req) do
  true ->
    # Yes, this `new_req` is allowed

  false ->
    # Nope, `new_req` is denied (not allowed)
end
```

## Supported Models

Casbin-Ex supports the following access control models:

1. [**ACL (Access Control List)**](https://en.wikipedia.org/wiki/Access-control_list)
2. **ACL with [superuser](https://en.wikipedia.org/wiki/Superuser)**
3. **ACL without users**: especially useful for systems that don't have authentication or user log-ins
4. **ACL without resources**: some scenarios may target a type of resources instead of an individual resource
5. **[RBAC (Role-Based Access Control)](https://en.wikipedia.org/wiki/Role-based_access_control)**
6. **RBAC with resource roles**: both users and resources can have roles (or groups) at the same time
7. **RBAC with domains/tenants**: users can have different role sets for different domains/tenants
8. **[ABAC (Attribute-Based Access Control)](https://en.wikipedia.org/wiki/Attribute-Based_Access_Control)**: syntax sugar like `resource.Owner` can be used to get the attribute for a resource
9. **[RESTful](https://en.wikipedia.org/wiki/Representational_state_transfer)**: supports paths like `/res/*`, `/res/:id` and HTTP methods like `GET`, `POST`, `PUT`, `DELETE`
10. **Deny-override**: both allow and deny authorizations are supported, deny overrides the allow
11. **Priority**: the policy rules can be prioritized like firewall rules

## Using with Ecto

All examples above use CSV files for simplicity, but in production applications you'll typically want to store policies in a database. Casbin-Ex provides an `EctoAdapter` for this purpose.

See our comprehensive guide: [Using Casbin with Ecto](guides/ecto_usage.md)

Key topics covered:
- Database setup and migrations
- Loading and saving policies to a database
- Dynamic policy management
- Multi-tenant applications with filtered policies
- Complete example applications

## Testing

### Using with Ecto.Adapters.SQL.Sandbox

If you're using Casbin-Ex with Ecto and need to wrap operations in database transactions during testing, see our guide on [Testing with Ecto.Adapters.SQL.Sandbox and Transactions](guides/sandbox_testing.md).

Key points:
- Use `Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})` for tests with transactions
- Allow the EnforcerServer process to access your test's database connection
- See the guide for complete examples and best practices

## Middlewares

Authz middlewares for web frameworks: https://casbin.org/docs/middlewares

## Our adopters

https://casbin.org/docs/adopters

## How to Contribute

Please read the [contributing guide](CONTRIBUTING.md).

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=casbin/casbin-ex&type=Date)](https://star-history.com/#casbin/casbin-ex&Date)

## License

This project is licensed under the [Apache 2.0 license](LICENSE).

## Contact

If you have any issues or feature requests, please contact us. PR is welcomed.
- https://github.com/casbin/casbin-ex/issues
- https://discord.gg/S5UjpzGZjN
