module TestBuildExamodel

using Test: Test
import CTBase.Exceptions
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_build_examodel()
    Test.@testset "Build Examodel Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Error on functional API model
        # ====================================================================

        Test.@testset "get_build_examodel error on functional API model" begin
            # Build a minimal OCP using the functional (macro-free) API
            ocp = CTModels.PreModel()
            CTModels.time!(ocp; t0=0.0, tf=1.0)
            CTModels.state!(ocp, 2)
            CTModels.control!(ocp, 1)

            # Simple dynamics function
            dynamics!(r, t, x, u, v) = (r[1] = x[2]; r[2] = u[1])
            CTModels.dynamics!(ocp, dynamics!)

            # Simple objective
            CTModels.objective!(ocp, :min, mayer=(x0, xf) -> xf[1]^2)

            # Set time dependence (required before build)
            CTModels.time_dependence!(ocp, autonomous=true)

            # Build without build_examodel (functional API)
            model = CTModels.build(ocp)

            # Attempting to get build_examodel should throw PreconditionError
            Test.@test_throws Exceptions.PreconditionError CTModels.get_build_examodel(model)

            # Verify the error message contains the key information
            try
                CTModels.get_build_examodel(model)
                Test.@test false  # Should not reach here
            catch err
                Test.@test err isa Exceptions.PreconditionError
                Test.@test occursin(":exa modeler", err.msg)
                Test.@test occursin("functional", err.reason)
                Test.@test occursin("macro-free", err.reason)
                Test.@test occursin(":adnlp", err.suggestion)
                Test.@test occursin("@def", err.suggestion)
                Test.@test occursin("Exa builder", err.context)
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Verify functional API workflow
        # ====================================================================

        Test.@testset "Functional API workflow integration" begin
            # Build a complete OCP using functional API
            ocp = CTModels.PreModel()
            CTModels.time!(ocp; t0=0.0, tf=1.0)
            CTModels.state!(ocp, 2)
            CTModels.control!(ocp, 1)
            CTModels.dynamics!(ocp, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u[1]))
            CTModels.objective!(ocp, :min, mayer=(x0, xf) -> xf[1]^2)

            # Set time dependence (required before build)
            CTModels.time_dependence!(ocp, autonomous=true)

            # Build without build_examodel
            model = CTModels.build(ocp)

            # Verify model is built but has no Exa builder
            Test.@test model isa CTModels.Model
            Test.@test model.build_examodel === nothing

            # Verify get_build_examodel throws informative error
            try
                CTModels.get_build_examodel(model)
                Test.@test false  # Should not reach here
            catch err
                Test.@test err isa Exceptions.PreconditionError
                Test.@test occursin(":exa modeler", err.msg)
                Test.@test occursin("functional", err.reason)
                Test.@test occursin("macro-free", err.reason)
                Test.@test occursin(":adnlp", err.suggestion)
                Test.@test occursin("@def", err.suggestion)
                Test.@test occursin("Exa builder", err.context)
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_build_examodel() = TestBuildExamodel.test_build_examodel()
