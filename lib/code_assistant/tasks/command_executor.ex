defmodule CodeAssistan.Tasks.CommandExecutor do
  @doc """
  Executes a secondary command based on the file path and overall context,
  typically after an Aider command has been (notionally) processed.

  For Elixir projects, if the task was "Generate tests" and the primary file
  processed by Aider was a test file, this function will indicate that
  `mix test <file_path>` would be run.
  """
  def execute(file_path, data) do
    cond do
      data.language == "Elixir" &&
          data.task == "Generate tests" && # Retaining this condition as per original logic
          String.ends_with?(file_path, "_test.exs") ->
        command_parts = ["test", file_path]
        # System.cmd returns {output, exit_status}
        # We'll run the command from the current working directory.
        # No specific environment variables or other options needed for now.
        result = System.cmd("mix", command_parts, [])
        {:ok, result} # result is {output_string, exit_status_integer}

      true ->
        # No specific secondary action for other cases at the moment.
        {:ok, :no_specific_secondary_action}
    end
  end
end
