using Test
using Aqua
using CTBase
using CTModels
using ADNLPModels
using SolverCore
using NLPModels
using ExaModels
using OrderedCollections: OrderedDict

# Tests parameters
const VERBOSE = true
const SHOWTIMING = true

#
include(joinpath("problems", "solution_example.jl"))
include(joinpath("problems", "problems_definition.jl"))
include(joinpath("problems", "rosenbrock.jl"))
include(joinpath("problems", "max1minusx2.jl"))
include(joinpath("problems", "elec.jl"))
include(joinpath("problems", "beam.jl"))
include(joinpath("problems", "solution_example_dual.jl"))

# ---------------------------------------------------------------------------#
# Test selection infrastructure (aligned with CTSolvers)
# ---------------------------------------------------------------------------#

function default_tests()
    return OrderedDict(
        # Extension exceptions, before any extensions are triggered
        :notrigger => OrderedDict(:ext_exceptions => true),

        # Meta / quality tests
        :meta => OrderedDict(:aqua => true, :CTModels => true),

        # Tests in test/ocp
        :ocp => OrderedDict(
            :times => true,
            :time_dependence => true,
            :state => true,
            :control => true,
            :variable => true,
            :dynamics => true,
            :objective => true,
            :constraints => true,
            :definition => true,
            :model => true,
            :ocp => true,
            :dual_model => true,
            :print => true,
            :solution => true,
        ),

        # Core utilities and type-level tests in test/core
        :core => OrderedDict(
            :utils => true,
            :default => true,
            :types => true,
            :ocp_components => true,
            :ocp_model_types => true,
            :ocp_solution_types => true,
            :nlp_types => true,
            :initial_guess_types => true,
        ),

        # Tests in test/nlp
        :nlp => OrderedDict(
            :problem_core => true,
            :options_schema => true,
            :nlp_backends => true,
            :discretized_ocp => true,
            :model_api => true,
        ),

        # Tests in test/init
        :init => OrderedDict(:initial_guess => true),

        # IO-related tests in test/io
        :io => OrderedDict(:export_import => true),

        # Plot-related tests in test/plot
        :plot => OrderedDict(:plot => true),
    )
end

const TEST_SELECTIONS = isempty(ARGS) ? Symbol[] : Symbol.(ARGS)

const TEST_GROUP_INFO = Dict(
    :notrigger => (title="Extension exceptions", subdir="io"),
    :meta => (title="Meta / quality", subdir="meta"),
    :ocp => (title="OCP continuous-time layer", subdir="ocp"),
    :core => (title="Core utilities and types", subdir="core"),
    :nlp => (title="NLP / backends / discretized OCP", subdir="nlp"),
    :init => (title="Initial guess", subdir="init"),
    :io => (title="IO / export / import", subdir="io"),
    :plot => (title="Plotting", subdir="plot"),
)

function selected_tests()
    tests = default_tests()
    sels = TEST_SELECTIONS

    # No selection: default configuration
    if isempty(sels)
        return tests
    end

    # Single :all selection: enable everything
    if length(sels) == 1 && sels[1] == :all
        for (_, group_tests) in tests
            for k in keys(group_tests)
                group_tests[k] = true
            end
        end
        return tests
    end

    # Otherwise start with everything disabled
    for (_, group_tests) in tests
        for k in keys(group_tests)
            group_tests[k] = false
        end
    end

    # Apply each selector
    for sel in sels
        # :all mixed with others -> just enable everything and stop
        if sel == :all
            for (_, group_tests) in tests
                for k in keys(group_tests)
                    group_tests[k] = true
                end
            end
            break
        end

        # sel = group key (e.g. :meta, :ocp, :nlp, :io, :plot, ...)
        if haskey(tests, sel)
            for k in keys(tests[sel])
                tests[sel][k] = true
            end
            continue
        end

        # sel = leaf key (e.g. :times, :nlp_backends, :plot, ...)
        for (_, group_tests) in tests
            if haskey(group_tests, sel)
                group_tests[sel] = true
                break
            end
        end
    end

    return tests
end

const SELECTED_TESTS = selected_tests()

function run_test_group(group::Symbol, tests::OrderedDict{Symbol,Bool})
    any(values(tests)) || return nothing
    info = TEST_GROUP_INFO[group]
    title = info.title
    subdir = info.subdir
    println("========== $(title) tests ==========")
    @testset "$(title)" verbose=VERBOSE showtiming=SHOWTIMING begin
        for (name, enabled) in tests
            enabled || continue
            @testset "$(name)" verbose=VERBOSE showtiming=SHOWTIMING begin
                test_name = Symbol(:test_, name)
                println("testing: ", string(name))
                include(joinpath(subdir, string(test_name, ".jl")))
                @eval $test_name()
            end
        end
    end
    println("✓ $(title) tests passed\n")
end

for (group, tests) in SELECTED_TESTS
    run_test_group(group, tests)
end

# test with CTDirect and CTParser: must be commented if new version of CTModels, that is breaking

# using CTDirect
# using NLPModelsIpopt
# using ADNLPModels
# import CTParser: CTParser, @def

# #
# include(joinpath("problems", "solution_example_dual.jl"))

# @testset verbose=VERBOSE showtiming=SHOWTIMING "CTModels tests" begin
#     for name in (
#         :plot,
#         # :export_import,
#     )
#         @testset "$(name)" begin
#             test_name = Symbol(:test_, name)
#             println("testing: ", string(name))
#             include(_testfile_path(name))
#             @eval $test_name()
#         end
#     end
# end
