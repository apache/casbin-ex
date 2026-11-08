defmodule Casbin.MixProject do
  use Mix.Project

  def project do
    [
      app: :casbin,
      version: "1.14.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://github.com/apache/casbin-ex",
      homepage_url: "https://casbin.incubator.apache.org"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Casbin, []}
    ]
  end

  # specifies which paths to compile per environment
  def elixirc_paths(:test), do: ["lib", "test/support"]
  def elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:git_hooks, "~> 0.7.3", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Apache Casbin (Incubating) for Elixir: an access control library supporting ACL, RBAC and ABAC. Apache Casbin is undergoing incubation at the Apache Software Foundation."
  end

  defp package() do
    [
      name: "apache_casbin",
      files:
        ~w(lib guides rbac.png .formatter.exs .credo.exs mix.exs README.md LICENSE NOTICE DISCLAIMER),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/apache/casbin-ex",
        "Homepage" => "https://casbin.incubator.apache.org",
        "Docs" => "https://casbin.incubator.apache.org/docs/overview/"
      }
    ]
  end
end
