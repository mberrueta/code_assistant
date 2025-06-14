defmodule CodeAssistan.Tasks.CommandExecutor do
  @doc """
  Spawns a command in a new terminal window (Kitty or Tmux) and detaches,
  allowing the Elixir process to continue immediately.

  This function will NOT capture the output of the command, nor will it
  run post-execution checks, as it does not wait for completion.

  ## Arguments

    * `spawner`: The terminal to use. Can be `:kitty` or `:tmux`.
    * `aider_command_str`: The full command string to execute inside the new terminal.
    * `_data`: The overall context (unused in this detached version, but kept for API consistency).

  ## Returns

    * `{:ok, :spawned}` on success.
    * `{:error, :unsupported_spawner}` if the spawner is not recognized.

  ## Example

      CodeAssistan.Tasks.CommandExecutor.spawn_and_detach(
        :kitty,
        "aider lib/my_app/my_module.ex",
        %{language: "Elixir"}
      )
  """
  def spawn_and_detach(spawner, aider_command_str, _data) do
    case spawner do
      :kitty ->
        # Executes `kitty sh -c "your_command; exec $SHELL"`
        # This runs the aider_command_str, and once it finishes,
        # `exec $SHELL` replaces the current shell with a new interactive shell,
        # keeping the Kitty window open.
        # The `kitty` command itself exits quickly once the new window is created.
        System.cmd("kitty", ["sh", "-c", "#{aider_command_str}; exec $SHELL"])
        {:ok, :spawned}

      :tmux ->
        # Executes `tmux new-window "your_command..."`
        # This instructs a running tmux server to create a new window and run the
        # command. The `tmux` client command exits immediately.
        System.cmd("tmux", ["new-window", aider_command_str])
        {:ok, :spawned}

      _ ->
        {:error, :unsupported_spawner}
    end
  end
end
