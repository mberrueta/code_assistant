# **Elixir Style Guide & Best Practices (for AI Refactoring)**

This document outlines good and bad practices for Elixir code. When requesting refactoring or code modifications, please adhere to these principles to ensure the output aligns with preferred Elixir idiomatic patterns and maintainable code.

## **Good Elixir Practices**

* **Purity in Functions:**  
  * Aim for pure functions (given the same input, always return the same output; no side effects).  
  * Isolate side effects to specific boundaries (e.g., GenServer callbacks, Task supervision trees).  
* **Embrace Pattern Matching & Access:**  
  * Use pattern matching extensively for function heads, case statements, and argument destructuring.  
  * It leads to more explicit, readable, and robust code.  
  * Prefer direct access (map\[:key\]) over Map.get/2 or Keyword.get/2 when applicable, as it's more idiomatic and flexible for different collection types.

**Example (Access):**\# Don't: Locks into specific data structure  
opts \= %{foo: :bar}  
Map.get(opts, :foo)

\# Do: More flexible and idiomatic  
opts \= %{foo: :bar}  
opts\[:foo\] \# Returns :bar

* **Favor Immutability:**  
  * Recognize that all data in Elixir is immutable.  
  * Transform data rather than modifying it in place.  
* **Use with for Happy Paths:**  
  * When dealing with multiple potential failure points in a sequence, use the with macro to handle the "happy path" cleanly.  
  * Use else for handling various failure outcomes, but be mindful not to overcomplicate the else block, as with is primarily for the happy path.

**Example (using with for happy path):**\# Don't: Spreads error handling and makes control flow less clear  
def main do  
  data  
  |\> call\_service  
  |\> parse\_response  
  |\> handle\_result  
end

defp call\_service(data) do \# ... returns {:ok, response} or {:error, reason} end  
  {:ok, "{\\"key\\": \\"value\\"}"} \# Example success  
end

defp parse\_response({:ok, result}), do: Jason.decode(result)  
defp parse\_response(error), do: error \# Propagate error

defp handle\_result({:ok, decoded}), do: decoded  
defp handle\_result({:error, error}), do: raise error \# Raises error on failure

\# Do: Clear happy path with explicit error handling for each step  
def main do  
  with {:ok, response} \<- call\_service("some data"),  
       {:ok, decoded} \<- Jason.decode(response) do  
    decoded  
  else  
    {:error, %Jason.Error{} \= error} \-\> {:error, {:json\_error, error}}  
    {:error, %ServiceError{} \= error} \-\> {:error, {:service\_error, error}}  
    error \-\> error \# Catch-all for other errors  
  end  
end

* **Clear Function Names:**  
  * Functions should have clear, descriptive names that indicate their purpose and what they return.  
  * Follow Erlang's convention for functions that return a {:ok, value} or {:error, reason} tuple (e.g., do\_something/1, do\_something\!/1).  
* **Explicit nil Handling:**  
  * Avoid functions that implicitly return nil if something isn't found or an operation fails.  
  * Prefer returning {:ok, value} and {:error, reason} tuples.  
* **Supervisor Trees for Resilience:**  
  * Organize processes into supervisor trees for fault tolerance and self-healing applications.  
  * Understand different restart strategies (one\_for\_one, one\_for\_all, rest\_for\_one, simple\_one\_for\_one).  
* **Small, Focused Modules:**  
  * Break down logic into small, single-responsibility modules.  
  * Avoid large, monolithic modules.  
* **Pipe Operator (|\>) for Readability & Explicitness:**  
  * Use the pipe operator to chain function calls, improving readability by showing data flow.  
  * Prefer piping directly into higher-order functions (like Enum.map, Enum.reduce) rather than hiding them inside wrapper functions.

**Example (Exposing Higher-Order Functions):**\# Don't: Hides the higher-order functions, making the pipeline less explicit  
def main do  
  collection  
  |\> parse\_items  
  |\> add\_items  
end

def parse\_items(list) do  
  Enum.map(list, \&String.to\_integer/1)  
end

def add\_items(list) do  
  Enum.reduce(list, 0, &(&1 \+ &2))  
end

\# Do: Clearly shows the operations in the pipeline  
def main do  
  collection  
  |\> Enum.map(\&parse\_item/1)  
  |\> Enum.reduce(0, \&add\_item/2)  
end

defp parse\_item(item), do: String.to\_integer(item)  
defp add\_item(num, acc), do: num \+ acc

* **Guard Clauses for Preconditions:**  
  * Use when clauses (guards) to define preconditions for function execution, making logic clearer and more concise.  
* **Explicit Alias Statements:**  
  * Prefer declaring each alias on its own line for better clarity and easier code management, especially when dealing with many aliases.

**Example (Alias Statements):**\# Don't: Combined alias statement  
alias MyApp.Accounts.{User, Profile, AuthToken}

\# Do: Separate alias statements  
alias MyApp.Accounts.User  
alias MyApp.Accounts.Profile  
alias MyApp.Accounts.AuthToken

* **Group and Sort use, require, import, and alias Statements:**  
  * Organize these statements by type (e.g., all use statements together, then all require, etc.).  
  * Within each type, sort them alphabetically for consistent readability and easier navigation.

**Example (Grouped and Sorted Statements):**\# Don't: Mixed order and un-sorted  
alias MyApp.Repo  
import Ecto.Query  
use Ecto.Schema  
alias MyApp.User  
require Logger

\# Do: Grouped and sorted  
use Ecto.Schema

require Logger

import Ecto.Query

alias MyApp.Repo  
alias MyApp.User

* **HEEX HTML Attributes for Control Flow:**  
  * When writing HEEX templates, prefer using HTML attributes like :if={} and :for={} for control flow (conditionals and loops) instead of embedded Elixir tags (\<% %\>). This leads to cleaner, more HTML-like syntax.

**Example (HEEX Control Flow):**\<\!-- Don't: Embedded Elixir tags for control flow \--\>  
\<% if @user.is\_admin? do %\>  
  \<button\>Admin Action\</button\>  
\<% end %\>

\<% for item \<- @items do %\>  
  \<li\>\<%= item.name %\>\</li\>  
\<% end %\>

\<\!-- Do: HTML attributes for control flow \--\>  
\<button :if={@user.is\_admin?}\>Admin Action\</button\>

\<li :for={item \<- @items}\>  
  {item.name}  
\</li\>

* **Polymorphic Filtering/Querying Functions:**  
  * Instead of creating many specialized functions (e.g., list\_by\_x, list\_by\_y), prefer a single, polymorphic function that uses pattern matching or case statements on keyword list options to apply various filters or query conditions. This makes your API cleaner and more extensible.

**Example (Polymorphic Filtering):**\# Don't: Multiple, specialized list functions  
def list\_app\_configurations\_by\_type(type), do: \# ...  
def list\_app\_configurations\_by\_config\_key(config\_key), do: \# ...

\# Do: Single function with multiple clauses for filtering/querying  
defp filter\_query(query, type: type) do  
  where(query, \[c\], c.type \== ^type)  
end

defp filter\_query(query, config\_key: config\_key) do  
  where(query, \[c\], c.config\_key \== ^config\_key)  
end

defp filter\_query(query, \_), do: query \# Catch-all for unhandled options

def list\_app\_configurations(opts \\\\ \[\]) do  
  \# Changed pmd to ac for clarity  
  query \= from(ac in AppConfiguration)

  \# Apply filters based on opts  
  query \=  
    Enum.reduce(opts, query, fn {key, value}, acc\_query \-\>  
      case key do  
        :type \-\> filter\_query(acc\_query, type: value)  
        :config\_key \-\> filter\_query(acc\_query, config\_key: value)  
        \# Ignore unknown keys or unhandled filter options  
        \_ \-\> acc\_query  
      end  
    end)

  Repo.all(query)  
end

* **Clear and Localized Schema Validations with Keys:**  
  * Use @required and @optional module attributes to clearly define schema fields.  
  * Always use **visible keys** for gettext error messages (e.g., gettext(".this\_is\_a\_key")) instead of plain English strings. This ensures consistency for translation and easier management of messages across your application.

**Example (Schema Validations):**@optional \~w(tax\_id prefix birth\_date gender picture notes)a  
@required \~w(user\_id first\_name last\_name)a

@doc false  
def changeset(person, attrs) do  
  person  
  |\> cast(attrs, @required \++ @optional)  
  |\> validate\_inclusion(:gender, gender\_options(),  
    message:  
      gettext(".gender\_invalid\_option",  
        options: Enum.join(gender\_options(), ", ")  
      )  
  )  
end

* **Leverage Existing Dependencies:**  
  * Prioritize using existing, well-tested libraries from your mix.exs dependencies over writing custom implementations for common functionalities. This reduces development time, relies on community-vetted solutions, and ensures consistency.

**Your Current Dependencies:**\[  
  {:bcrypt\_elixir, "\~\> 3.0"},  
  \# Defaults  
  {:phoenix, "\~\> 1.7.18"},  
  {:phoenix\_ecto, "\~\> 4.5"},  
  {:ecto\_sql, "\~\> 3.10"},  
  {:postgrex, "\>= 0.0.0"},  
  {:phoenix\_html, "\~\> 4.1"},  
  {:phoenix\_live\_reload, "\~\> 1.2", only: :dev},  
  {:phoenix\_live\_view, "\~\> 1.0.0"},  
  {:floki, "\>= 0.30.0", only: :test},  
  {:phoenix\_live\_dashboard, "\~\> 0.8.3"},  
  {:esbuild, "\~\> 0.8", runtime: Mix.env() \== :dev},  
  {:tailwind, "\~\> 0.2", runtime: Mix.env() \== :dev},  
  {:heroicons,  
    github: "tailwindlabs/heroicons",  
    tag: "v2.1.5",  
    sparse: "optimized",  
    app: false,  
    compile: false,  
    depth: 1},  
  {:telemetry\_metrics, "\~\> 1.0"},  
  {:telemetry\_poller, "\~\> 1.0"},  
  {:gettext, "\~\> 0.26"},  
  {:jason, "\~\> 1.2"},  
  {:dns\_cluster, "\~\> 0.1.1"},  
  {:bandit, "\~\> 1.5"},

  \# Auth  
  {:swoosh, "\~\> 1.18"},  
  {:hackney, "\~\> 1.9"},

  \# General  
  {:uuid, "\~\> 1.1"},  
  {:cachex, "\~\> 4.0"},  
  {:deep\_merge, "\~\> 1.0"},  
  {:timex, "\~\> 3.7"},  
  {:nimble\_csv, "\~\> 1.2"},  
  {:ymlr, "\~\> 5.1"},  
  {:yaml\_elixir, "\~\> 2.11"},  
  {:algoliax, "\~\> 0.9.1"},  
  {:ex\_aws, "\~\> 2.1"},  
  {:ex\_aws\_s3, "\~\> 2.0"},  
  {:sweet\_xml, "\~\> 0.6"},  
  \# Image resize  
  {:mogrify, "\~\> 0.9.2"},  
  \# Jobs  
  {:oban, "\~\> 2.19"},  
  {:igniter, "\~\> 0.5", only: \[:dev\]},  
  {:oban\_web, "\~\> 2.11"},  
  {:polymorphic\_embed, "\~\> 5.0"},  
  {:calendar\_translations, "\~\> 0.0.4"},  
  \# AI  
  {:goth, "\~\> 1.4"},  
  {:tesla, "\~\> 1.11"},  
  \# PDF (liquid template)  
  {:solid, "\~\> 1.0.0-rc.0"},  
  {:earmark, "\~\> 1.4"},

  \#  
  \# Development  
  \# {:mishka\_chelekom, "\~\> 0.0.3", only: :dev},  
  {:live\_debugger, "\~\> 0.2.0", only: :dev},  
  {:tidewave, "\~\> 0.1", only: :dev},  
  {:dialyxir, "\~\> 1.0", only: :dev, runtime: false},  
  {:sobelow, "\~\> 0.8", only: :dev},  
  {:ex\_doc, "\~\> 0.27", only: :dev, runtime: false},  
  {:credo, "\~\> 1.6", only: \[:dev, :test\], runtime: false},  
  {:excoveralls, "\~\> 0.16.1", only: \[:test\]},  
  {:mix\_test\_watch, "\~\> 1.0", only: \[:dev, :test\], runtime: false},  
  \# Conflict with yaml\_elixir {:mix\_audit, "\~\> 2.1", only: \[:dev, :test\], runtime: false},  
  {:faker, "\~\> 0.17"},  
  {:ex\_machina, "\~\> 2.7.0"},  
  {:mock, "\~\> 0.3.0", only: :test},  
  {:mox, "\~\> 1.0", only: :test},  
  {:bypass, "\~\> 2.1", only: :test},

  \# Prod  
  {:sentry, "\~\> 10.8.1"}  
\]

## **Bad Elixir Practices (to avoid)**

* **Excessive Use of if / cond:**  
  * While sometimes necessary, avoid over-reliance on if and cond when pattern matching can achieve the same result more elegantly.  
  * Consider case or function head matching first.  
* **Piping into case statements:**  
  * Avoid piping the result of a chain of operations directly into a case statement. This can make the code harder to read and debug. Assign the result to a variable first.

**Example (Piping into case):**\# Don't: Less clear flow of data to the case statement  
build\_post(attrs)  
|\> store\_post()  
|\> case do  
  {:ok, post} \-\> \# ...  
  {:error, \_} \-\> \# ...  
end

\# Do: Clearer separation of concerns  
changeset \= build\_post(attrs)  
case store\_post(changeset) do  
  {:ok, post} \-\> \# ...  
  {:error, \_} \-\> \# ...  
end

* **Ignoring Tuple Returns ({:ok, ...} / {:error, ...}):**  
  * Do not discard the :error part of return tuples without proper handling.  
  * Avoid using \! functions (e.g., File.read\!) unless you are certain the operation cannot fail or it's part of a controlled error propagation strategy.  
* **Large, Complex Functions:**  
  * Avoid functions with many lines of code or deep nesting.  
  * Refactor into smaller, more focused helper functions.  
* **Magic Numbers/Strings:**  
  * Avoid using arbitrary un-named values directly in code.  
  * Use module attributes (@attribute) or constants to define meaningful names for these values.  
* **Unnecessary Process Spawning:**  
  * Do not spawn new processes casually for every small task.  
  * Consider Task for one-off async operations or GenServer for stateful processes.  
* **Deeply Nested Data Structures (without proper access):**  
  * While Elixir handles nested data, frequently accessing deeply nested elements without appropriate patterns (e.g., Kernel.get\_in/2, Map.dig/2) can lead to less readable code.  
* **Ignoring Supervision:**  
  * Running critical processes without a supervisor makes your application brittle and prone to crashing without recovery.  
* **Misusing IO.inspect:**  
  * IO.inspect is great for debugging but should be removed from production code.  
  * Do not rely on it for application logic or side effects.  
* **Over-optimization:**  
  * Don't prematurely optimize code that isn't a bottleneck. Prioritize readability and maintainability first.  
* **Lack of Documentation:**  
  * Functions and modules should have clear @doc and @moduledoc comments explaining their purpose, arguments, and return values.  
* **Over-reliance on else in with blocks:**  
  * with is best used when you can fall through without worrying about specific errors. If you find yourself writing a complex else block to handle many distinct error types from a with statement, it might be clearer to use nested case statements or a dedicated error handling function for each step.

**Example (Over-reliance on else in with):**\# Don't: Complicated else block for 'with'  
with {:ok, response} \<- call\_service(data),  
     {:ok, decoded} \<- Jason.decode(response),  
     {:ok, result} \<- store\_in\_db(decoded) do  
  :ok  
else  
  {:error, %Jason.Error{} \= error} \-\> \# Do something with json error  
  {:error, %ServiceError{} \= error} \-\> \# Do something with service error  
  {:error, %DBError{}} \-\> \# Do something with db error  
end

* **Embedded Elixir Tags (\<% %\>) for HEEX Control Flow:**  
  * Avoid using \<% %\> tags in HEEX templates for control flow (conditionals, loops, etc.). This makes the template less readable and mixes Elixir code directly into the HTML structure.  
* **Creating Specialized List/Query Functions for Each Filter:**  
  * Avoid creating numerous distinct functions (e.g., list\_by\_type, list\_by\_config\_key) for each possible filtering criterion. This leads to an explosion of functions and less maintainable code. Prefer a single, generalized function that accepts options and applies filters dynamically.  
* **Plain English Strings in gettext for Schema Validations:**  
  * Avoid using plain English strings directly within gettext calls for validation messages. This makes it harder to manage translations consistently across your application and can lead to duplicated efforts. Always use explicit keys.  
* **Obvious Code Comments:**  
  * Avoid adding comments that merely restate what the code clearly does. Comments should be reserved for explaining *why* certain decisions were made, complex logic, or non-obvious behaviors. Clear code is self-documenting.

**Example (Obvious Comments):**\# Don't: Comments explaining obvious code  
\# This function saves the user to the database.  
def save\_user(user) do  
  Repo.insert(user)  
end

\# Do: Reserve comments for complex or non-obvious logic  
\# This recursion handles deeply nested configurations,  
\# ensuring all child nodes are processed before the parent.  
defp process\_config(config\_node) do  
  \# ... complex logic ...  
end

* **Reimplementing Existing Functionality:**  
  * Do not write custom code for functionality that is already provided by one of your project's existing dependencies. This wastes time, increases maintenance burden, and introduces potential for new bugs. Always check your mix.exs before starting a new implementation.

By adhering to these guidelines, the refactored code will be more idiomatic, readable, maintainable, and robust.