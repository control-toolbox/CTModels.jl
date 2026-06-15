module TestBuildExamodel

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Building: Building
import CTModels.Models: Models

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_build_examodel()
    Test.@testset "Build Examodel Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Error on functional API model
        # ====================================================================

        Test.@testset "get_build_examodel error on functional API model" begin
            # Build a minimal OCP using the functional (macro-free) API
            ocp = Building.PreModel()
            Building.time!(ocp; t0=0.0, tf=1.0)
            Building.state!(ocp, 2)
            Building.control!(ocp, 1)

            # Simple dynamics function
            dynamics!(r, t, x, u, v) = (r[1]=x[2]; r[2]=u[1])
            Building.dynamics!(ocp, dynamics!)

            # Simple objective
            Building.objective!(ocp, :min, mayer=(x0, xf) -> xf[1]^2)

            # Set time dependence (required before build)
            Building.time_dependence!(ocp, autonomous=true)

            # Build without build_examodel (functional API)
            model = Building.build(ocp)

            # Attempting to get build_examodel should throw PreconditionError
            Test.@test_throws Exceptions.PreconditionError Models.get_build_examodel(model)

            # Verify the error message contains the key information
            try
                Models.get_build_examodel(model)
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
            ocp = Building.PreModel()
            Building.time!(ocp; t0=0.0, tf=1.0)
            Building.state!(ocp, 2)
            Building.control!(ocp, 1)
            Building.dynamics!(ocp, (r, t, x, u, v) -> (r[1]=x[2]; r[2]=u[1]))
            Building.objective!(ocp, :min, mayer=(x0, xf) -> xf[1]^2)

            # Set time dependence (required before build)
            Building.time_dependence!(ocp, autonomous=true)

            # Build without build_examodel
            model = Building.build(ocp)

            # Verify model is built but has no Exa builder
            Test.@test model isa Models.Model
            Test.@test model.build_examodel === nothing

            # Verify get_build_examodel throws informative error
            try
                Models.get_build_examodel(model)
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
