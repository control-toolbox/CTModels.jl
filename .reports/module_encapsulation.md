# Test Suite Module Encapsulation Report

**Date:** 2026-01-26
**Topic:** Modularizing the Test Suite for `CTModels.jl`

## 1. Context and Motivation

The `CTModels.jl` test suite is growing in complexity, with tests distributed across numerous subdirectories (now organized under `test/suite/`).

### Current Limitations
1.  **Namespace Pollution / Collisions**:
    Currently, tests are typically `include`d into the main runner's scope. This means that if `test_A.jl` defines a helper struct `MyStruct` and `test_B.jl` defines a different struct with the same name `MyStruct`, Julia will throw a "redefinition of constant" error or warnings, especially if the structs are different.
2.  **World Age Issues**:
    To avoid performance issues and "world age" errors, struct definitions must happen at the top level of the module/file, not inside the test function. This exacerbates the potential for name collisions because we can't hide them inside the function scope.
3.  **Ambiguity of Dependencies**:
    When everything is in one global scope, it is unclear which test relies on which shared helper from `test/problems/`.

## 2. Proposed Solution: Module Encapsulation

The strategy is to wrap every single test file in its own Julia `module`.

### The Pattern
Each test file (e.g., `test/suite/ocp/test_dynamics.jl`) will follow this pattern:

```julia
module TestDynamics # 1. Unique Module Name

using Test
using CTModels
using Main.TestProblems # 2. Access shared test resources

# 3. Safe, isolated struct definitions
struct MyDummyModel end    # No conflict with MyDummyModel in other files

function test_dynamics()   # 4. Standard entry point
    @testset "Dynamics Tests" begin
        # ... implementation ...
    end
end

end # module

# 5. Export the entry point back to the runner's scope
using .TestDynamics: test_dynamics
```

## 3. Handling Shared Resources (`TestProblems`)

The challenge with modularization is that modules introduce hard scope boundaries. They do not automatically inherit variables from the parent scope (unlike `include` without modules).

Tests in `CTModels` rely on shared problem definitions and helpers located in `test/problems/` (e.g., `OptimizationProblem`, `Rosenbrock`, `Solution`).

### The `TestProblems` Module
To solve this, we will refactor `test/problems/*.jl` into a shared module:

**File:** `test/problems/TestProblems.jl`
```julia
module TestProblems
    using CTModels
    using SolverCore
    using ADNLPModels
    using ExaModels

    # Include definitions
    include("problems_definition.jl")
    include("solution_example.jl")
    # ...

    # Export common tools
    export OptimizationProblem, Rosenbrock, Solution
end
```

### Integration in `runtests.jl`
The runner will load this shared module once:
```julia
include(joinpath("problems", "TestProblems.jl"))
using .TestProblems # Available in Main
```
Individual test modules then access it via `using Main.TestProblems`.

## 4. Migration Plan

1.  **Create `TestProblems`**: Consolidate `problems/` into the new module.
2.  **Refactor `runtests.jl`**: Update imports to load `TestProblems` instead of raw includes.
3.  **Iterative Migration**: Systematically go through `test/suite/*` and apply the module pattern.

## 5. Benefits

-   **Robustness**: Complete isolation of test files. You can copy-paste a struct definition from one test to another without renaming it.
-   **Clarity**: Explicit imports (`using CTModels`, `using Test`) in each file make it clear what the test depends on.
-   **Future-Proofing**: Makes it easier to run tests in parallel or in random order in the future, as they no longer share a mutable global state.
