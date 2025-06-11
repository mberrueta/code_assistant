defmodule CodeAssistan.Tasks.ElixirTest do
  # Use async: false because of File.cd!
  use ExUnit.Case, async: false

  @all_fixture_project_files [
                               "a.ex",
                               "another.ex",
                               "b.exs",
                               "debug_single_file.ex",
                               "lib/d.ex",
                               "lib/primary_four/helper_d.ex",
                               # Renamed from primary_four_dot_alias.ex
                               "lib/primary_four/sub_module.ex",
                               "lib/primary_four/sub_module/helper_e.ex",
                               # Renamed from primary_one.ex
                               "lib/primary_one.ex",
                               "lib/primary_one/helper_a.ex",
                               "lib/primary_one/helper_b.ex",
                               # Renamed
                               "lib/primary_three_no_relevant_aliases.ex",
                               # Stays at root of fixture
                               "primary_two_no_module.ex",
                               "test/non_existent_source_test.exs",
                               "test/primary_four_sub_module_test.exs",
                               "test/primary_one_test.exs",
                               "test/primary_three_no_relevant_aliases_test.exs"
                             ]
                             |> Enum.sort()

  # Removed alias CodeAssistan.Tasks.Elixir to use full name directly

  test "base_read_files/0 returns the configured base files" do
    assert CodeAssistan.Tasks.Elixir.base_read_files() == ["assets/prompts/elixir.md"]
  end

  describe "call/1" do
    setup do
      original_cwd = File.cwd!()
      # Define the path to the fixture project relative to the project root
      fixture_project_path =
        Path.join([original_cwd, "test", "fixtures", "sample_elixir_project"])

      # Change CWD so Path.wildcard in SUT works relative to the fixture project
      File.cd!(fixture_project_path)

      on_exit(fn ->
        # Change back to original CWD
        File.cd!(original_cwd)
        # No need to clean up files as they are static fixtures
      end)

      :ok
    end

    test "when filter targets a single specific project file" do
      context = %{
        # Updated filter to reflect new path
        filters: "lib/primary_one.ex",
        task: "Generate tests",
        language: "Elixir"
      }

      # Updated expectation
      expected_primary_files = ["lib/primary_one.ex"]

      result_context = CodeAssistan.Tasks.Elixir.call(context)
      assert Map.get(result_context, :project_files) == @all_fixture_project_files
      assert Map.get(result_context, :primary_files) == expected_primary_files
      assert Map.get(result_context, :global_readonly_files) == ["assets/prompts/elixir.md"]

      assert Map.get(result_context, :readonly_files) == %{
               "lib/primary_one.ex" => [
                 "lib/primary_one/helper_a.ex",
                 "lib/primary_one/helper_b.ex"
               ]
             }
    end

    test "when no filter is provided, includes all valid project files sorted" do
      context = %{
        filters: nil,
        task: "Generate tests",
        language: "Elixir"
      }

      result_context = CodeAssistan.Tasks.Elixir.call(context)

      assert Map.get(result_context, :project_files) == @all_fixture_project_files
      # When no filter, primary_files equals project_files
      assert Map.get(result_context, :primary_files) == @all_fixture_project_files
      assert Map.get(result_context, :global_readonly_files) == ["assets/prompts/elixir.md"]

      # Assert readonly_files (will be populated based on all project files becoming primary files)
      expected_readonly_files = %{
        # Path updated
        "lib/primary_one.ex" => ["lib/primary_one/helper_a.ex", "lib/primary_one/helper_b.ex"],
        # Path updated
        "lib/primary_four/sub_module.ex" => [
          "lib/primary_four/helper_d.ex",
          "lib/primary_four/sub_module/helper_e.ex"
        ]
      }

      assert Map.get(result_context, :readonly_files) == expected_readonly_files
    end

    test "when a filter is provided, filters primary_files and readonly_files accordingly" do
      context = %{
        # Filter for files containing "primary_one" in their path
        filters: "primary_one",
        task: "Generate tests",
        language: "Elixir"
      }

      # Only "lib/primary_one.ex", "lib/primary_one/helper_a.ex", "lib/primary_one/helper_b.ex" contain "primary_one"
      # Path updated
      expected_primary_files =
        [
          "lib/primary_one.ex",
          "lib/primary_one/helper_a.ex",
          "lib/primary_one/helper_b.ex",
          "test/primary_one_test.exs"
        ]
        |> Enum.sort()

      result_context = CodeAssistan.Tasks.Elixir.call(context)

      assert Map.get(result_context, :project_files) == @all_fixture_project_files
      assert Map.get(result_context, :primary_files) == expected_primary_files
      assert Map.get(result_context, :global_readonly_files) == ["assets/prompts/elixir.md"]

      # Assert readonly_files (only primary_one.ex from expected_primary_files will be processed)
      # lib/primary_one/helper_a.ex and lib/primary_one/helper_b.ex are primary files too,
      # but they don't alias other project files in this test setup.
      expected_readonly_files = %{
        # Path updated
        "lib/primary_one.ex" => ["lib/primary_one/helper_a.ex", "lib/primary_one/helper_b.ex"]
      }

      assert Map.get(result_context, :readonly_files) == expected_readonly_files
    end

    test "when a filter matches multiple files including those with aliases" do
      context = %{
        # Matches all .ex files
        filters: ".ex",
        task: "Generate tests",
        language: "Elixir"
      }

      # Files containing ".ex" become primary files
      expected_primary_files =
        Enum.filter(@all_fixture_project_files, &String.contains?(&1, ".ex")) |> Enum.sort()

      result_context = CodeAssistan.Tasks.Elixir.call(context)

      assert Map.get(result_context, :project_files) == @all_fixture_project_files
      assert Map.get(result_context, :primary_files) == expected_primary_files
      assert Map.get(result_context, :global_readonly_files) == ["assets/prompts/elixir.md"]

      expected_readonly_files = %{
        # Path updated
        "lib/primary_one.ex" => ["lib/primary_one/helper_a.ex", "lib/primary_one/helper_b.ex"],
        # Path updated
        "lib/primary_four/sub_module.ex" => [
          "lib/primary_four/helper_d.ex",
          "lib/primary_four/sub_module/helper_e.ex"
        ]
      }

      assert Map.get(result_context, :readonly_files) == expected_readonly_files
    end

    test "when a filter matches no files, primary_files and readonly_files are empty" do
      context = %{
        filters: "nonexistent_string_pattern",
        task: "Generate tests",
        language: "Elixir"
      }

      result_context = CodeAssistan.Tasks.Elixir.call(context)

      assert Map.get(result_context, :project_files) == @all_fixture_project_files
      assert Map.get(result_context, :primary_files) == []
      assert Map.get(result_context, :global_readonly_files) == ["assets/prompts/elixir.md"]
      assert Map.get(result_context, :readonly_files) == %{}
    end

    test "when filter is an empty string, behaves like no filter" do
      context = %{
        filters: "", # Empty string filter
        task: "Generate tests",
        language: "Elixir"
      }

      result_context = CodeAssistan.Tasks.Elixir.call(context)

      assert Map.get(result_context, :project_files) == @all_fixture_project_files
      # When filter is empty string, primary_files equals project_files
      assert Map.get(result_context, :primary_files) == @all_fixture_project_files
      assert Map.get(result_context, :global_readonly_files) == ["assets/prompts/elixir.md"]

      # Assert readonly_files (will be populated based on all project files becoming primary files)
      expected_readonly_files = %{
        "lib/primary_one.ex" => ["lib/primary_one/helper_a.ex", "lib/primary_one/helper_b.ex"],
        "lib/primary_four/sub_module.ex" => [
          "lib/primary_four/helper_d.ex",
          "lib/primary_four/sub_module/helper_e.ex"
        ]
      }

      assert Map.get(result_context, :readonly_files) == expected_readonly_files
    end

    test "excludes files from _build, deps, and priv directories" do
      # These paths are relative to the fixture_project_path due to File.cd! in setup
      excluded_dirs = ["_build", "deps", "priv"]

      excluded_files_to_create =
        Enum.map(excluded_dirs, fn dir ->
          Path.join(dir, "excluded_#{dir}_file.ex")
        end)

      # Setup: Create dummy directories and files
      Enum.each(excluded_dirs, &File.mkdir_p!/1)

      Enum.each(excluded_files_to_create, fn file_path ->
        File.write!(file_path, "defmodule Excluded.#{Macro.camelize(Path.basename(file_path, ".ex"))} do end")
      end)

      # Defer cleanup to ensure it runs even if assertions fail
      on_exit(fn ->
        Enum.each(excluded_files_to_create, &File.rm/1)
        Enum.each(excluded_dirs, &File.rm_rf!/1) # Use rm_rf! to remove directories and their contents
      end)

      context = %{
        filters: nil, # No filter, so all discoverable files should be considered
        task: "AnyTask",
        language: "Elixir"
      }

      result_context = CodeAssistan.Tasks.Elixir.call(context)
      project_files = Map.get(result_context, :project_files)

      # Assert: Excluded files are not present
      for excluded_file <- excluded_files_to_create do
        refute Enum.member?(project_files, excluded_file),
               "File #{excluded_file} should have been excluded but was found in project_files."
      end

      # Assert: All expected non-excluded files are present and no other files are included
      # @all_fixture_project_files is already sorted, and add_project_files also sorts its output.
      assert project_files == @all_fixture_project_files,
             "Project files list should match @all_fixture_project_files after excluding temporary files."
    end
  end

  describe "call/1 with an empty project directory" do
    setup do
      original_cwd = File.cwd!()

      # Create a unique temporary directory for the empty project scenario
      # Path.join is used to ensure OS-agnostic path construction.
      # System.unique_integer ensures the directory name is unique to avoid conflicts.
      temp_dir_name = "test_empty_project_#{System.unique_integer([:positive])}"
      empty_project_path = Path.join(original_cwd, temp_dir_name)

      File.mkdir_p!(empty_project_path)
      File.cd!(empty_project_path)

      on_exit(fn ->
        File.cd!(original_cwd)
        File.rm_rf!(empty_project_path)
      end)

      :ok
    end

    test "handles empty project directory by returning empty file lists" do
      context = %{
        filters: nil, # No specific filters, should process all (none) files
        task: "AnyTask",
        language: "Elixir"
      }

      result_context = CodeAssistan.Tasks.Elixir.call(context)

      assert Map.get(result_context, :project_files) == []
      assert Map.get(result_context, :primary_files) == []
      assert Map.get(result_context, :global_readonly_files) == ["assets/prompts/elixir.md"]
      assert Map.get(result_context, :readonly_files) == %{}
    end
  end
end
