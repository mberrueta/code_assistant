defmodule CodeAssistantTest do
  use ExUnit.Case
  doctest CodeAssistant

  test "greets the world" do
    assert CodeAssistant.hello() == :world
  end
end
