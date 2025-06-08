defmodule CodeAssistant.MixProject do
  use Mix.Project

  def project do
    [
      app: :code_assistant,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: CodeAssistant.CLI]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {CodeAssistant.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:owl, "~> 0.12"},
      {:ucwidth, "~> 0.2"}
    ]
  end
end
