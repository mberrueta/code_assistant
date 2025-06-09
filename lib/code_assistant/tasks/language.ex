defmodule CodeAssistan.Tasks.Language do
  @moduledoc """
  This execute the proper language
  """

  alias CodeAssistan.Tasks.Elixir, as: E

  def call(%{language: "elixir"} = context), do: E.call(context)
end
