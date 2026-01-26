# Testing Guide for CTModels

This directory contains the test suite for `CTModels.jl`. It follows the testing conventions and infrastructure provided by [CTBase.jl](https://github.com/control-toolbox/CTBase.jl).

For detailed guidelines on testing and coverage, please refer to:

- [CTBase Test Coverage Guide](https://control-toolbox.org/CTBase.jl/stable/test-coverage-guide.html)
- [CTBase TestRunner Extension](https://github.com/control-toolbox/CTBase.jl/blob/main/ext/TestRunner.jl)
- [CTBase CoveragePostprocessing](https://github.com/control-toolbox/CTBase.jl/blob/main/ext/CoveragePostprocessing.jl)

---

## 1. Running Tests

Tests are executed using the standard Julia Test interface, enhanced by `CTBase.TestRunner`.

### Default Run (All Enabled Tests)

Runs all tests enabled by default in `test/runtests.jl`.

```bash
julia --project -e 'using Pkg; Pkg.test("CTModels")'
```

### Running Specific Test Groups

You can run specific test files or groups using the `test_args` argument. The argument supports glob-style patterns.

**Run all tests in the `ocp` directory:**

```bash
julia --project -e 'using Pkg; Pkg.test("CTModels"; test_args=["ocp/*"])'
```

**Run specific test files:**

```bash
julia --project -e 'using Pkg; Pkg.test("CTModels"; test_args=["ocp/test_constraints", "ocp/test_dynamics"])'
```

### Running All Tests (Including Optional/Long Tests)

To run absolutely every test available (including those potentially marked as optional or skipped by default):

```bash
julia --project -e 'using Pkg; Pkg.test("CTModels"; test_args=["-a"])'
```

## 2. Coverage

To generate a coverage report, you must run the tests with `coverage=true` and then execute the coverage post-processing script.

**Command:**

```bash
julia --project=@. -e 'using Pkg; Pkg.test("CTModels"; coverage=true); include("test/coverage.jl")'
```

**Outputs:**

- `coverage/lcov.info`: LCOV format file (useful for CI integration like Codecov).
- `coverage/cov_report.md`: Human-readable summary of coverage gaps.
- `coverage/cov/`: detailed `.cov` files.

## 3. Adding New Tests

### File and Function Naming

- **File Name:** Must follow the pattern `test_<name>.jl` (e.g., `test_dynamics.jl`).
- **Entry Function:** The file **MUST** contain a function named `test_<name>()` (matching the filename) that serves as the entry point.

**Example (`test/ocp/test_dynamics.jl`):**

```julia
module TestDynamics # Optional but good for namespace isolation

using Test
using CTModels

# Define structs at top-level (crucial!)
struct MyDummyModel end

function test_dynamics()
    @testset "Dynamics Tests" begin
        # Your tests here
    end
end

end # module
```

### Registering the Test

Add your new test file pattern to the `available_tests` tuple in `test/runtests.jl` if necessary (e.g., if you added a new subdirectory).

## 4. Best Practices & Rules

### ⚠️ Crucial: Struct Definitions

**NEVER define `struct`s inside the test function.**
All helper methods, mocks, and structs must be defined at the **top-level** of the file (or module). Defining structs inside the function causes world-age issues and invalidates precompilation.

### Test Structure

- **Unit vs. Integration:** Clearly separate unit tests (testing single functions/components in isolation) from integration tests (testing the interaction between components).
- **Mocks and Fakes:** Use mock objects or fake implementations to isolate the code under test.
- **Exports:** Even if a function is exported, it is often better to **qualify the method call** (e.g., `CTModels.solve(...)`) to be explicit about what is being tested. Alternatively, have a specific test dedicated to verifying that exports work as expected.

### Directory Structure

Place your test file in the appropriate subdirectory based on functionality:

- `core/`: Core utilities and types.
- `ocp/`: Optimal Control Problem definitions and layers.
- `nlp/`: NLP interfaces.
- `strategies/`, `options/`, `orchestration/`: New architecture components.
- ...and others as listed in `test/runtests.jl`.
