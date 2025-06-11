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
    case Map.get(data, :aider_commands) do
      nil ->
        # No commands to process
        data

      commands when map_size(commands) == 0 ->
        # No commands to process
        data

      commands ->
        # Add a blank line for separation
        IO.puts("")
        IO.puts(D.tag("Aider Command Execution Confirmation:", :cyan))

        Enum.each(commands, fn {file_path, command_str} ->
          command_box_content = [
            command_str
          ]

          command_box =
            Owl.Box.new(command_box_content,
              title: D.tag(file_path, :yellow),
              border: [style: :single, color: :cyan]
            )

          Owl.IO.puts(command_box)

          if IO.confirm(message: "Execute this command?") do
            IO.puts(D.tag("OK (Aider command execution pending implementation)", :green))
            # Attempt to execute a secondary command, like running tests
            handle_secondary_command_result(
              CodeAssistan.Tasks.CommandExecutor.execute(file_path, data)
            )
          else
            IO.puts(D.tag("Skipped.", :yellow))
          end

          # Add a blank line for separation before the next command
          IO.puts("")
        end)

        data
    end

    data
  end

  defp handle_secondary_command_result({:ok, {output, exit_status}}) do
    IO.puts(D.tag("Secondary command output (exit status: #{exit_status}):", :blue))
    IO.puts(output)
  end

  defp handle_secondary_command_result({:ok, :no_specific_secondary_action}) do
    IO.puts(D.tag("No specific secondary command was executed.", :blue))
  end

  defp handle_secondary_command_result({:error, reason}) do
    IO.puts(D.error("Error executing secondary command: #{inspect(reason)}"))
  end
end
