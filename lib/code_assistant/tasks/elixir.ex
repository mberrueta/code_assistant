defmodule CodeAssistan.Tasks.Elixir do
  @moduledoc "A utility module for Elixir-related file and code tasks."

  @base_read_files [
    "assets/prompts/elixir.md"
  ]
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
  end

  defp add_project_files(context) do
    project_files =
      Path.wildcard("**/*.{ex,exs}")
      |> Enum.reject(fn path ->
        Enum.any?(["deps/", "priv/", "_build"], &String.starts_with?(path, &1))
      end)
      |> Enum.sort()

    context
    |> Map.put(:project_files, project_files)
  end

  # Files that aider will work with
  defp add_primary_files(%{filters: filters} = context) do
    context
    |> Map.put(
      :primary_files,
      context.project_files
      |> Enum.filter(&String.contains?(&1, filters))
    )
  end

  defp add_primary_files(context), do: Map.put(context, :primary_files, context.project_files)

  defp extract_related_modules(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&String.starts_with?(&1, "alias DoctorSmart."))
        |> Enum.map(fn alias_line ->
          module_string = String.split(alias_line, " ") |> List.last()
          module_to_path(module_string)
        end)
        |> Enum.reject(&is_nil/1)

      {:error, _reason} ->
        []
    end
  end

  defp module_to_path("DoctorSmart." <> rest) do
    path_part = String.split(rest, ".") |> Enum.map(&String.downcase/1) |> Path.join()
    "lib/doctor_smart/#{path_part}.ex"
  end

  defp module_to_path(_), do: nil
end
