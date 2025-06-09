defmodule PrimaryOne do
  alias PrimaryOne.HelperA
  alias PrimaryOne.HelperB
  alias PrimaryOne.NonExistentHelper # This will be converted to a path but should not be found in project_files
  alias ExternalLib.Something      # This should be ignored as it doesn't start with PrimaryOne
  alias PrimaryOne                 # Aliasing itself, should be filtered out
end
