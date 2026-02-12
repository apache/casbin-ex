defmodule Casbin.Persist.MockRepo do
  @moduledoc """
  Mock repository for testing Ecto adapter functionality.
  """

  defmacro __using__(opts) do
    pfile = opts[:pfile]

    quote do
      alias Casbin.Persist.EctoAdapter.CasbinRule
      alias Ecto.Changeset

      def to_changeset(id, rule) do
        Enum.zip([:ptype, :v0, :v1, :v2, :v3, :v4, :v5, :v6], rule)
        |> Map.new()
        |> then(&Map.merge(%Casbin.Persist.EctoAdapter.CasbinRule{id: id}, &1))
      end

      # Define function head with default parameter
      def all(query_or_schema, opts \\ [])

      def all(CasbinRule, _opts) do
        unquote(pfile)
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.map(&String.split(&1, ~r{,\s*}))
        |> Enum.with_index(1)
        |> Enum.map(fn {rule, id} -> to_changeset(id, rule) end)
      end

      # Support for Ecto.Query - delegates to CasbinRule for simplicity
      # In a real database, Ecto would apply the query filters
      # For testing filtered policies, use ReadonlyFileAdapter tests instead
      def all(%Ecto.Query{}, _opts) do
        all(CasbinRule)
      end

      def insert(changeset, opts \\ [])

      def insert(%Changeset{errors: [], changes: values}, _opts) do
        {:ok, struct(CasbinRule, values)}
      end

      def insert(changeset, _opts) do
        {:error, changeset}
      end

      def delete_all(queryset) do
        {1, nil}
      end

      def transaction(fun) when is_function(fun, 0) do
        {:ok, fun.()}
      end

      def transaction(fun) when is_function(fun, 1) do
        # For transaction with repo argument
        result = fun.(__MODULE__)
        {:ok, result}
      end

      # Allow override in using modules
      defoverridable all: 1, all: 2
    end
  end
end
