defmodule CodeAssistant.CLI do
  alias CodeAssistan.Tasks.CommandExecutor
  alias Owl.Data, as: D
  alias Owl.IO

  # The main entry point for the command-line application.
  def main(_args) do
    :ok
    |> select_language()
    # New step to select the terminal
    |> select_spawner()
    |> select_task()
    |> get_prompts()
    |> select_filters()
    |> CodeAssistan.Tasks.Runner.call()
    |> display_summary()
    # Changed from confirm_aider_commands
    |> process_commands_interactively()
  end

  # Step 1: Prompt the user to select a programming language.
  defp select_language(:ok) do
    language =
      IO.select(["Elixir", "Ruby"])

    %{language: language}
  end

  # New Step: Prompt the user to select the terminal spawner.
  defp select_spawner(data) do
    spawner =
      IO.select(
        ["Kitty", "Tmux"],
        header: "Choose a terminal to spawn Aider in:"
      )
      |> String.downcase()
      |> String.to_atom()

    Map.put(data, :spawner, spawner)
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

  # Step 4: Filter project files.
  defp select_filters(data) do
    filters =
      Owl.IO.input(label: "filters(optional, press Enter to skip)", optional: true)

    Map.put(data, :filters, filters)
  end

  # Step 5: Display a summary of all the collected data.
  defp display_summary(data) do
    # ... (This function remains unchanged, so it's omitted for brevity)
    content = [
      D.tag("Language:", :cyan),
      " #{data.language}\n",
      D.tag("Spawner:", :cyan),
      # Display the spawner
      "  #{data.spawner |> Atom.to_string() |> String.capitalize()}\n",
      D.tag("Task:", :cyan),
      "     #{data.task}\n\n",
      D.tag("Prompt:", :cyan),
      "\n",
      "  #{data.positive_prompt}\n\n",
      D.tag("To Avoid:", :cyan),
      "\n",
      "  #{if data.negative_prompt == "", do: "None", else: data.negative_prompt}\n\n",
      D.tag("Filters:", :cyan),
      "   ",
      if(data.filters == [] or data.filters == "",
        do: "None",
        else: Enum.join(List.wrap(data.filters), ", ")
      )
    ]

    summary_box = Owl.Box.new(content, title: "Request Summary", border: :heavy)
    Owl.IO.puts(summary_box)
    data
  end

  # Step 6: Main interactive loop to process commands.
  defp process_commands_interactively(data) do
    aider_commands = Map.get(data, :aider_commands, %{}) |> Enum.to_list()

    cond do
      aider_commands == [] ->
        IO.puts("")
        IO.puts(D.tag("No Aider commands to execute.", :yellow))
        IO.puts("")
        data

      true ->
        count = length(aider_commands)
        IO.puts("")
        IO.puts(D.tag("Found #{count} Aider command(s) to review.", :green))
        IO.puts("")
        # Start the recursive loop
        command_loop(aider_commands, data)
        data
    end
  end

  # Recursive loop to handle one command at a time.
  defp command_loop([], _data) do
    IO.puts(D.tag("All commands have been processed.", :green))
    IO.puts("")
  end

  defp command_loop([{file_path, command_str} | rest], data) do
    IO.puts(D.tag(file_path, :cyan))
    IO.puts(D.tag(command_str, :yellow))
    IO.puts("")

    if IO.confirm(message: "Execute this command in a new #{data.spawner} window?") do
      # Enter the post-spawn menu and wait for user to choose to continue
      post_spawn_menu(file_path, command_str, data)
    else
      IO.puts(D.tag("Skipped.", :yellow))
      IO.puts("")
    end

    # Process the next command in the list
    command_loop(rest, data)
  end

  # lib/code_assistant/cli.ex

  # ... keep all other functions the same ...

  # CORRECTED VERSION of the post-spawn menu
  defp post_spawn_menu(file_path, command_str, data) do
    # Spawn the command first and handle the result safely
    case CommandExecutor.spawn_and_detach(data.spawner, command_str, data) do
      {:ok, :spawned} ->
        # --- SUCCESS PATH ---
        # This code now only runs if the command was spawned successfully.
        IO.puts(D.tag("✅ Command spawned in new #{data.spawner} window.", :green))
        IO.puts("")

        # Now show the menu of options
        choice =
          IO.select(
            ["Re-run Aider Command", "Run Associated Tests", "Continue to Next File"],
            header: "What would you like to do next for #{Path.basename(file_path)}?"
          )

        case choice do
          "Re-run Aider Command" ->
            IO.puts("")
            command_str = data[:aider_commands][file_path]
            # Recurse to re-run the same command and show the menu again
            post_spawn_menu(file_path, command_str, data)

          "Run Associated Tests" ->
            IO.puts("")
            command_str = test_command(file_path, data)
            # After tests, show the menu again for the same file
            post_spawn_menu(file_path, command_str, data)

          "Continue to Next File" ->
            IO.puts(D.tag("Continuing...", :blue))
            IO.puts("")
            # Return :ok to let command_loop proceed
            :ok
        end

      {:error, reason} ->
        # --- FAILURE PATH ---
        # If spawning fails, print an error and skip the menu for this item.
        # The main loop will then proceed to the next command.
        IO.puts(D.tag("❌ Error spawning command: #{inspect(reason)}", :red))
        IO.puts("")
        :ok
    end
  end

  defp test_command(file_path, data) do
    cond do
      data.language == "Elixir" && String.ends_with?(file_path, "_test.exs") ->
        "mix test #{file_path}"

      true ->
        # No specific action for other cases
        {:error, :no_specific_action}
    end
  end
end
