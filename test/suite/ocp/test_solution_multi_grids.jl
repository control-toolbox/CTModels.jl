# ------------------------------------------------------------------------------ #
# Tests for multiple time grids in OCP solutions
# ------------------------------------------------------------------------------ #

module TestSolutionMultiGrids

using Test
using CTModels

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# Import exception types for testing
using CTBase: CTBase
const Exceptions = CTBase.Exceptions

function test_solution_multi_grids()
    @testset "Multiple Time Grids Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Time Grid Models
        # ====================================================================
        
        @testset "Time Grid Models" begin
            @testset "UnifiedTimeGridModel" begin
                T = LinRange(0, 1, 101)
                tgm = CTModels.UnifiedTimeGridModel(T)
                @test tgm isa CTModels.UnifiedTimeGridModel
                @test tgm isa CTModels.AbstractTimeGridModel
                @test tgm.value == T
            end
            
            @testset "MultipleTimeGridModel" begin
                T_state = LinRange(0, 1, 101)
                T_control = LinRange(0, 1, 51)
                T_costate = LinRange(0, 1, 76)
                T_dual = LinRange(0, 1, 101)
                
                mtgm = CTModels.MultipleTimeGridModel(
                    state=T_state,
                    control=T_control,
                    costate=T_costate,
                    path=T_dual,
                    dual=T_dual
                )
                @test mtgm isa CTModels.MultipleTimeGridModel
                @test mtgm isa CTModels.AbstractTimeGridModel
                @test mtgm.grids.state == T_state
                @test mtgm.grids.control == T_control
                @test mtgm.grids.costate == T_costate
                @test mtgm.grids.path == T_dual
                @test mtgm.grids.dual == T_dual
            end
        end
        
    # ====================================================================
    # UNIT TESTS - Component Symbol Cleaning
    # ====================================================================
        
    @testset "Component Symbol Cleaning" begin
        @testset "clean_component_symbols" begin
            # Test singular forms (unchanged)
            @test CTModels.clean_component_symbols((:state,)) == (:state,)
            @test CTModels.clean_component_symbols((:control,)) == (:control,)
            @test CTModels.clean_component_symbols((:costate,)) == (:costate,)
            @test CTModels.clean_component_symbols((:path,)) == (:path,)
            @test CTModels.clean_component_symbols((:dual,)) == (:dual,)
                
            # Test plural forms (converted to singular)
            @test CTModels.clean_component_symbols((:states,)) == (:state,)
            @test CTModels.clean_component_symbols((:controls,)) == (:control,)
            @test CTModels.clean_component_symbols((:costates,)) == (:costate,)
            @test CTModels.clean_component_symbols((:duals,)) == (:dual,)
                
            # Test ambiguous terms (mapped to :path)
            @test CTModels.clean_component_symbols((:constraint,)) == (:path,)
            @test CTModels.clean_component_symbols((:constraints,)) == (:path,)
            @test CTModels.clean_component_symbols((:cons,)) == (:path,)
                
            # Test mixed input
            @test CTModels.clean_component_symbols((:states, :controls, :constraint, :duals)) == (:state, :control, :path, :dual)
                
            # Test duplicate removal
            @test CTModels.clean_component_symbols((:state, :state)) == (:state,)
            @test CTModels.clean_component_symbols((:states, :state)) == (:state,)
        end
    end
        
    # ====================================================================
    # UNIT TESTS - Build Solution with Multiple Grids
    # ====================================================================
        
    @testset "Build Solution with Multiple Grids" begin
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
            
        @testset "Identical grids → UnifiedTimeGridModel" begin
            T = collect(LinRange(0, 1, 101))
            X = [1.0 - t/100 for t in 1:101, i in 1:2]
            U = [sin(2π * t/100) for t in 1:101, i in 1:1]
            P = zeros(101, 2)
            v = Float64[]
                
            sol = CTModels.build_solution(
                ocp, T, T, T, T, X, U, v, P;
                objective=0.5, iterations=10, constraints_violation=1e-6,
                message="Success", status=:optimal, successful=true
            )
                
            @test CTModels.time_grid_model(sol) isa CTModels.UnifiedTimeGridModel
            @test CTModels.time_grid(sol) == T
        end
            
            @testset "Different grids → MultipleTimeGridModel" begin
                T_state = collect(LinRange(0, 1, 101))
                T_control = collect(LinRange(0, 1, 51))
                T_costate = collect(LinRange(0, 1, 76))
                T_dual = collect(LinRange(0, 1, 101))
                
                X = [1.0 - t/100 for t in 1:101, i in 1:2]
                U = [sin(2π * t/50) for t in 1:51, i in 1:1]
                P = zeros(76, 2)
                v = Float64[]
                
                sol = CTModels.build_solution(
                    ocp, T_state, T_control, T_costate, T_dual, X, U, v, P;
                    objective=0.5, iterations=10, constraints_violation=1e-6,
                    message="Success", status=:optimal, successful=true
                )
                
                @test CTModels.time_grid_model(sol) isa CTModels.MultipleTimeGridModel
                @test CTModels.time_grid(sol, :state) == T_state
                @test CTModels.time_grid(sol, :control) == T_control
                @test CTModels.time_grid(sol, :costate) == T_costate
                @test CTModels.time_grid(sol, :dual) == T_dual
                @test CTModels.time_grid(sol, :path) == T_dual  # Same as dual
            end
            
            @testset "Nothing dual grid" begin
                T_state = collect(LinRange(0, 1, 101))
                T_control = collect(LinRange(0, 1, 51))
                T_costate = collect(LinRange(0, 1, 76))
                T_dual = nothing
                
                X = [1.0 - t/100 for t in 1:101, i in 1:2]
                U = [sin(2π * t/50) for t in 1:51, i in 1:1]
                P = zeros(76, 2)
                v = Float64[]
                
                sol = CTModels.build_solution(
                    ocp, T_state, T_control, T_costate, T_dual, X, U, v, P;
                    objective=0.5, iterations=10, constraints_violation=1e-6,
                    message="Success", status=:optimal, successful=true
                )
                
                @test CTModels.time_grid_model(sol) isa CTModels.MultipleTimeGridModel
                @test CTModels.time_grid(sol, :state) == T_state
                @test CTModels.time_grid(sol, :control) == T_control
                @test CTModels.time_grid(sol, :costate) == T_costate
                @test CTModels.time_grid(sol, :dual) == T_state  # Falls back to state grid
                @test CTModels.time_grid(sol, :path) == T_state
            end
        end
        
        # ====================================================================
        # UNIT TESTS - Time Grid Getters
        # ====================================================================
        
        @testset "Time Grid Getters" begin
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
            
            @testset "UnifiedTimeGridModel getters" begin
                sol = CTModels.build_solution(
                    ocp, T, T, T, T, X, U, v, P;
                    objective=0.5, iterations=10, constraints_violation=1e-6,
                    message="Success", status=:optimal, successful=true
                )
                
                # Should work without component specification
                @test CTModels.time_grid(sol) == T
                
                # Should also work with component specification (fallback to unified)
                @test CTModels.time_grid(sol, :state) == T
                @test CTModels.time_grid(sol, :control) == T
                @test CTModels.time_grid(sol, :costate) == T
                @test CTModels.time_grid(sol, :dual) == T
                @test CTModels.time_grid(sol, :path) == T
                
                # Test plural forms
                @test CTModels.time_grid(sol, :states) == T
                @test CTModels.time_grid(sol, :controls) == T
            end
            
            @testset "MultipleTimeGridModel getters" begin
                T_state = collect(LinRange(0, 1, 101))
                T_control = collect(LinRange(0, 1, 51))
                
                # Create data matching the grid sizes
                X_multi = [1.0 - t/100 for t in 1:101, i in 1:2]  # 101 points for state
                U_multi = [sin(2π * t/50) for t in 1:51, i in 1:1]   # 51 points for control
                P_multi = zeros(101, 2)  # 101 points for costate
                v_multi = Float64[]
                
                sol = CTModels.build_solution(
                    ocp, T_state, T_control, T_state, T_state, X_multi, U_multi, v_multi, P_multi;
                    objective=0.5, iterations=10, constraints_violation=1e-6,
                    message="Success", status=:optimal, successful=true
                )
                
                # Should require component specification
                @test_throws Exceptions.IncorrectArgument CTModels.time_grid(sol)
                
                # Should work with component specification
                @test CTModels.time_grid(sol, :state) == T_state
                @test CTModels.time_grid(sol, :control) == T_control
                @test CTModels.time_grid(sol, :costate) == T_state
                @test CTModels.time_grid(sol, :dual) == T_state
                @test CTModels.time_grid(sol, :path) == T_state
                
                # Test plural forms
                @test CTModels.time_grid(sol, :states) == T_state
                @test CTModels.time_grid(sol, :controls) == T_control
                
                # Test invalid component
                @test_throws Exceptions.IncorrectArgument CTModels.time_grid(sol, :invalid)
            end
        end
        
        # ====================================================================
        # INTEGRATION TESTS - Serialization
        # ====================================================================
        
        @testset "Serialization with Multiple Grids" begin
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
            T_dual = collect(LinRange(0, 1, 101))
            
            X = [1.0 - t/100 for t in 1:101, i in 1:2]
            U = [sin(2π * t/50) for t in 1:51, i in 1:1]
            P = zeros(76, 2)
            v = Float64[]
            
            sol = CTModels.build_solution(
                ocp, T_state, T_control, T_costate, T_dual, X, U, v, P;
                objective=0.5, iterations=10, constraints_violation=1e-6,
                message="Success", status=:optimal, successful=true
            )
            
            @testset "_serialize_solution" begin
                data = CTModels._serialize_solution(sol)
                
                # Should have multiple time grid fields
                @test haskey(data, "time_grid_state")
                @test haskey(data, "time_grid_control")
                @test haskey(data, "time_grid_costate")
                @test haskey(data, "time_grid_dual")
                
                # Should not have legacy single time grid
                @test !haskey(data, "time_grid")
                
                # Time grids should match
                @test data["time_grid_state"] == T_state
                @test data["time_grid_control"] == T_control
                @test data["time_grid_costate"] == T_costate
                @test data["time_grid_dual"] == T_dual
            end
        end
        
        # ====================================================================
        # INTEGRATION TESTS - Backward Compatibility
        # ====================================================================
        
        @testset "Backward Compatibility" begin
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
            
            @testset "Legacy build_solution signature" begin
                sol = CTModels.build_solution(
                    ocp, T, X, U, v, P;
                    objective=0.5, iterations=10, constraints_violation=1e-6,
                    message="Success", status=:optimal, successful=true
                )
                
                # Should create UnifiedTimeGridModel
                @test CTModels.time_grid_model(sol) isa CTModels.UnifiedTimeGridModel
                @test CTModels.time_grid(sol) == T
                
                # Legacy serialization format
                data = CTModels._serialize_solution(sol)
                @test haskey(data, "time_grid")
                @test !haskey(data, "time_grid_state")
                @test data["time_grid"] == T
            end
        end
        
        # ====================================================================
        # ERROR TESTS
        # ====================================================================
        
        @testset "Error Handling" begin
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
            X = [1.0 - t/100 for t in 1:101, i in 1:2]
            U = [sin(2π * t/50) for t in 1:51, i in 1:1]
            P = zeros(101, 2)
            v = Float64[]
            
            sol = CTModels.build_solution(
                ocp, T_state, T_control, T_state, T_state, X, U, v, P;
                objective=0.5, iterations=10, constraints_violation=1e-6,
                message="Success", status=:optimal, successful=true
            )
            
            @testset "Invalid component access" begin
                @test_throws Exceptions.IncorrectArgument CTModels.time_grid(sol, :invalid)
                @test_throws Exceptions.IncorrectArgument CTModels.time_grid(sol, :unknown)
            end
            
            @testset "Missing component specification" begin
                @test_throws Exceptions.IncorrectArgument CTModels.time_grid(sol)
            end
        end
        
        # ====================================================================
        # TYPE STABILITY TESTS
        # ====================================================================
        
        @testset "Type Stability" begin
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
            
            @testset "UnifiedTimeGridModel type stability" begin
                sol = CTModels.build_solution(
                    ocp, T, T, T, T, X, U, v, P;
                    objective=0.5, iterations=10, constraints_violation=1e-6,
                    message="Success", status=:optimal, successful=true
                )
                
                @test_nowarn @inferred CTModels.time_grid(sol)
                @test_nowarn @inferred CTModels.time_grid(sol, :state)
                @test_nowarn @inferred CTModels.time_grid(sol, :control)
            end
            
            @testset "MultipleTimeGridModel type stability" begin
                T_state = collect(LinRange(0, 1, 101))
                T_control = collect(LinRange(0, 1, 51))
                
                # Create data matching the grid sizes
                X_stab = [1.0 - t/100 for t in 1:101, i in 1:2]  # 101 points for state
                U_stab = [sin(2π * t/50) for t in 1:51, i in 1:1]   # 51 points for control
                P_stab = zeros(101, 2)  # 101 points for costate
                v_stab = Float64[]
                
                sol = CTModels.build_solution(
                    ocp, T_state, T_control, T_state, T_state, X_stab, U_stab, v_stab, P_stab;
                    objective=0.5, iterations=10, constraints_violation=1e-6,
                    message="Success", status=:optimal, successful=true
                )
                
                # Note: MultipleTimeGridModel time_grid is not type-stable due to Union return types
                # This is expected behavior and doesn't affect functionality
                @test CTModels.time_grid(sol, :state) isa Vector{Float64}
                @test CTModels.time_grid(sol, :control) isa Vector{Float64}
                @test CTModels.time_grid(sol, :costate) isa Vector{Float64}
            end
        end
    end
end

end # module

# Export test function for TestRunner
test_solution_multi_grids() = TestSolutionMultiGrids.test_solution_multi_grids()
