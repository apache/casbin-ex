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

defmodule Casbin.Persist.EctoAdapter do
  @moduledoc """
  This module defines an adapter for persisting the list of policies
  to a database.

  ## Ecto.Adapters.SQL.Sandbox Compatibility

  When using this adapter with `Ecto.Adapters.SQL.Sandbox` in tests, especially
  with nested transactions, you need to ensure proper connection handling.

  ### Recommended: Use Shared Mode

  In your test setup, use shared mode for tests that wrap Casbin operations in transactions:

      setup do
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)
        Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, {:shared, self()})
        :ok
      end

  This allows the EnforcerServer process to access the database connection
  during transactions. Note that this means all tests in the module will
  share the same connection, which may affect test isolation.

  ### Alternative: Avoid Transactions in Tests

  If you need better test isolation, consider structuring your tests to avoid
  wrapping Casbin operations in explicit transactions, or handle rollback differently.

  ### Advanced: Dynamic Repo (Limited Use)

  For advanced use cases, you can configure the adapter with a function that
  returns the repo, though this alone doesn't solve the transaction isolation issue:

      # In your application setup
      adapter = EctoAdapter.new(fn -> MyApp.Repo end)

  See `Ecto.Adapters.SQL.Sandbox` documentation for more details on connection handling.
  """
  import Ecto.Changeset
  use Ecto.Schema

  defstruct repo: nil, get_dynamic_repo: nil

  defmodule CasbinRule do
    @moduledoc """
    Schema for storing Casbin rules in the database.
    """
    import Ecto.Changeset
    require Ecto.Query
    use Ecto.Schema
    @columns [:ptype, :v0, :v1, :v2, :v3, :v4, :v5, :v6]

    schema "casbin_rule" do
      field(:ptype, :string)
      field(:v0, :string)
      field(:v1, :string)
      field(:v2, :string)
      field(:v3, :string)
      field(:v4, :string)
      field(:v5, :string)
      field(:v6, :string)
    end

    @doc """

      # Examples
        iex> CasbinRule.policy_to_map({:p, ["admin"]}, 1) |> Map.to_list |> Enum.sort
        [ptype: "p", v1: "admin"]


        iex> CasbinRule.policy_to_map({:p, ["admin"]}) |> Map.to_list |> Enum.sort
        [ptype: "p", v0: "admin"]

    """
    @spec policy_to_map({atom(), [String.t()]}) :: %{}
    def policy_to_map({key, attrs}) do
      Enum.zip(@columns, [Atom.to_string(key) | attrs]) |> Map.new()
    end

    def policy_to_map({key, attrs}, idx) do
      [kcol | cols] = @columns

      arr =
        cols
        |> Enum.slice(idx, length(attrs))
        |> (&[&2 | &1]).(kcol)
        |> Enum.zip([Atom.to_string(key) | attrs])
        |> Map.new()

      arr
    end

    @spec create_changeset({atom(), [String.t()]}) :: Ecto.Changeset.t()
    def create_changeset({_key, _attrs} = policy) do
      changeset(%CasbinRule{}, policy_to_map(policy))
    end

    @spec create_changeset(
            String.t(),
            String.t(),
            String.t(),
            String.t(),
            String.t(),
            String.t(),
            String.t(),
            String.t()
          ) :: Ecto.Changeset.t()
    def create_changeset(ptype, v0, v1, v2 \\ nil, v3 \\ nil, v4 \\ nil, v5 \\ nil, v6 \\ nil) do
      changeset(%CasbinRule{}, %{
        ptype: ptype,
        v0: v0,
        v1: v1,
        v2: v2,
        v3: v3,
        v4: v4,
        v5: v5,
        v6: v6
      })
    end

    def changeset(rule, params \\ %{}) do
      rule
      |> cast(params, @columns)
      |> validate_required([:ptype, :v0, :v1])
    end

    def changeset_to_list(%{ptype: ptype, v0: v0, v1: v1, v2: v2, v3: v3, v4: v4, v5: v5, v6: v6}) do
      [ptype, v0, v1, v2, v3, v4, v5, v6] |> Enum.filter(fn a -> !Kernel.is_nil(a) end)
    end

    def changeset_to_queryable({_key, _attrs} = policy, idx) do
      arr =
        policy_to_map(policy, idx)
        |> Map.to_list()

      Ecto.Query.from(CasbinRule, where: ^arr)
    end

    def changeset_to_queryable({key, attrs}) do
      arr = Enum.zip(@columns, [Atom.to_string(key) | attrs])
      Ecto.Query.from(CasbinRule, where: ^arr)
    end
  end

  @doc """
  Creates a new EctoAdapter with the given repo.

  ## Parameters
  - `repo`: An Ecto.Repo module or a function that returns one.

  ## Examples
      # Static repo (standard usage)
      adapter = EctoAdapter.new(MyApp.Repo)
      
      # Dynamic repo (for Sandbox testing with transactions)
      adapter = EctoAdapter.new(fn -> Ecto.Repo.get_dynamic_repo() || MyApp.Repo end)
  """
  def new(repo) when is_atom(repo) do
    %__MODULE__{repo: repo, get_dynamic_repo: nil}
  end

  def new(repo_fn) when is_function(repo_fn, 0) do
    %__MODULE__{repo: nil, get_dynamic_repo: repo_fn}
  end

  @doc """
  Gets the repo to use for the current operation.
  If get_dynamic_repo is set, calls it to get the dynamic repo.
  Otherwise returns the static repo.
  """
  def get_repo(%__MODULE__{get_dynamic_repo: get_fn}) when is_function(get_fn, 0) do
    get_fn.()
  end

  def get_repo(%__MODULE__{repo: repo}) when is_atom(repo) do
    repo
  end

  defimpl Casbin.Persist.PersistAdapter, for: Casbin.Persist.EctoAdapter do
    alias Casbin.Persist.EctoAdapter

    # Columns a policy filter is allowed to constrain.
    @filterable_fields [:ptype, :v0, :v1, :v2, :v3, :v4, :v5, :v6]

    @doc """
    Queries the list of policy rules from the database and returns them
    as a list of strings.

    ## Examples

        iex> PersistAdapter.load_policies(%Casbin.Persist.EctoAdapter{repo: nil})
        ...> {:error, "repo is not set"}
    """
    @spec load_policies(EctoAdapter.t()) :: [Model.Policy.t()]
    def load_policies(%Casbin.Persist.EctoAdapter{repo: nil, get_dynamic_repo: nil}) do
      {:error, "repo is not set"}
    end

    def load_policies(adapter) do
      repo = EctoAdapter.get_repo(adapter)

      policies =
        repo.all(CasbinRule)
        |> Enum.map(&CasbinRule.changeset_to_list(&1))

      {:ok, policies}
    end

    @doc """
    Loads only policies matching the given filter from the database.

    The filter is a map where keys can be `:ptype`, `:v0`, `:v1`, `:v2`, `:v3`, `:v4`, `:v5`, or `:v6`.
    Values can be either a single string or a list of strings for matching multiple values.

    ## Examples

        # Load policies for a specific domain
        filter = %{v3: "org:tenant_123"}
        PersistAdapter.load_filtered_policy(adapter, filter)

        # Load policies with multiple criteria
        filter = %{ptype: "p", v3: ["org:tenant_1", "org:tenant_2"]}
        PersistAdapter.load_filtered_policy(adapter, filter)

        iex> PersistAdapter.load_filtered_policy(%Casbin.Persist.EctoAdapter{repo: nil}, %{})
        ...> {:error, "repo is not set"}
    """
    @spec load_filtered_policy(EctoAdapter.t(), map()) :: {:ok, [list()]} | {:error, String.t()}
    def load_filtered_policy(
          %Casbin.Persist.EctoAdapter{repo: nil, get_dynamic_repo: nil},
          _filter
        ) do
      {:error, "repo is not set"}
    end

    def load_filtered_policy(adapter, filter) when is_map(filter) do
      repo = EctoAdapter.get_repo(adapter)
      query = build_filtered_query(filter)

      policies =
        repo.all(query)
        |> Enum.map(&CasbinRule.changeset_to_list(&1))

      {:ok, policies}
    end

    defp build_filtered_query(filter) do
      import Ecto.Query
      base_query = from(r in CasbinRule)

      Enum.reduce(filter, base_query, fn {field, value}, query ->
        add_where_clause(query, field, value)
      end)
    end

    # Helper function to add WHERE clause for a single filter condition.
    # Unknown fields are ignored so a stray filter key cannot widen the query.
    defp add_where_clause(query, field, values)
         when field in @filterable_fields and is_list(values) do
      import Ecto.Query

      where(query, [r], field(r, ^field) in ^values)
    end

    defp add_where_clause(query, field, value) when field in @filterable_fields do
      import Ecto.Query

      where(query, [r], field(r, ^field) == ^value)
    end

    defp add_where_clause(query, _field, _value), do: query

    @doc """
    Uses the configured repo to insert a Policy into the casbin_rule table.

    Returns an error if repo is not set.

    ## Examples

        iex> PersistAdapter.add_policy(
        ...>    %Casbin.Persist.EctoAdapter{},
        ...>    {:p, ["user", "file", "read"]})
        ...> {:error, "repo is not set"}
    """
    def add_policy(%Casbin.Persist.EctoAdapter{repo: nil, get_dynamic_repo: nil}, _) do
      {:error, "repo is not set"}
    end

    def add_policy(adapter, {_key, _attrs} = policy) do
      repo = EctoAdapter.get_repo(adapter)
      changeset = CasbinRule.create_changeset(policy)

      # on_conflict: :nothing prevents Ecto.ConstraintError when a duplicate rule is
      # inserted concurrently (e.g., two nodes racing, or memory/DB state diverging after
      # an EnforcerServer restart). Without this, the bare insert raises and crashes the
      # EnforcerServer GenServer — a critical process that takes time to restart.
      case repo.insert(changeset, on_conflict: :nothing) do
        {:ok, _casbin} -> {:ok, adapter}
        {:error, changeset} -> {:error, changeset.errors}
      end
    end

    @doc """
    Removes all rules matching the provided attributes. If a subset of attributes
    are provided it will remove all matching records, i.e. if only a subj is provided
    all records including that subject will be removed from storage

    Returns an error if repo is not set.

    ## Examples

        iex> PersistAdapter.remove_policy(
        ...>    %Casbin.Persist.EctoAdapter{},
        ...>    {:p, ["user", "file", "read"]})
        ...> {:error, "repo is not set"}
    """
    def remove_policy(%Casbin.Persist.EctoAdapter{repo: nil, get_dynamic_repo: nil}, _) do
      {:error, "repo is not set"}
    end

    def remove_policy(adapter, {_key, _attr} = policy) do
      repo = EctoAdapter.get_repo(adapter)
      f = CasbinRule.changeset_to_queryable(policy)

      case repo.delete_all(f) do
        {:error, changeset} -> {:error, changeset.errors}
        _ -> {:ok, adapter}
      end
    end

    def remove_filtered_policy(adapter, key, idx, attrs) do
      repo = EctoAdapter.get_repo(adapter)
      f = CasbinRule.changeset_to_queryable({key, attrs}, idx)

      case repo.delete_all(f) do
        {:error, changeset} -> {:error, changeset.errors}
        _ -> {:ok, adapter}
      end
    end

    @doc """
    Truncates the table and inserts the provided policies.

    Returns an error if repo is not set.

    ## Examples

        iex> PersistAdapter.save_policies(
        ...>    %Casbin.Persist.EctoAdapter{},
        ...>    [])
        ...> {:error, "repo is not set"}
    """
    def save_policies(%Casbin.Persist.EctoAdapter{repo: nil, get_dynamic_repo: nil}, _) do
      {:error, "repo is not set"}
    end

    def save_policies(adapter, policies) do
      repo = EctoAdapter.get_repo(adapter)
      repo.transaction(fn -> insert_policies(repo, adapter, policies) end)
    end

    defp insert_policies(repo, adapter, policies) do
      repo.delete_all(CasbinRule)
      Enum.each(policies, &insert_policy(repo, adapter, &1))
    end

    defp insert_policy(repo, adapter, policy) do
      changeset = CasbinRule.create_changeset(policy)

      # on_conflict: :nothing — same rationale as add_policy/2: save_policies/2
      # truncates then re-inserts all rules; a race or restart can cause duplicates.
      case repo.insert(changeset, on_conflict: :nothing) do
        {:ok, _casbin} -> adapter
        {:error, changeset} -> {:error, changeset.errors}
      end
    end
  end
end
