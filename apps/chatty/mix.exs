defmodule Chatty.MixProject do
  use Mix.Project

  def project do
    [
      app: :chatty,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: application_mod()
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_pool, "~> 1.0"},
      {:poolboy, "~> 1.5"},
      {:thousand_island, "~> 0.6.4"}
    ]
  end

  defp application_mod do
    if System.get_env("THOUSAND_ISLAND") do
      {Chatty.ThousandIsland.Application, []}
    else
      {Chatty.Application, []}
    end
  end
end
