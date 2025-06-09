defmodule CodeAssistant.CLI do
  alias Owl.Data, as: D
  alias Owl.IO

  # The main entry point for the command-line application.
  def main(_args) do
    workflow_data =
      :ok
      |> select_language()
      |> select_task()
      |> get_prompts()
      |> select_filters()

    # Display a summary of the collected information.
    display_summary(workflow_data)
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
  end
end
