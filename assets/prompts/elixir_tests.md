# **elixir\_tests.md**

This document outlines the preferred style and good/bad practices for generating tests in our Elixir application. Aider, please use these guidelines to inform your test generation process.

## **MY STYLE \- Elixir Testing Principles**

Our tests should be:

1. **Clear and Readable:** Tests should be easy to understand at a glance. Prioritize clarity over brevity. Anyone on the team should be able to read a test and understand what it's testing and why.  
2. **Fast and Isolated:** Each test should run quickly and independently. Avoid reliance on external services or shared state. If a test fails, it should be clear why, and the failure should not impact other tests.  
3. **Comprehensive but Not Excessive:** Aim for good test coverage, focusing on critical paths, edge cases, and known bug areas. Avoid testing trivial getters/setters or internal implementation details that are unlikely to change.  
4. **Descriptive Test Names:** Test names should clearly articulate the scenario being tested and the expected outcome.  
5. **Behavior-Driven:** Tests should describe the expected behavior of the system, rather than just implementation details. Focus on *what* the code does, not *how* it does it.  
6. **Focused on Public APIs:** Generally, test the public interface of modules and functions. Avoid testing private functions directly unless absolutely necessary for a complex edge case that cannot be covered via the public API.  
7. **Use** ExUnit.Callbacks **for Setup/Teardown:** When common setup or teardown is needed across multiple tests in a file, use setup and setup\_all callbacks.

## **Project Structure and Test Files**

Our project structure for testing-related files is as follows. Aider, please leverage this understanding when generating tests and referencing helper modules:

.  
├── my_app/             \# Main application  
├── my_app\_app\_web/   \# Web-related code for \`my_app\_app\`  
├── my_app\_web/       \# Web-related code for \`my_app\`  
├── support/                \# General support modules  
├── factories/              \# Directory for ExMachina factories  
│   ├── factory.ex          \# Main factory definition  
│   └── ...                 \# Other specific factories  
├── fixtures/               \# Directory for test fixtures (e.g., JSON data, static files)  
├── conn\_case.ex            \# Phoenix connection test helpers (for web tests)  
├── data\_case.ex            \# Ecto data test helpers (for database tests)  
├── fake\_data\_generation.ex \# Module for generating fake data (likely used by factories)  
└── test\_helper.exs         \# Global test setup and configuration

* conn\_case.ex: This module provides common setup and helper functions for testing Phoenix controllers, LiveViews, and channels, especially when dealing with the Plug.Conn struct. Tests related to web requests should typically use this use YourAppWeb.ConnCase.  
* data\_case.ex: This module provides common setup and helper functions for testing Ecto models and database interactions. It's crucial for database sandbox integration. Tests interacting with the database should typically use this use YourApp.DataCase.  
* factories/factory.ex: This is where our ExMachina factories are defined. Always use these factories to generate test data for consistency and ease of setup.  
* fixtures/: Use this directory for static test data that can be loaded, such as JSON files for API responses or specific input files.  
* test\_helper.exs: This file contains the global configuration for ExUnit and other test-related setups.

## **Key Testing-Related Dependencies**

We use a variety of libraries that are important for how tests are written and executed:

* phoenix**,** phoenix\_ecto**,** ecto\_sql**,** postgrex: These are core for our application and database interactions. Tests will heavily rely on **Ecto** for persistence and querying, ensuring that database changes are correctly sandboxed.  
* floki: Essential for testing **Phoenix LiveView** and controller responses, allowing for easy parsing and assertion against HTML content.  
* ex\_machina: **MANDATORY** for creating test data. Always use defined factories (found in the factories/ directory) instead of manually building structs.  
  \# Good: Using a factory  
  user \= insert(:user, name: "Test User")

  \# Bad: Manual struct creation (avoids validation, often brittle)  
  user \= %User{name: "Test User", email: "test@example.com"}  
  Repo.insert\!(user)

* mock **and** mox: Our preferred libraries for **mocking and stubbing**. Mox should be used for explicit mock definitions of behaviours or external services. Mock can be used for simpler stubbing of individual functions when Mox might be overkill or impractical. Remember to use them sparingly, only when strictly necessary for isolation or testing external integrations.  
* bypass: This library is specifically for setting up **fake HTTP servers** in tests. Use it when testing modules that make HTTP requests to external APIs, allowing you to control and assert on those requests without hitting actual external services.  
* oban: For testing background jobs. If a test involves dispatching Oban jobs, consider asserting that the job was correctly enqueued (e.g., assert\_enqueued YourApp.Worker) or, for more complex scenarios, configuring Oban to run in test mode (Oban.start\_supervised\_for\_testing/1) to execute jobs inline.

## **Good Practices for Elixir Tests**

### **1\. Test Structure**

* describe **Blocks:** Use describe blocks to group related tests for a specific function, module, or feature. This improves readability and organization.  
  describe "User authentication" do  
    test "authenticates with valid credentials" do  
      \# ...  
    end

    test "fails to authenticate with invalid password" do  
      \# ...  
    end  
  end

* test **Blocks:** Each test block should focus on a single, specific assertion or behavior.

### **2\. Naming Conventions**

* **Descriptive Test Names:**  
  * **Good:** test "returns {:ok, user} when given valid credentials"  
  * **Good:** test "returns {:error, :invalid\_credentials} when given invalid password"  
  * **Bad:** test "auth test"  
  * **Bad:** test "login"

### **3\. Assertions**

* **Use Specific Assertions:** Prefer specific assertions like assert\_raise, assert\_error, assert\_ok (if custom helpers exist), assert\_match, assert\_not\_nil, assert\_nil, etc., over generic assert true or assert false.  
* assert **for Equality:** Use assert actual \== expected for asserting equality.  
* refute **for Inequality:** Use refute actual \== expected for asserting inequality.  
* **Pattern Matching for Complex Data Structures:** Leverage pattern matching within assert for asserting against complex data structures, especially when dealing with tuples ({:ok, data}, {:error, reason}).  
  test "creates a user with valid attributes" do  
    attrs \= %{name: "Alice", email: "alice@example.com"}  
    assert {:ok, %User{name: "Alice", email: "alice@example.com"}} \= Accounts.create\_user(attrs)  
  end

  test "returns error when creating user with invalid email" do  
    attrs \= %{name: "Bob", email: "invalid-email"}  
    assert {:error, %Ecto.Changeset{}} \= Accounts.create\_user(attrs)  
  end

### **4\. Setup and Teardown**

* setup **and** setup\_all**:** Use these callbacks for common setup necessary for tests within a describe block or file.  
  * setup: Runs before *each* test. Useful for creating fresh data for each test.  
  * setup\_all: Runs once before *all* tests in the file. Useful for operations that can be shared and are idempotent (e.g., seeding lookup data).

\# In a data\_case.ex or similar:  
setup do  
  \# Create a fresh user for each test using ExMachina factory  
  user \= insert(:user)  
  {:ok, %{user: user}}  
end

test "fetches user by ID", %{user: user} do  
  assert Accounts.get\_user(user.id) \== user  
end  
Remember to use use YourApp.DataCase or use YourAppWeb.ConnCase at the top of your test file to inherit these setups.

### **5\. Data Handling (Ecto/Database)**

* Ecto.Adapters.SQL.Sandbox**:** When testing modules that interact with the database, ensure Ecto.Adapters.SQL.Sandbox is configured (typically in test\_helper.exs and managed by data\_case.ex). This provides isolated transactions for each test, rolling back changes after the test completes.  
  \# In test/test\_helper.exs (ensure this is configured)  
  \# Ecto.Adapters.SQL.Sandbox.mode(YourApp.Repo, :manual)

  \# In your data\_case.ex or specific test file:  
  setup :setup\_and\_teardown\_sandbox

  defp setup\_and\_teardown\_sandbox do  
    :ok \= Ecto.Adapters.SQL.Sandbox.checkout(YourApp.Repo)  
    on\_exit fn \-\> Ecto.Adapters.SQL.Sandbox.checkin(YourApp.Repo) end  
  end

* **Factory Helpers (**ExMachina**):** Utilize ExMachina and the factories in your factories/ directory to generate test data easily and consistently. This avoids repetitive data creation in tests and ensures data conforms to your schema and associations.  
  \# Assuming ExMachina setup and a user factory in factories/factory.ex  
  test "updates user name" do  
    user \= insert(:user) \# Creates and inserts a user using the factory  
    assert {:ok, %User{name: "New Name"}} \= Accounts.update\_user(user, %{name: "New Name"})  
  end

### **6\. Testing** with **Statements**

* Test each branch of a with statement explicitly, including success paths and various failure paths.  
  describe "processing order" do  
    test "successfully processes a valid order" do  
      assert {:ok, %Order{status: :processed}} \= Orders.process(valid\_order\_params)  
    end

    test "returns error if payment fails" do  
      assert {:error, :payment\_failed} \= Orders.process(order\_params\_with\_failed\_payment)  
    end

    test "returns error if stock is insufficient" do  
      assert {:error, :insufficient\_stock} \= Orders.process(order\_params\_with\_low\_stock)  
    end  
  end

### **7\. Mocking and Stubbing (Use Sparingly)**

* Elixir's functional nature and explicit dependencies often reduce the need for heavy mocking.  
* **Dependency Injection:** Prefer passing dependencies (e.g., HTTP clients, database modules) as arguments or through application configuration, which makes them easy to replace in tests.  
* **Behaviors/Callbacks:** Use callbacks or behaviours to define interfaces, allowing you to substitute implementations for testing.  
* Mox **(for controlled mocking):** If mocking external services is truly necessary, use Mox to define explicit mocks for behaviours.  
  * **Good:** Mocking a third-party API that you don't control using Mox and Bypass.  
  * **Bad:** Mocking a module within your own application that could be tested by testing its public interface directly.  
* Bypass: Use Bypass for testing interactions with external HTTP APIs. It allows you to simulate HTTP responses and verify requests made by your application.

## **Bad Practices for Elixir Tests**

### **1\. Testing Private Functions Directly**

* **Why it's bad:** Private functions are implementation details. If you change the internal implementation of a module but its public behavior remains the same, your tests shouldn't break. Testing private functions couples your tests tightly to the implementation.  
* **Instead:** Test the public functions that rely on the private functions. If a private function is complex enough to warrant its own testing, consider extracting it into a separate, public module.

### **2\. Over-Mocking**

* **Why it's bad:** Over-mocking leads to brittle tests that break when the mocked dependency changes, even if the overall system behavior is correct. It can also mask actual issues by making tests pass when the real system would fail.  
* **Instead:** Focus on testing the interactions between modules at their boundaries, using integration tests or through judicious use of dependency injection. Only mock external services or highly unstable dependencies.

### **3\. Long, Slow, or Dependent Tests**

* **Why it's bad:** Slow tests discourage developers from running them frequently. Tests that depend on each other are brittle; a failure in one test can cause a cascade of unrelated failures.  
* **Instead:** Ensure tests are isolated and run quickly. Use ExUnit.Callbacks and database sandboxing to ensure a clean state for each test. Break down complex scenarios into smaller, focused tests.

### **4\. Unclear Test Names**

* **Why it's bad:** If a test name doesn't immediately tell you what's being tested and what the expected outcome is, debugging failures becomes much harder.  
* **Instead:** Refer to "Good Practices \- Naming Conventions" above.

### **5\. Testing Implementation Details**

* **Why it's bad:** This is similar to testing private functions. If your tests assert on the exact way something is implemented (e.g., checking specific struct fields that aren't part of the public contract, or the order of internal function calls), they will break unnecessarily when the internal implementation changes.  
* **Instead:** Test the *observable behavior* and the *public contract* of your modules. Does the function return the correct value? Does it cause the expected side effect? Focus on the inputs and outputs.

By adhering to these guidelines, we can ensure our Elixir test suite is robust, maintainable, and provides reliable feedback during development.
