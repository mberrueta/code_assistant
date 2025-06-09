defmodule CodeAssistan.Tasks.ElixirTestsTest do
  use ExUnit.Case, async: false

  alias CodeAssistan.Tasks.ElixirTests

  # All project files in the fixture directory, including new test files
  # and reflecting the renamed source files.
  @all_fixture_project_files [
    "a.ex",
    "another.ex",
    "b.exs",
    "debug_single_file.ex",
    "lib/d.ex",
    "lib/primary_four/helper_d.ex",
    "lib/primary_four/sub_module.ex",
    "lib/primary_four/sub_module/helper_e.ex",
    "lib/primary_one.ex",
    "lib/primary_one/helper_a.ex",
    "lib/primary_one/helper_b.ex",
    "lib/primary_three_no_relevant_aliases.ex",
    "primary_two_no_module.ex",
    "test/non_existent_source_test.exs",
    "test/primary_four_sub_module_test.exs",
    "test/primary_one_test.exs",
    "test/primary_three_no_relevant_aliases_test.exs"
  ]

  setup do
    original_cwd = File.cwd!()
    fixture_project_path = Path.join([original_cwd, "test", "fixtures", "sample_elixir_project"])
    File.cd!(fixture_project_path)

    on_exit(fn ->
      File.cd!(original_cwd)
    end)

    # Base context simulating output from CodeAssistan.Tasks.Elixir.call/1
    # For most tests, :primary_files will be overridden.
    # :readonly_files from Elixir.call/1 is assumed to be %{} or handled if pre-filled.
    base_context = %{
      project_files: @all_fixture_project_files,
      # To be set per test
      primary_files: [],
      # From Elixir.call/1
      global_readonly_files: ["assets/prompts/elixir.md"],
      # Assume empty from Elixir.call/1 for simplicity here
      readonly_files: %{},
      positive_prompt: nil,
      negative_prompt: nil,
      # Other keys that might be present
      language: "Elixir",
      task: "Generate tests"
    }

    {:ok, base_context: base_context}
  end

  describe "call/1" do
    test "appends global readonly files and sets default prompts", %{base_context: base_context} do
      context = %{base_context | primary_files: ["test/primary_one_test.exs"]}
      result = ElixirTests.call(context)

      expected_globals =
        (base_context.global_readonly_files ++ ElixirTests.test_base_files())
        |> Enum.uniq()
        |> Enum.sort()

      assert Map.get(result, :global_readonly_files) == expected_globals
      assert Map.get(result, :positive_prompt) == ElixirTests.default_positive_prompt()
      assert Map.get(result, :negative_prompt) == ElixirTests.default_negative_prompt()
    end

    test "does not overwrite existing prompts", %{base_context: base_context} do
      context = %{
        base_context
        | primary_files: ["test/primary_one_test.exs"],
          positive_prompt: "custom positive",
          negative_prompt: "custom negative"
      }

      result = ElixirTests.call(context)

      assert Map.get(result, :positive_prompt) == "custom positive"
      assert Map.get(result, :negative_prompt) == "custom negative"
    end

    test "enhances readonly_files for a test file with source and related modules", %{
      base_context: base_context
    } do
      # primary_one.ex (source for primary_one_test.exs) aliases HelperA and HelperB
      context = %{base_context | primary_files: ["test/primary_one_test.exs"]}
      result = ElixirTests.call(context)

      expected_readonly = %{
        "test/primary_one_test.exs" =>
          [
            # Source file
            "lib/primary_one.ex",
            # Related to source
            "lib/primary_one/helper_a.ex",
            # Related to source
            "lib/primary_one/helper_b.ex"
          ]
          |> Enum.sort()
      }

      assert Map.get(result, :readonly_files) == expected_readonly
    end

    test "enhances readonly_files for a test file with complex related modules", %{
      base_context: context
    } do
      # primary_four/sub_module.ex (source for test) aliases HelperD and SubModule.HelperE
      context = %{context | primary_files: ["lib/primary_one.ex"]}
      result = ElixirTests.call(context)

      expected_readonly =
        %{
          "lib/primary_one.ex" => [
            "lib/primary_one.ex",
            "lib/primary_one/helper_a.ex",
            "lib/primary_one/helper_b.ex"
          ]
        }

      assert Map.get(result, :readonly_files) == expected_readonly
    end

    test "enhances readonly_files when source file does not exist", %{base_context: base_context} do
      context = %{base_context | primary_files: ["test/non_existent_source_test.exs"]}
      result = ElixirTests.call(context)
      # No source file, so no additions to readonly_files for this key from enhance_readonly_files
      # The key itself might be added with an empty list if it wasn't there, or remain empty.
      # Current ElixirTests logic: if updated_readonly_for_test is empty, it might not add the key.
      # Let's check: `if Enum.any?(updated_readonly_for_test)`
      # If it's empty, the key is not added unless it was pre-existing with content.
      # If `context.readonly_files` was `%{}` initially, it should remain `%{}`.
      assert Map.get(result, :readonly_files) == %{}
    end

    test "enhances readonly_files when source file has no relevant aliases", %{
      base_context: base_context
    } do
      # primary_three_no_relevant_aliases.ex is source for primary_three_no_relevant_aliases_test.exs
      # Updated primary file
      context = %{
        base_context
        | primary_files: ["test/primary_three_no_relevant_aliases_test.exs"]
      }

      result = ElixirTests.call(context)

      expected_readonly = %{
        # Updated key
        "test/primary_three_no_relevant_aliases_test.exs" =>
          [
            # Only the source file
            "lib/primary_three_no_relevant_aliases.ex"
          ]
          |> Enum.sort()
      }

      assert Map.get(result, :readonly_files) == expected_readonly
    end

    test "merges with pre-existing readonly_files from Elixir.call/1", %{
      base_context: base_context
    } do
      pre_existing_readonly = %{
        "test/primary_one_test.exs" => ["initial_related_to_test.ex"],
        # This should be preserved
        "other_test.exs" => ["other_related.ex"]
      }

      context = %{
        base_context
        | primary_files: ["test/primary_one_test.exs"],
          readonly_files: pre_existing_readonly
      }

      result = ElixirTests.call(context)

      expected_readonly = %{
        "test/primary_one_test.exs" =>
          [
            # From pre-existing
            "initial_related_to_test.ex",
            "lib/primary_one.ex",
            "lib/primary_one/helper_a.ex",
            "lib/primary_one/helper_b.ex"
          ]
          |> Enum.uniq()
          |> Enum.sort(),
        # Preserved
        "other_test.exs" => ["other_related.ex"]
      }

      assert Map.get(result, :readonly_files) == expected_readonly
    end

    test "handles multiple primary test files correctly", %{base_context: base_context} do
      context = %{
        base_context
        | # Updated primary file
          primary_files: [
            "test/primary_one_test.exs",
            "test/primary_three_no_relevant_aliases_test.exs",
            "test/non_existent_source_test.exs"
          ]
      }

      result = ElixirTests.call(context)

      expected_readonly = %{
        "test/primary_one_test.exs" =>
          [
            "lib/primary_one.ex",
            "lib/primary_one/helper_a.ex",
            "lib/primary_one/helper_b.ex"
          ]
          |> Enum.sort(),
        # Updated key
        "test/primary_three_no_relevant_aliases_test.exs" =>
          [
            "lib/primary_three_no_relevant_aliases.ex"
          ]
          |> Enum.sort()
        # "test/non_existent_source_test.exs" will not have an entry if its list is empty
      }

      assert Map.get(result, :readonly_files) == expected_readonly
    end
  end
end
