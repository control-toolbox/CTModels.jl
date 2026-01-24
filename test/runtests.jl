# ==============================================================================
# CTModels Test Runner
# ==============================================================================
#
# This test runner uses the CTBase TestRunner extension (triggered by `using Test`)
# to execute tests with configurable file/function name builders and optional
# test selection via command-line arguments.
#
# ## Running Tests
#
# ### Default (all enabled tests)
#
#   julia --project -e 'using Pkg; Pkg.test("CTModels")'
#
# ### Run a specific test group
#
#   julia --project -e 'using Pkg; Pkg.test("CTModels"; test_args=["ocp"])'
#   julia --project -e 'using Pkg; Pkg.test("CTModels"; test_args=["constraints", "dynamics"])'
#
# ### Run all tests (including those not enabled by default)
#
#   julia --project -e 'using Pkg; Pkg.test("CTModels"; test_args=["-a"])'
#
# ## Coverage Mode
#
# Run tests with code coverage instrumentation:
#
#   julia --project=@. -e 'using Pkg; Pkg.test("CTModels"; coverage=true); include("test/coverage.jl")'
#
# This produces:
#   - coverage/lcov.info      — LCOV format for CI integration
#   - coverage/cov_report.md  — Human-readable summary with uncovered lines
#   - coverage/cov/           — Archived .cov files
#
# ## Test Groups
#
# Each test group corresponds to a file `test/<subdir>/test_<name>.jl` that defines
# a function `test_<name>()`. The `available_tests` list below controls
# which groups are valid; requests for unlisted groups will error.
#
# Available test directories:
#   - core/   : Core utilities and type-level tests
#   - init/   : Initial guess tests
#   - io/     : IO-related tests (export/import, extension exceptions)
#   - meta/   : Meta / quality tests (Aqua, package loading)
#   - nlp/    : NLP / backends / discretized OCP tests
#   - ocp/    : OCP continuous-time layer tests
#   - plot/   : Plotting tests
#
# ==============================================================================

# Test dependencies
using Test
using Aqua
using CTBase
using CTModels
using ADNLPModels
using SolverCore
using NLPModels
using ExaModels
using MadNLP  # Trigger CTModelsMadNLP extension

# Trigger loading of optional extensions
const TestRunner = Base.get_extension(CTBase, :TestRunner)

# Controls nested testset output formatting (used by individual test files)
const VERBOSE = true
const SHOWTIMING = true

# Include shared test problems
include(joinpath("problems", "solution_example.jl"))
include(joinpath("problems", "problems_definition.jl"))
include(joinpath("problems", "rosenbrock.jl"))
include(joinpath("problems", "max1minusx2.jl"))
include(joinpath("problems", "elec.jl"))
include(joinpath("problems", "beam.jl"))
include(joinpath("problems", "solution_example_dual.jl"))

# Run tests using the TestRunner extension
CTBase.run_tests(;
    args=String.(ARGS),
    testset_name="CTModels tests",
    available_tests=(
        "core/test_*",
        "init/test_*",
        "io/test_*",
        "meta/test_*",
        #"nlp/test_*",
        "ocp/test_*",
        "options/test_*",
        "plot/test_*",
        "strategies/test_*",
    ),
    filename_builder=name -> Symbol(:test_, name),
    funcname_builder=name -> Symbol(:test_, name),
    verbose=VERBOSE,
    showtiming=SHOWTIMING,
    test_dir=@__DIR__,
)

# If running with coverage enabled, remind the user to run the post-processing script
# because .cov files are flushed at process exit and cannot be cleaned up by this script.
if Base.JLOptions().code_coverage != 0
    println(
        """

================================================================================
[CTModels] Coverage files generated.

To process them, move them to the coverage/ directory, and generate a report,
please run:

    julia --project=@. -e 'using Pkg; Pkg.test("CTModels"; coverage=true); include("test/coverage.jl")'
================================================================================
""",
    )
end
