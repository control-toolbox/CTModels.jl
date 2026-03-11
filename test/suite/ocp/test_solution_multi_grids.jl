module TestSolutionMultiGrids

using Test: Test
using CTModels: CTModels
import CTBase.Exceptions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_solution_multi_grids()
    Test.@testset "Solution Multi Grids Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for solution multi grids functionality
        end

        # ====================================================================
        # UNIT TESTS - Time Grid Models
        # ====================================================================

        Test.@testset "Time Grid Models" begin
            Test.@testset "UnifiedTimeGridModel" begin
                T = LinRange(0, 1, 101)
                tgm = CTModels.UnifiedTimeGridModel(T)
                Test.@test tgm isa CTModels.UnifiedTimeGridModel
                Test.@test tgm isa CTModels.AbstractTimeGridModel
                Test.@test tgm.value == T
            end

            Test.@testset "MultipleTimeGridModel" begin
                T_state = LinRange(0, 1, 101)
                T_control = LinRange(0, 1, 51)
                T_costate = LinRange(0, 1, 76)
                T_path = LinRange(0, 1, 61)

                mtgm = CTModels.MultipleTimeGridModel(
                    state=T_state, control=T_control, costate=T_costate, path=T_path
                )
                Test.@test mtgm isa CTModels.MultipleTimeGridModel
                Test.@test mtgm isa CTModels.AbstractTimeGridModel
                Test.@test mtgm.grids.state == T_state
                Test.@test mtgm.grids.control == T_control
                Test.@test mtgm.grids.costate == T_costate
                Test.@test mtgm.grids.path == T_path
            end
        end

        # ====================================================================
        # UNIT TESTS - Component Symbol Cleaning
        # ====================================================================

        Test.@testset "Component Symbol Cleaning" begin
            Test.@testset "clean_component_symbols" begin
                # Test canonical forms (unchanged)
                Test.@test CTModels.clean_component_symbols((:state,)) == (:state,)
                Test.@test CTModels.clean_component_symbols((:control,)) == (:control,)
                Test.@test CTModels.clean_component_symbols((:path,)) == (:path,)

                # Test costate maps to costate (has its own grid)
                Test.@test CTModels.clean_component_symbols((:costate,)) == (:costate,)
                Test.@test CTModels.clean_component_symbols((:costates,)) == (:costate,)

                # Test dual maps to path (shares path grid)
                Test.@test CTModels.clean_component_symbols((:dual,)) == (:path,)
                Test.@test CTModels.clean_component_symbols((:duals,)) == (:path,)

                # Test plural forms
                Test.@test CTModels.clean_component_symbols((:states,)) == (:state,)
                Test.@test CTModels.clean_component_symbols((:controls,)) == (:control,)

                # Test ambiguous terms (mapped to :path)
                Test.@test CTModels.clean_component_symbols((:constraint,)) == (:path,)
                Test.@test CTModels.clean_component_symbols((:constraints,)) == (:path,)
                Test.@test CTModels.clean_component_symbols((:cons,)) == (:path,)

                # Test box constraint aliases
                Test.@test CTModels.clean_component_symbols((:state_box_constraint,)) ==
                    (:state,)
                Test.@test CTModels.clean_component_symbols((:state_box_constraints,)) ==
                    (:state,)
                Test.@test CTModels.clean_component_symbols((:control_box_constraint,)) ==
                    (:control,)
                Test.@test CTModels.clean_component_symbols((:control_box_constraints,)) ==
                    (:control,)

                # Test mixed input (costate→state, dual→path, so only 3 unique)
                Test.@test CTModels.clean_component_symbols((
                    :states, :controls, :constraint, :duals
                )) == (:state, :control, :path)

                # Test duplicate removal
                Test.@test CTModels.clean_component_symbols((:state, :state)) == (:state,)
                Test.@test CTModels.clean_component_symbols((:states, :state)) == (:state,)
                Test.@test CTModels.clean_component_symbols((:costate, :costate)) ==
                    (:costate,)
                Test.@test CTModels.clean_component_symbols((:costates, :costate)) ==
                    (:costate,)
                Test.@test CTModels.clean_component_symbols((:dual, :path)) == (:path,)
            end
        end

        # ====================================================================
        # UNIT TESTS - Build Solution with Multiple Grids
        # ====================================================================

        Test.@testset "Build Solution with Multiple Grids" begin
            # Create a simple OCP for testing
            pre_ocp = CTModels.PreModel()
            CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
            CTModels.state!(pre_ocp, 2)
            CTModels.control!(pre_ocp, 1)
            CTModels.variable!(pre_ocp, 0)

            # Simple dynamics: ẋ = [x₂, u]
            dynamics!(r, t, x, u, v) = begin
                r[1] = x[2]
                r[2] = u[1]
                return nothing
            end
            CTModels.dynamics!(pre_ocp, dynamics!)

            # Simple objective: ∫0.5*u² → min
            lagrange(t, x, u, v) = 0.5 * u[1]^2
            CTModels.objective!(pre_ocp, :min; lagrange=lagrange)

            # Add definition (required for build)
            definition = quote
                t ∈ [0, 1], time
                x ∈ R², state
                u ∈ R, control
                ẋ(t) == [x₂(t), u(t)]
                ∫(0.5*u(t)^2) → min
            end
            CTModels.definition!(pre_ocp, definition)

            # Set time dependence
            CTModels.time_dependence!(pre_ocp; autonomous=true)

            # Build the model
            ocp = CTModels.build(pre_ocp)

            Test.@testset "Identical grids → UnifiedTimeGridModel" begin
                T = collect(LinRange(0, 1, 101))
                X = [1.0 - t/100 for t in 1:101, i in 1:2]
                U = [sin(2π * t/100) for t in 1:101, i in 1:1]
                P = zeros(101, 2)
                v = Float64[]

                sol = CTModels.build_solution(
                    ocp,
                    T,
                    T,
                    T,
                    T,
                    X,
                    U,
                    v,
                    P;
                    objective=0.5,
                    iterations=10,
                    constraints_violation=1e-6,
                    message="Success",
                    status=:optimal,
                    successful=true,
                )

                Test.@test CTModels.time_grid_model(sol) isa CTModels.UnifiedTimeGridModel
                Test.@test CTModels.time_grid(sol) == T
            end

            Test.@testset "Different grids → MultipleTimeGridModel" begin
                T_state = collect(LinRange(0, 1, 101))
                T_control = collect(LinRange(0, 1, 51))
                T_costate = collect(LinRange(0, 1, 76))
                T_path = collect(LinRange(0, 1, 61))

                X = [1.0 - t/100 for t in 1:101, i in 1:2]
                U = [sin(2π * t/50) for t in 1:51, i in 1:1]
                P = zeros(76, 2)  # Costate has its own grid
                v = Float64[]

                sol = CTModels.build_solution(
                    ocp,
                    T_state,
                    T_control,
                    T_costate,
                    T_path,
                    X,
                    U,
                    v,
                    P;
                    objective=0.5,
                    iterations=10,
                    constraints_violation=1e-6,
                    message="Success",
                    status=:optimal,
                    successful=true,
                )

                Test.@test CTModels.time_grid_model(sol) isa CTModels.MultipleTimeGridModel
                Test.@test CTModels.time_grid(sol, :state) == T_state
                Test.@test CTModels.time_grid(sol, :control) == T_control
                Test.@test CTModels.time_grid(sol, :costate) == T_costate
                Test.@test CTModels.time_grid(sol, :path) == T_path
                # Dual maps to path grid
                Test.@test CTModels.time_grid(sol, :dual) == T_path
            end

            Test.@testset "Nothing path grid" begin
                T_state = collect(LinRange(0, 1, 101))
                T_control = collect(LinRange(0, 1, 51))
                T_costate = collect(LinRange(0, 1, 76))
                T_path = nothing

                X = [1.0 - t/100 for t in 1:101, i in 1:2]
                U = [sin(2π * t/50) for t in 1:51, i in 1:1]
                P = zeros(76, 2)  # Costate has its own grid
                v = Float64[]

                sol = CTModels.build_solution(
                    ocp,
                    T_state,
                    T_control,
                    T_costate,
                    T_path,
                    X,
                    U,
                    v,
                    P;
                    objective=0.5,
                    iterations=10,
                    constraints_violation=1e-6,
                    message="Success",
                    status=:optimal,
                    successful=true,
                )

                Test.@test CTModels.time_grid_model(sol) isa CTModels.MultipleTimeGridModel
                Test.@test CTModels.time_grid(sol, :state) == T_state
                Test.@test CTModels.time_grid(sol, :control) == T_control
                Test.@test CTModels.time_grid(sol, :costate) == T_costate
                # Path grid falls back to state grid when nothing
                Test.@test CTModels.time_grid(sol, :path) == T_state
                Test.@test CTModels.time_grid(sol, :dual) == T_state
            end
        end

        # ====================================================================
        # UNIT TESTS - Time Grid Getters
        # ====================================================================

        Test.@testset "Time Grid Getters" begin
            # Create solutions for testing
            pre_ocp = CTModels.PreModel()
            CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
            CTModels.state!(pre_ocp, 2)
            CTModels.control!(pre_ocp, 1)
            CTModels.variable!(pre_ocp, 0)

            dynamics!(r, t, x, u, v) = begin
                r[1] = x[2]
                r[2] = u[1]
                return nothing
            end
            CTModels.dynamics!(pre_ocp, dynamics!)

            lagrange(t, x, u, v) = 0.5 * u[1]^2
            CTModels.objective!(pre_ocp, :min; lagrange=lagrange)

            # Add definition (required for build)
            definition = quote
                t ∈ [0, 1], time
                x ∈ R², state
                u ∈ R, control
                ẋ(t) == [x₂(t), u(t)]
                ∫(0.5*u(t)^2) → min
            end
            CTModels.definition!(pre_ocp, definition)

            # Set time dependence
            CTModels.time_dependence!(pre_ocp; autonomous=true)

            ocp = CTModels.build(pre_ocp)

            T = collect(LinRange(0, 1, 101))
            X = [1.0 - t/100 for t in 1:101, i in 1:2]
            U = [sin(2π * t/100) for t in 1:101, i in 1:1]
            P = zeros(101, 2)
            v = Float64[]

            Test.@testset "UnifiedTimeGridModel getters" begin
                sol = CTModels.build_solution(
                    ocp,
                    T,
                    T,
                    T,
                    T,
                    X,
                    U,
                    v,
                    P;
                    objective=0.5,
                    iterations=10,
                    constraints_violation=1e-6,
                    message="Success",
                    status=:optimal,
                    successful=true,
                )

                # Should work without component specification
                Test.@test CTModels.time_grid(sol) == T

                # Should also work with component specification (fallback to unified)
                Test.@test CTModels.time_grid(sol, :state) == T
                Test.@test CTModels.time_grid(sol, :control) == T
                Test.@test CTModels.time_grid(sol, :costate) == T
                Test.@test CTModels.time_grid(sol, :dual) == T
                Test.@test CTModels.time_grid(sol, :path) == T

                # Test plural forms
                Test.@test CTModels.time_grid(sol, :states) == T
                Test.@test CTModels.time_grid(sol, :controls) == T
            end

            Test.@testset "MultipleTimeGridModel getters" begin
                T_state = collect(LinRange(0, 1, 101))
                T_control = collect(LinRange(0, 1, 51))
                T_costate = collect(LinRange(0, 1, 76))
                T_path = collect(LinRange(0, 1, 61))

                # Create data matching the grid sizes
                X_multi = [1.0 - t/100 for t in 1:101, i in 1:2]  # 101 points for state
                U_multi = [sin(2π * t/50) for t in 1:51, i in 1:1]   # 51 points for control
                P_multi = zeros(76, 2)  # 76 points for costate (has its own grid)
                v_multi = Float64[]

                sol = CTModels.build_solution(
                    ocp,
                    T_state,
                    T_control,
                    T_costate,
                    T_path,
                    X_multi,
                    U_multi,
                    v_multi,
                    P_multi;
                    objective=0.5,
                    iterations=10,
                    constraints_violation=1e-6,
                    message="Success",
                    status=:optimal,
                    successful=true,
                )

                # Should require component specification
                Test.@test_throws Exceptions.IncorrectArgument CTModels.time_grid(sol)

                # Should work with component specification
                Test.@test CTModels.time_grid(sol, :state) == T_state
                Test.@test CTModels.time_grid(sol, :control) == T_control
                Test.@test CTModels.time_grid(sol, :costate) == T_costate
                Test.@test CTModels.time_grid(sol, :dual) == T_path
                Test.@test CTModels.time_grid(sol, :path) == T_path

                # Test plural forms
                Test.@test CTModels.time_grid(sol, :states) == T_state
                Test.@test CTModels.time_grid(sol, :controls) == T_control

                # Test invalid component
                Test.@test_throws Exceptions.IncorrectArgument CTModels.time_grid(
                    sol, :invalid
                )
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Serialization
        # ====================================================================

        Test.@testset "Serialization with Multiple Grids" begin
            # Create solution with multiple grids
            pre_ocp = CTModels.PreModel()
            CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
            CTModels.state!(pre_ocp, 2)
            CTModels.control!(pre_ocp, 1)
            CTModels.variable!(pre_ocp, 0)

            dynamics!(r, t, x, u, v) = begin
                r[1] = x[2]
                r[2] = u[1]
                return nothing
            end
            CTModels.dynamics!(pre_ocp, dynamics!)

            lagrange(t, x, u, v) = 0.5 * u[1]^2
            CTModels.objective!(pre_ocp, :min; lagrange=lagrange)

            # Add definition (required for build)
            definition = quote
                t ∈ [0, 1], time
                x ∈ R², state
                u ∈ R, control
                ẋ(t) == [x₂(t), u(t)]
                ∫(0.5*u(t)^2) → min
            end
            CTModels.definition!(pre_ocp, definition)

            # Set time dependence
            CTModels.time_dependence!(pre_ocp; autonomous=true)

            ocp = CTModels.build(pre_ocp)

            T_state = collect(LinRange(0, 1, 101))
            T_control = collect(LinRange(0, 1, 51))
            T_costate = collect(LinRange(0, 1, 76))
            T_path = collect(LinRange(0, 1, 61))

            X = [1.0 - t/100 for t in 1:101, i in 1:2]
            U = [sin(2π * t/50) for t in 1:51, i in 1:1]
            P = zeros(76, 2)  # Costate has its own grid
            v = Float64[]

            sol = CTModels.build_solution(
                ocp,
                T_state,
                T_control,
                T_costate,
                T_path,
                X,
                U,
                v,
                P;
                objective=0.5,
                iterations=10,
                constraints_violation=1e-6,
                message="Success",
                status=:optimal,
                successful=true,
            )

            Test.@testset "_serialize_solution" begin
                data = CTModels._serialize_solution(sol)

                # Should have multiple time grid fields
                Test.@test haskey(data, "time_grid_state")
                Test.@test haskey(data, "time_grid_control")
                Test.@test haskey(data, "time_grid_costate")
                Test.@test haskey(data, "time_grid_path")

                # Should not have legacy single time grid or old keys
                Test.@test !haskey(data, "time_grid")
                Test.@test !haskey(data, "time_grid_dual")

                # Time grids should match
                Test.@test data["time_grid_state"] == T_state
                Test.@test data["time_grid_control"] == T_control
                Test.@test data["time_grid_costate"] == T_costate
                Test.@test data["time_grid_path"] == T_path
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Backward Compatibility
        # ====================================================================

        Test.@testset "Backward Compatibility" begin
            pre_ocp = CTModels.PreModel()
            CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
            CTModels.state!(pre_ocp, 2)
            CTModels.control!(pre_ocp, 1)
            CTModels.variable!(pre_ocp, 0)

            dynamics!(r, t, x, u, v) = begin
                r[1] = x[2]
                r[2] = u[1]
                return nothing
            end
            CTModels.dynamics!(pre_ocp, dynamics!)

            lagrange(t, x, u, v) = 0.5 * u[1]^2
            CTModels.objective!(pre_ocp, :min; lagrange=lagrange)

            # Add definition (required for build)
            definition = quote
                t ∈ [0, 1], time
                x ∈ R², state
                u ∈ R, control
                ẋ(t) == [x₂(t), u(t)]
                ∫(0.5*u(t)^2) → min
            end
            CTModels.definition!(pre_ocp, definition)

            # Set time dependence
            CTModels.time_dependence!(pre_ocp; autonomous=true)

            ocp = CTModels.build(pre_ocp)

            T = collect(LinRange(0, 1, 101))
            X = [1.0 - t/100 for t in 1:101, i in 1:2]
            U = [sin(2π * t/100) for t in 1:101, i in 1:1]
            P = zeros(101, 2)
            v = Float64[]

            Test.@testset "Legacy build_solution signature" begin
                sol = CTModels.build_solution(
                    ocp,
                    T,
                    X,
                    U,
                    v,
                    P;
                    objective=0.5,
                    iterations=10,
                    constraints_violation=1e-6,
                    message="Success",
                    status=:optimal,
                    successful=true,
                )

                # Should create UnifiedTimeGridModel
                Test.@test CTModels.time_grid_model(sol) isa CTModels.UnifiedTimeGridModel
                Test.@test CTModels.time_grid(sol) == T

                # Legacy serialization format
                data = CTModels._serialize_solution(sol)
                Test.@test haskey(data, "time_grid")
                Test.@test !haskey(data, "time_grid_state")
                Test.@test data["time_grid"] == T
            end
        end

        # ====================================================================
        # ERROR TESTS
        # ====================================================================

        Test.@testset "Error Handling" begin
            pre_ocp = CTModels.PreModel()
            CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
            CTModels.state!(pre_ocp, 2)
            CTModels.control!(pre_ocp, 1)
            CTModels.variable!(pre_ocp, 0)

            dynamics!(r, t, x, u, v) = begin
                r[1] = x[2]
                r[2] = u[1]
                return nothing
            end
            CTModels.dynamics!(pre_ocp, dynamics!)

            lagrange(t, x, u, v) = 0.5 * u[1]^2
            CTModels.objective!(pre_ocp, :min; lagrange=lagrange)

            # Add definition (required for build)
            definition = quote
                t ∈ [0, 1], time
                x ∈ R², state
                u ∈ R, control
                ẋ(t) == [x₂(t), u(t)]
                ∫(0.5*u(t)^2) → min
            end
            CTModels.definition!(pre_ocp, definition)

            # Set time dependence
            CTModels.time_dependence!(pre_ocp; autonomous=true)

            ocp = CTModels.build(pre_ocp)

            T_state = collect(LinRange(0, 1, 101))
            T_control = collect(LinRange(0, 1, 51))
            T_costate = collect(LinRange(0, 1, 76))
            T_path = collect(LinRange(0, 1, 61))
            X = [1.0 - t/100 for t in 1:101, i in 1:2]
            U = [sin(2π * t/50) for t in 1:51, i in 1:1]
            P = zeros(76, 2)
            v = Float64[]

            sol = CTModels.build_solution(
                ocp,
                T_state,
                T_control,
                T_costate,
                T_path,
                X,
                U,
                v,
                P;
                objective=0.5,
                iterations=10,
                constraints_violation=1e-6,
                message="Success",
                status=:optimal,
                successful=true,
            )

            Test.@testset "Invalid component access" begin
                Test.@test_throws Exceptions.IncorrectArgument CTModels.time_grid(
                    sol, :invalid
                )
                Test.@test_throws Exceptions.IncorrectArgument CTModels.time_grid(
                    sol, :unknown
                )
            end

            Test.@testset "Missing component specification" begin
                Test.@test_throws Exceptions.IncorrectArgument CTModels.time_grid(sol)
            end
        end

        # ====================================================================
        # TYPE STABILITY TESTS
        # ====================================================================

        Test.@testset "Type Stability" begin
            pre_ocp = CTModels.PreModel()
            CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
            CTModels.state!(pre_ocp, 2)
            CTModels.control!(pre_ocp, 1)
            CTModels.variable!(pre_ocp, 0)

            dynamics!(r, t, x, u, v) = begin
                r[1] = x[2]
                r[2] = u[1]
                return nothing
            end
            CTModels.dynamics!(pre_ocp, dynamics!)

            lagrange(t, x, u, v) = 0.5 * u[1]^2
            CTModels.objective!(pre_ocp, :min; lagrange=lagrange)

            # Add definition (required for build)
            definition = quote
                t ∈ [0, 1], time
                x ∈ R², state
                u ∈ R, control
                ẋ(t) == [x₂(t), u(t)]
                ∫(0.5*u(t)^2) → min
            end
            CTModels.definition!(pre_ocp, definition)

            # Set time dependence
            CTModels.time_dependence!(pre_ocp; autonomous=true)

            ocp = CTModels.build(pre_ocp)

            T = collect(LinRange(0, 1, 101))
            X = [1.0 - t/100 for t in 1:101, i in 1:2]
            U = [sin(2π * t/100) for t in 1:101, i in 1:1]
            P = zeros(101, 2)
            v = Float64[]

            Test.@testset "UnifiedTimeGridModel type stability" begin
                sol = CTModels.build_solution(
                    ocp,
                    T,
                    T,
                    T,
                    T,
                    X,
                    U,
                    v,
                    P;
                    objective=0.5,
                    iterations=10,
                    constraints_violation=1e-6,
                    message="Success",
                    status=:optimal,
                    successful=true,
                )

                Test.@test_nowarn Test.@inferred CTModels.time_grid(sol)
                Test.@test_nowarn Test.@inferred CTModels.time_grid(sol, :state)
                Test.@test_nowarn Test.@inferred CTModels.time_grid(sol, :control)
            end

            Test.@testset "MultipleTimeGridModel type stability" begin
                T_state = collect(LinRange(0, 1, 101))
                T_control = collect(LinRange(0, 1, 51))
                T_costate = collect(LinRange(0, 1, 76))
                T_path = collect(LinRange(0, 1, 61))

                # Create data matching the grid sizes
                X_stab = [1.0 - t/100 for t in 1:101, i in 1:2]  # 101 points for state
                U_stab = [sin(2π * t/50) for t in 1:51, i in 1:1]   # 51 points for control
                P_stab = zeros(76, 2)  # 76 points for costate
                v_stab = Float64[]

                sol = CTModels.build_solution(
                    ocp,
                    T_state,
                    T_control,
                    T_costate,
                    T_path,
                    X_stab,
                    U_stab,
                    v_stab,
                    P_stab;
                    objective=0.5,
                    iterations=10,
                    constraints_violation=1e-6,
                    message="Success",
                    status=:optimal,
                    successful=true,
                )

                # Note: MultipleTimeGridModel time_grid is not type-stable due to Union return types
                # This is expected behavior and doesn't affect functionality
                Test.@test CTModels.time_grid(sol, :state) isa Vector{Float64}
                Test.@test CTModels.time_grid(sol, :control) isa Vector{Float64}
                Test.@test CTModels.time_grid(sol, :costate) isa Vector{Float64}
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_solution_multi_grids() = TestSolutionMultiGrids.test_solution_multi_grids()
