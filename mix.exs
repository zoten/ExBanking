defmodule ExBanking.MixProject do
  use Mix.Project

  @app :ex_banking
  @version "0.1.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      test_coverage: [tool: ExCoveralls],
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExBanking.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      # Test coverage
      {:excoveralls, "~> 0.14", only: :test},
      # Doc
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      # Code decorum
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:credo_envvar, "~> 0.1", only: [:dev, :test], runtime: false},
      {:credo_naming, "~> 0.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:mock, "~> 0.3.0", only: :test}
    ]
  end
end
