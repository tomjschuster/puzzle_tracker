defmodule PuzzleTracker.MixProject do
  use Mix.Project

  def project do
    [
      app: :puzzle_tracker,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.github": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PuzzleTracker.Application, []}
    ]
  end

  defp deps do
    [
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end
end
