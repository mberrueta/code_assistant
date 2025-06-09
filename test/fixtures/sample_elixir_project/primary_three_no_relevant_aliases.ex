defmodule PrimaryThree do
  alias External.Dependency # Should be ignored
  alias AnotherExternal.Lib # Should be ignored
  # No aliases starting with "PrimaryThree."
end
