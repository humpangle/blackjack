defmodule Blackjack.Mixfile do
  use Mix.Project

  def project do
    [
      app: :blackjack,
      version: "0.1.0",
      elixir: "~> 1.7",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [mod: {Blackjack, []}, extra_applications: [:logger]]
  end

  defp deps do
    []
  end
end
