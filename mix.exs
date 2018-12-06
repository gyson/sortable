defmodule Sortable.MixProject do
  use Mix.Project

  def project do
    [
      app: :sortable,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:benchee, "~> 0.13", only: :dev},
      {:stream_data, "~> 0.4", only: [:test, :dev]},
      {:edown, "~> 0.8", override: true, only: :dev},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false},
      {:sext,
       git: "https://github.com/uwiger/sext.git", tag: "1.5.0", manager: :rebar, only: :dev}
    ]
  end
end
