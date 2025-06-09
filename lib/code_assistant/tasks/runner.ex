defmodule CodeAssistan.Tasks.Runner do
  alias CodeAssistan.Tasks.Elixir, as: E
  alias CodeAssistan.Tasks.ElixirTests
  alias CodeAssistan.Tasks.AiderCommand

  def call(context) do
    processed_context =
      case context.language do
        "Elixir" ->
          context
          |> E.call()
          |> handle_elixir_task()

        _other_language ->
          # For now, pass through if not Elixir.
          # Consider raising an error or logging for unsupported languages.
          context
      end

    AiderCommand.call(processed_context)
  end

  defp handle_elixir_task(elixir_context) do
    case elixir_context.task do
      "Generate tests" ->
        ElixirTests.call(elixir_context)

      _other_task ->
        # For now, pass through if not "Generate tests".
        # Consider raising an error or logging for unsupported Elixir tasks.
        elixir_context
    end
  end
end
