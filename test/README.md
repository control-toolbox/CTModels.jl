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

**Run all tests in the `building` directory:**

```bash
julia --project -e 'using Pkg; Pkg.test("CTModels"; test_args=["suite/building/*"])'
```

**Run specific test files:**

```bash
julia --project -e 'using Pkg; Pkg.test("CTModels"; test_args=["suite/building/test_constraints", "suite/building/test_dynamics"])'
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

**Example (`test/suite/building/test_dynamics.jl`):**

```julia
module TestDynamics # namespace isolation

using Test: Test
using CTModels: CTModels

const VERBOSE    = isdefined(Main, :TestData) ? Main.TestData.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Define structs at top-level (crucial! world-age issues otherwise)
struct FakeDynModel <: CTModels.AbstractModel end

function test_dynamics()
    Test.@testset "Dynamics Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Your tests here
    end
end

end # module

# CRITICAL: Redefine the function in the outer scope so TestRunner can find it
test_dynamics() = TestDynamics.test_dynamics()
```

### Registering the Test

All test files in `test/suite/*/` are automatically discovered by the pattern `"suite/*/test_*"` in `test/runtests.jl`. Simply place your test file in the appropriate subdirectory under `test/suite/`.

## 4. Best Practices & Rules

### ⚠️ Crucial: Struct Definitions

**NEVER define `struct`s inside the test function.**
All helper methods, mocks, and structs must be defined at the **top-level** of the file (or module). Defining structs inside the function causes world-age issues and invalidates precompilation.

### Test Structure

- **Unit vs. Integration:** Clearly separate unit tests (testing single functions/components in isolation) from integration tests (testing the interaction between components).
- **Mocks and Fakes:** Use mock objects or fake implementations to isolate the code under test.
- **Qualification of methods**: always **qualify the method call** even if a method is exported (e.g., `CTModels.solve(...)`). This makes it explicit what is being tested and avoids any ambiguity.
- **Verification of exports**: dedicated tests should be added to verify that methods are correctly exported when necessary (e.g., using `isdefined(CTModels, :...)`).

### Directory Structure

All test files are organized under `test/suite/`. Place your test file in the appropriate subdirectory based on functionality (groups align with the package's submodules):

- `suite/components/`: Shared types, aliases, accessors, time-dependence traits (`CTModels.Components`)
- `suite/models/`: Immutable `Model` type, readers, user-facing predicates (`CTModels.Models`)
- `suite/building/`: `PreModel`, mutators, validation, defaults, `build` (`CTModels.Building`)
- `suite/solutions/`: `Solution`, time grids, dual model, interpolation (`CTModels.Solutions`)
- `suite/init/`: Initial guess construction, validation, API (`CTModels.Init`)
- `suite/serialization/`: Import/export to disk (JLD2, JSON) (`CTModels.Serialization`)
- `suite/display/`: Pretty-printing of models and solutions (`CTModels.Display`)
- `suite/extensions/`: Weak-dependency extension tests (e.g. Plots)
- `suite/integration/`: End-to-end tests spanning multiple modules
- `suite/meta/`: Aqua.jl code-quality checks, export verification, type hierarchy
