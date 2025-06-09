defmodule CodeAssistan.Tasks.AiderCommand do
  @moduledoc "A utility module for ElixirTest-related file and code tasks."
  @doc """
  Generate the aider command for a specific test

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
    primary_files: ["test/primary_one_test.exs"],
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

  => aider --read a --read b --file c --message "lorem"
  """
  def call(context) do
    context
    |> Map.put(
      :aider_commands,
      Enum.reduce(context.primary_files, context.aider_commands, fn file_to_test, acc_commands ->
        acc_commands
        |> Map.put(file_to_test, do_gen_command(context, file_to_test))
      end)
    )
  end

  defp do_gen_command(context, file_to_test) do
    (["aider"] ++
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
          "Positive Prompt: #{positive_prompt}\n\n\nNegative Prompt: #{negative_prompt}\n\n"

        has_positive_prompt ->
          "Positive Prompt: #{positive_prompt}\n\n"

        has_negative_prompt ->
          "Negative Prompt: #{negative_prompt}\n\n"

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
