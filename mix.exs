defmodule Excansock.MixProject do
  use Mix.Project

  def project do
    [
      app: :excansock,
      version: "1.0.2",
      elixir: "~> 1.9",
      compilers: [:elixir_make | Mix.compilers()],
      make_targets: ["all"],
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps(),
      name: "Excansock",
      source_url: "https://github.com/pavels/excansock"
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:elixir_make, "~> 0.6", runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Excansock allows you to communicate using CAN bus through SocketCAN API. As SocketCAN is Linux specific, this project is useful only on Linux operating system."
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: "https://github.com/pavels/excansock"
    ]
  end

  defp package() do
    [
      files: ~w(lib c_src mix.exs mix.lock README.md LICENSE Makefile .formatter.exs),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/pavels/excansock"}
    ]
  end
end
