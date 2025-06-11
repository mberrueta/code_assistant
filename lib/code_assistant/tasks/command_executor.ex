defmodule CodeAssistan.Tasks.CommandExecutor do
  @doc """
  Executes a secondary command based on the file path and overall context,
  typically after an Aider command has been (notionally) processed.

  For Elixir projects, if the task was "Generate tests" and the primary file
  processed by Aider was a test file, this function will indicate that
  `mix test <file_path>` would be run.
  """
  def execute(file_path, aider_command_str, data) do
    # Execute the Aider command by passing the full string to the shell
    # stderr_to_stdout: true merges stderr into the output string for simpler handling
    # Using "sh -c" allows the shell to parse the command string correctly.
    aider_result = System.cmd("sh", ["-c", aider_command_str], stderr_to_stdout: true)

    # Run post-Aider checks
    checks_result = run_post_aider_checks(file_path, data)

    {:ok, %{aider: aider_result, checks: checks_result}}
  end

  defp run_post_aider_checks(file_path, data) do
    cond do
      data.language == "Elixir" &&
        data.task == "Generate tests" &&
          String.ends_with?(file_path, "_test.exs") ->
        command_parts = ["test", file_path]
        # Execute mix test command
        mix_test_result = System.cmd("mix", command_parts, stderr_to_stdout: true)
        # Return the result of the mix test command
        # mix_test_result is {output_string, exit_status_integer}
        {:ok, mix_test_result}

      true ->
        # No specific action for other cases
        {:ok, :no_specific_action}
    end
  end
end
