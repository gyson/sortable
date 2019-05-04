defmodule Sortable.MixProject do
  use Mix.Project

  def project do
    [
      app: :sortable,
      version: "0.1.0",
      description: "Sortable is a library to provide serialization with order reserved.",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      name: "Sortable",
      source_url: "https://github.com/gyson/sortable"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rocksdb, "~> 1.0", only: :dev},
      {:benchee, "~> 0.13", only: :dev},
      {:stream_data, "~> 0.4", only: [:test, :dev]},
      {:edown, "~> 0.8", override: true, only: :dev},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:ex_type, "~> 0.3.0", only: :dev, runtime: true},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false},
      {:sext,
       git: "https://github.com/uwiger/sext.git", tag: "1.5.0", manager: :rebar, only: :dev}
    ]
  end

  def package do
    %{
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/gyson/sortable"}
    }
  end
end
