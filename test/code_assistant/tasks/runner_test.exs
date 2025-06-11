defmodule CodeAssistan.Tasks.RunnerTest do
  use ExUnit.Case, async: true

  alias CodeAssistan.Tasks.Runner

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

    test "when language is Elixir and task is 'Generate tests'" do
      initial_context = %{
        language: "Elixir",
        task: "Generate tests",
        positive_prompt: "test prompt",
        filters: "lib/primary_one.ex"
      }

      assert Runner.call(initial_context).aider_commands == %{
               "lib/primary_one.ex" =>
                 "aider --read assets/prompts/elixir.md --read assets/prompts/elixir_tests.md --read test/support/factories/factory.ex --read test/test_helper.exs --read lib/primary_one.ex --read lib/primary_one/helper_a.ex --read lib/primary_one/helper_b.ex --file lib/primary_one.ex --message \"Things to do: test prompt\n\n------Things to avoid: Do not use basic `fixtures`. The project uses factories for test data setup.\nYou must use ExMachina for creating test data structures.\nFor mocking external services or dependencies, you must use Mox.\nDo not use the libraries 'mock' or 'bypass'.\""
             }
    end
  end
end
