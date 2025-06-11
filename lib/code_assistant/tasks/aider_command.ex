defmodule CodeAssistan.Tasks.AiderCommand do
  @moduledoc "A utility module for ElixirTest-related file and code tasks."
  @doc """
  Generates Aider command strings for each primary file in the context and
  adds them to the context under the :aider_commands key.

  The `:aider_commands` key will contain a map where each key is a primary file path
  and the value is the generated Aider command string for that file.

  Example:

  context = %{
    task: "Generate tests",
    language: "Elixir",
    project_files: ["a.ex", "another.ex", "b.exs", "debug_single_file.ex",
     "lib/d.ex", "lib/primary_four/helper_d.ex", "lib/primary_four/sub_module.ex",
     "lib/primary_four/sub_module/helper_e.ex", "lib/primary_one.ex",
     "lib/primary_one/helper_a.ex", "lib/primary_one/helper_b.ex",
     "lib/primary_three_no_relevant_aliases.ex", "primary_two_no_module.ex",
     "test/non_existent_source_test.exs", "test/primary_four_sub_module_test.exs",
     "test/primary_one_test.exs",
     "test/primary_three_no_relevant_aliases_test.exs"],
    primary_files: ["test/primary_one_test.exs"], # Example with one primary file
    global_readonly_files: ["assets/prompts/elixir.md",
     "assets/prompts/elixir_tests.md", "test/support/factories/factory.ex",
     "test/test_helper.exs"],
    readonly_files: %{
      "test/primary_one_test.exs" => ["lib/primary_one.ex",
       "lib/primary_one/helper_a.ex", "lib/primary_one/helper_b.ex"]
    },
    positive_prompt: "Please act as an expert Elixir developer.",
    negative_prompt: "Do not use basic `fixtures`. "
  }
  CodeAssistan.Tasks.AiderCommand.call(context)

  => %{
       task: "Generate tests",
       language: "Elixir",
       project_files: ["a.ex", "another.ex", "b.exs", "..."], # Contents as defined in context
       primary_files: ["test/primary_one_test.exs"],
       global_readonly_files: ["assets/prompts/elixir.md", "..."], # Contents as defined
       readonly_files: %{
         "test/primary_one_test.exs" => ["lib/primary_one.ex", "..."] # Contents as defined
       },
       positive_prompt: "Please act as an expert Elixir developer.",
       negative_prompt: "Do not use basic `fixtures`. ",
       aider_commands: %{
         "test/primary_one_test.exs" => "aider --read assets/prompts/elixir.md --read assets/prompts/elixir_tests.md --read test/support/factories/factory.ex --read test/test_helper.exs --read lib/primary_one.ex --read lib/primary_one/helper_a.ex --read lib/primary_one/helper_b.ex --file test/primary_one_test.exs --message \"Positive Prompt: Please act as an expert Elixir developer.\\n\\n\\nNegative Prompt: Do not use basic `fixtures`. \\n\\n\""
       }
     }
  """
  def call(context) do
    context
    |> Map.put(
      :aider_commands,
      Enum.reduce(context.primary_files, %{}, fn file_to_test, acc_commands ->
        acc_commands
        |> Map.put(file_to_test, do_gen_command(context, file_to_test))
      end)
    )
  end

  defp do_gen_command(context, file_to_test) do
    (["aider --yes"] ++
       add_read_file_args(context.global_readonly_files) ++
       add_read_file_args(context.readonly_files[file_to_test]) ++
       [add_target_file_arg(file_to_test)] ++
       [add_message_arg(context)])
    |> Enum.join(" ")
  end

  defp add_read_file_args(files), do: Enum.map(files, &"--read #{&1}")

  defp add_target_file_arg(file_to_test), do: "--file #{file_to_test}"

  defp add_message_arg(context) do
    positive_prompt = Map.get(context, :positive_prompt, "") |> String.trim()
    negative_prompt = Map.get(context, :negative_prompt, "") |> String.trim()

    has_positive_prompt = positive_prompt != ""
    has_negative_prompt = negative_prompt != ""

    message_content =
      cond do
        has_positive_prompt and has_negative_prompt ->
          "Things to do: #{positive_prompt}\n\n------Things to avoid: #{negative_prompt}"

        has_positive_prompt ->
          "Things to do: #{positive_prompt}"

        has_negative_prompt ->
          "Things to avoid: #{negative_prompt}"

        true ->
          ""
      end

    if String.trim(message_content) != "" do
      escaped_message =
        message_content
        |> String.replace("\\", "\\\\")
        |> String.replace("\"", "\\\"")

      "--message \"#{escaped_message}\""
    else
      ""
    end
  end
end
