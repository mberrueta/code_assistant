defmodule CodeAssistan.Tasks.Elixir do
  @moduledoc "A utility module for Elixir-related file and code tasks."

  @base_read_files ["assets/prompts/elixir.md"]
  def base_read_files, do: @base_read_files

  @doc """
   Execute the elixir task.
  Will add the Elixir related file paths to the context

  Example:
   context = %{
    filters: nil,
    task: "Generate tests",
    language: "Elixir",
    positive_prompt: "This is an example",
    negative_prompt: nil
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
    |> add_project_files()
    |> add_primary_files()
    |> add_global_files()
    |> add_readonly_files()
  end

  defp add_project_files(context) do
    project_files =
      Path.wildcard("**/*.{ex,exs}")
      |> Enum.reject(fn path ->
        # Exclude common build/dependency dirs and also test directories for this task
        Enum.any?(["deps/", "priv/", "_build/", "test/"], &String.starts_with?(path, &1))
      end)
      |> Enum.sort()

    context
    |> Map.put(:project_files, project_files)
  end

  # Files that aider will work with
  defp add_primary_files(%{filters: filters} = context)
       when is_binary(filters) and filters != "" do
    context
    |> Map.put(
      :primary_files,
      context.project_files
      |> Enum.filter(&String.contains?(&1, filters))
    )
  end

  defp add_primary_files(context), do: Map.put(context, :primary_files, context.project_files)

  defp add_global_files(context), do: Map.put(context, :global_readonly_files, @base_read_files)

  defp add_readonly_files(context) do
    readonly_map =
      Enum.reduce(context.primary_files, %{}, fn primary_file_path, acc ->
        related_files =
          extract_related_files_for(primary_file_path, context.project_files)

        if Enum.any?(related_files) do
          Map.put(acc, primary_file_path, related_files)
        else
          acc
        end
      end)

    Map.put(context, :readonly_files, readonly_map)
  end

  defp extract_related_files_for(primary_file_path, all_project_files) do
    # Ensure primary_file_path itself is absolute for File.read, or relative to CWD
    # In tests, CWD is the fixture dir, so relative paths are fine.
    case File.read(primary_file_path) do
      {:ok, content} ->
        with {:ok, main_module_base} <- extract_main_module_base(content) do
          content
          |> extract_related_aliases(main_module_base)
          |> Enum.map(&module_to_elixir_path/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.filter(&(&1 != primary_file_path and Enum.member?(all_project_files, &1)))
          |> Enum.uniq()
          |> Enum.sort()
        else
          # No main module base found or other issue
          _error -> []
        end

      {:error, _reason} ->
        # IO.puts("Could not read file: #{primary_file_path}, reason: #{reason}")
        []
    end
  end

  defp extract_main_module_base(content) do
    case Regex.run(~r/defmodule\s+([A-Z][\w.]*)/, content, capture: :all_but_first) do
      [full_module_name | _] ->
        # Get the first part, e.g., "Pepe" from "Pepe.Something.Else" or "Pepe" from "Pepe"
        main_base = String.split(full_module_name, ".") |> List.first()
        {:ok, main_base}

      nil ->
        {:error, :no_module_definition_found}
    end
  end

  defp extract_related_aliases(content, main_module_base) do
    # This regex captures the full module name, e.g., "PrimaryOne.HelperA" or "PrimaryOne"
    # The capturing group is (PrimaryOne(?:\.[\w.]+)?), which is the full module name.
    module_capture_regex = ~r/alias\s+(#{Regex.escape(main_module_base)}(?:\.[\w.]+)?)\b/

    content
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      # Regex.scan returns a list of lists of captures, e.g., [["PrimaryOne.HelperA"], ["PrimaryOne.HelperB"]]
      # Each inner list contains the string captured by the first (and only) capturing group.
      Regex.scan(module_capture_regex, line, capture: :all_but_first)
      # Extracts the module name string
      |> Enum.map(fn [module_name] -> module_name end)
    end)
    # Ensure unique module names
    |> Enum.uniq()
  end

  # Converts a module string like "MySystem.MyModule" to "lib/my_system/my_module.ex"
  # or "MySystem" to "lib/my_system.ex"
  defp module_to_elixir_path(module_string) do
    parts = String.split(module_string, ".") |> Enum.map(&Macro.underscore/1)

    case parts do
      [] ->
        # Should not happen for valid module strings
        nil

      [single_filename_part] ->
        # e.g., "MySystem" (module) -> "my_system" (part) -> "lib/my_system.ex" (path)
        Path.join("lib", "#{single_filename_part}.ex")

      [root_dir_part | path_segments] ->
        # e.g., "MySystem.MyModule" -> parts: ["my_system", "my_module"]
        # root_dir_part = "my_system"
        # path_segments = ["my_module"]
        # filename_part = List.last(path_segments) -> "my_module"
        # sub_dirs = List.delete_at(path_segments, -1) -> []
        # Path: lib/my_system/my_module.ex

        # e.g., "MySystem.MyDir.MyModule" -> parts: ["my_system", "my_dir", "my_module"]
        # root_dir_part = "my_system"
        # path_segments = ["my_dir", "my_module"]
        # filename_part = "my_module"
        # sub_dirs = ["my_dir"]
        # Path: lib/my_system/my_dir/my_module.ex
        filename = List.last(path_segments) <> ".ex"
        sub_directories = List.delete_at(path_segments, -1)
        Path.join(["lib", root_dir_part] ++ sub_directories ++ [filename])
    end
  end
end
