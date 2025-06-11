defmodule CodeAssistant.CLI do
  alias Owl.Data, as: D
  alias Owl.IO

  # The main entry point for the command-line application.
  def main(_args) do
    :ok
    |> select_language()
    |> select_task()
    |> get_prompts()
    |> select_filters()
    |> CodeAssistan.Tasks.Runner.call()
    |> display_summary()
    |> confirm_aider_commands()
  end

  # Step 1: Prompt the user to select a programming language.
  defp select_language(:ok) do
    language =
      IO.select(["Elixir", "Ruby"])

    %{language: language}
  end

  # Step 2: Prompt the user to select the desired task.
  defp select_task(data) do
    task =
      IO.select(["Refactor code", "Generate tests"])

    Map.put(data, :task, task)
  end

  # Step 3: Get the main (positive) and negative prompts from the user.
  defp get_prompts(data) do
    IO.puts(D.tag("Now, provide the details for the task.", :cyan))

    positive =
      IO.input(
        label: "Enter the code or main prompt. (optional, press Enter to skip)",
        optional: true
      )

    negative =
      IO.input(
        label: "What should the assistant avoid? (optional, press Enter to skip)",
        optional: true
      )

    data
    |> Map.put(:positive_prompt, positive)
    |> Map.put(:negative_prompt, negative)
  end

  # Filter project files, to add Aider to the context files
  defp select_filters(data) do
    filters =
      Owl.IO.input(label: "filters(optional, press Enter to skip)", optional: true)

    Map.put(data, :filters, filters)
  end

  # Final Step: Display a summary of all the collected data in a formatted panel.
  defp display_summary(data) do
    content = [
      D.tag("Language:", :cyan),
      " #{data.language}\n",
      D.tag("Task:", :cyan),
      "     #{data.task}\n\n",
      D.tag("Prompt:", :cyan),
      "\n",
      # Add a little indentation to the user's prompt text
      "  #{data.positive_prompt}\n\n",
      D.tag("To Avoid:", :cyan),
      "\n",
      "  #{if data.negative_prompt == "", do: "None", else: data.negative_prompt}\n\n",
      D.tag("Filters:", :cyan),
      "  ",
      # This check correctly handles both an empty list from multiselect or user input
      if(data.filters == [] or data.filters == "",
        do: "None",
        else: Enum.join(List.wrap(data.filters), ", ")
      )
    ]

    summary_box = Owl.Box.new(content, title: "Request Summary", border: :heavy)

    Owl.IO.puts(summary_box)

    data
  end

  # Step: Confirm Aider commands with the user one by one.
  defp confirm_aider_commands(data) do
    aider_commands = Map.get(data, :aider_commands)
    dbg()

    cond do
      is_nil(aider_commands) or map_size(aider_commands) == 0 ->
        # For spacing from previous output
        IO.puts("")

        IO.puts(
          D.tag(
            "No Aider commands to execute. This might be due to your filters or an empty project.",
            :yellow
          )
        )

        # Ensure a blank line after this message
        IO.puts("")
        data

      true ->
        count = map_size(aider_commands)
        # For spacing from previous output
        IO.puts("")
        IO.puts(D.tag("Found #{count} Aider command(s) to review.", :green))
        IO.puts(D.tag("Aider Command Execution Confirmation:", :cyan))
        # Add a blank line for separation before the first command box
        IO.puts("")

        Enum.each(aider_commands, fn {file_path, command_str} ->
          # Print the file path in cyan
          IO.puts(D.tag(file_path, :cyan))
          # Print the command string in yellow
          IO.puts(D.tag(command_str, :yellow))
          # Add a small space before the confirmation prompt
          IO.puts("")

          if IO.confirm(message: "Execute this command?") do
            {:ok, _spinner_pid} =
              Owl.Spinner.start(
                id: CodeAssistant.CLI.Spinner,
                type: :dots,
                message: "Executing commands..."
              )

            # Execute the Aider command and then post-Aider checks
            results = CodeAssistan.Tasks.CommandExecutor.execute(file_path, command_str, data)

            Owl.Spinner.stop(id: CodeAssistant.CLI.Spinner, resolution: :ok)
            handle_execution_results(results)
          else
            IO.puts(D.tag("Skipped.", :yellow))
          end

          # Add a blank line for separation before the next command or after the last one
          IO.puts("")
        end)

        data
    end
  end

  defp handle_execution_results({:ok, results}) do
    # Handle Aider command result
    case results.aider do
      {output, 0} ->
        # Aider command succeeded
        success_box_content = [output]
        success_box_title = D.tag("Aider command successful (exit status: 0)", :green)

        success_box =
          Owl.Box.new(success_box_content,
            title: success_box_title,
            border: [style: :single, color: :green]
          )

        Owl.IO.puts(success_box)

      {output, exit_status} ->
        # Aider command failed
        error_box_content = [output]
        error_box_title = D.tag("Aider command failed (exit status: #{exit_status})", :red)

        error_box =
          Owl.Box.new(error_box_content,
            title: error_box_title,
            border: [style: :single, color: :red]
          )

        Owl.IO.puts(error_box)

      other ->
        IO.puts(D.tag("Unexpected Aider command result format: #{inspect(other)}", :red))
    end

    # Separator
    IO.puts("")

    # Handle Post-Aider checks result
    case results.checks do
      {:ok, {output, 0}} ->
        # Post-Aider checks succeeded
        success_box_content = [output]
        success_box_title = D.tag("Post-Aider checks successful (exit status: 0)", :green)

        success_box =
          Owl.Box.new(success_box_content,
            title: success_box_title,
            border: [style: :single, color: :green]
          )

        Owl.IO.puts(success_box)

      {:ok, {output, exit_status}} ->
        # Post-Aider checks failed
        error_box_content = [output]
        error_box_title = D.tag("Post-Aider checks failed (exit status: #{exit_status})", :red)

        error_box =
          Owl.Box.new(error_box_content,
            title: error_box_title,
            border: [style: :single, color: :red]
          )

        Owl.IO.puts(error_box)

      {:ok, :no_specific_action} ->
        IO.puts(D.tag("No specific post-Aider checks were performed.", :blue))

      other ->
        IO.puts(D.tag("Unexpected post-Aider checks result format: #{inspect(other)}", :red))
    end
  end

  # This clause was reported as unused by the compiler because
  # CodeAssistan.Tasks.CommandExecutor.execute/3 always returns {:ok, results_map}.
  # Errors within the execution are reported inside the results_map.
  # defp handle_execution_results({:error, reason}) do
  #   IO.puts(D.tag("Error during command execution phase: #{inspect(reason)}", :red))
  # end
end
