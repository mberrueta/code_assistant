defmodule CodeAssistan.Tasks.ElixirTests do
  @moduledoc "A utility module for ElixirTest-related file and code tasks."
  @behaviour CodeAssistan.Tasks.ElixirTestsBehaviour

  @test_base_files [
    "assets/prompts/elixir_tests.md",
    "test/support/factories/factory.ex",
    "test/test_helper.exs"
  ]
  def test_base_files(), do: @test_base_files

  @doc """
   Execute the elixir task.
  Will add the Elixir related file paths to the context

  Example:
   context = %{
    filters: nil,
    task: "Generate tests",
    language: "Elixir",
    positive_prompt: "This is an example",
    project_files: ["a.ex", "b.ex", "c.ex"]
    primary_files: ["a.ex"],
    global_readonly_files: ["z.md"],
    readonly_files: %{"a.ex" => "c.ex"},
  }

  CodeAssistan.Tasks.Elixir.call(context)
   %{
      ...
      project_files: ["a.ex", "b.ex", "c.ex"]
      primary_files: ["a.ex"],
      global_readonly_files: ["z.md"],
      readonly_files: %{"a.ex" => "c.ex"},
    }
  """
  def call(context) do
    context
    |> append_global_readonly_files()
    |> enhance_readonly_files()
    |> add_default_prompts()
  end

  defp append_global_readonly_files(context) do
    existing_globals = Map.get(context, :global_readonly_files, []) |> List.wrap()
    new_globals = (existing_globals ++ @test_base_files) |> Enum.uniq() |> Enum.sort()
    Map.put(context, :global_readonly_files, new_globals)
  end

  defp enhance_readonly_files(context) do
    # Needed for filtering related files
    project_files = Map.get(context, :project_files, [])

    readonly_files_map =
      Enum.reduce(
        context.primary_files || [],
        context.readonly_files || %{},
        fn primary_test_file, acc ->
          current_readonly_for_test_key = Map.get(acc, primary_test_file, [])
          source_file_path = test_path_to_source_path(primary_test_file)
          file_exists_result = File.exists?(source_file_path)

          # Determine all files to be associated with this test file key
          all_files_for_this_test_key =
            if file_exists_result do
              # Start with any pre-existing files for this test key (current_readonly_for_test_key),
              # then add the source file and its related files.
              # Add the source file itself
              newly_derived_files = [source_file_path]

              related_to_source =
                extract_related_files_for_source(
                  source_file_path,
                  project_files,
                  primary_test_file
                )

              # Combine current (pre-existing for this key), the source file, and its related files
              current_readonly_for_test_key ++ newly_derived_files ++ related_to_source
            else
              # If source file doesn't exist, just use current readonly files for this key
              current_readonly_for_test_key
            end

          final_readonly_for_test = Enum.uniq(all_files_for_this_test_key) |> Enum.sort()

          new_acc =
            if Enum.empty?(final_readonly_for_test) do
              # If the list for this primary_test_file becomes empty,
              # remove its key from the accumulator.
              Map.delete(acc, primary_test_file)
            else
              # Otherwise, update the accumulator with the new list for this primary_test_file.
              Map.put(acc, primary_test_file, final_readonly_for_test)
            end

          # Explicitly return the new accumulator for the Enum.reduce
          new_acc
        end
      )

    Map.put(context, :readonly_files, readonly_files_map)
  end

  # Helper to find files related to a given source file
  defp extract_related_files_for_source(source_file_path, all_project_files, primary_test_file) do
    file_read_result = File.read(source_file_path)

    case file_read_result do
      {:ok, content} ->
        with {:ok, main_module_base} <- extract_main_module_base(content) do
          content
          |> extract_related_aliases(main_module_base)
          |> Enum.map(&module_to_elixir_path/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.filter(fn related_path ->
            related_path != source_file_path &&
              related_path != primary_test_file &&
              Enum.member?(all_project_files, related_path)
          end)
          |> Enum.uniq()

          # Sorting is handled when these are merged into the main readonly_files map
        else
          # No main module base found or other issue
          _error -> []
        end

      {:error, _reason} ->
        []
    end
  end

  # --- Copied from CodeAssistan.Tasks.Elixir ---
  defp extract_main_module_base(content) do
    case Regex.run(~r/defmodule\s+([A-Z][\w.]*)/, content, capture: :all_but_first) do
      [full_module_name | _] ->
        main_base = String.split(full_module_name, ".") |> List.first()
        {:ok, main_base}

      nil ->
        {:error, :no_module_definition_found}
    end
  end

  defp extract_related_aliases(content, main_module_base) do
    module_capture_regex = ~r/alias\s+(#{Regex.escape(main_module_base)}(?:\.[\w.]+)?)\b/

    content
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      Regex.scan(module_capture_regex, line, capture: :all_but_first)
      |> Enum.map(fn [module_name] -> module_name end)
    end)
    |> Enum.uniq()
  end

  defp module_to_elixir_path(module_string) do
    parts = String.split(module_string, ".") |> Enum.map(&Macro.underscore/1)

    case parts do
      [] ->
        nil

      [single_filename_part] ->
        Path.join("lib", "#{single_filename_part}.ex")

      [root_dir_part | path_segments] ->
        filename = List.last(path_segments) <> ".ex"
        sub_directories = List.delete_at(path_segments, -1)
        Path.join(["lib", root_dir_part] ++ sub_directories ++ [filename])
    end
  end

  # --- End of copied functions ---

  defp add_default_prompts(context) do
    context
    |> put_if_absent_or_empty(:positive_prompt, default_positive_prompt())
    |> put_if_absent_or_empty(:negative_prompt, default_negative_prompt())
  end

  # This helper remains private as it's only used by add_default_prompts
  defp put_if_absent_or_empty(context, key, value) do
    current_value = Map.get(context, key)

    if is_nil(current_value) or current_value == "" do
      Map.put(context, key, value)
    else
      context
    end
  end

  # --- No other changes are needed in this module's helper functions ---

  defp test_path_to_source_path(test_path) do
    test_path
    |> String.replace_prefix("test/", "lib/")
    |> String.replace_suffix("_test.exs", ".ex")
  end

  # Made public
  def default_positive_prompt() do
    """
    Please act as an expert Elixir developer.
    Analyze the corresponding source code module for the test file being edited.
    Identify any public functions that are not currently covered by a test case.
    Add new, high-quality tests for these missing functions.
    Ensure you test both happy paths (correct inputs) and unhappy paths (error cases, edge cases).
    """
  end

  # Made public
  def default_negative_prompt() do
    """
    Do not use basic `fixtures`. The project uses factories for test data setup.
    You must use ExMachina for creating test data structures.
    For mocking external services or dependencies, you must use Mox.
    Do not use the libraries 'mock' or 'bypass'.
    """
  end
end
