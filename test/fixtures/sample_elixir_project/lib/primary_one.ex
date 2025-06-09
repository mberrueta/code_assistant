defmodule PrimaryOne do
  alias PrimaryOne.HelperA
  alias PrimaryOne.HelperB
  # This will be converted to a path but should not be found in project_files
  alias PrimaryOne.NonExistentHelper
  # This should be ignored as it doesn't start with PrimaryOne
  alias ExternalLib.Something
  # Aliasing itself, should be filtered out
  alias PrimaryOne
end
