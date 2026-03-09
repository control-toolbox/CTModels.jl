module TestOCPIntegration

using Test: Test
using CTModels: CTModels
import CTBase.Exceptions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_ocp_exception_integration()
    Test.@testset "OCP Exception Integration" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Exception Types
        # ====================================================================

        Test.@testset "Exception Types" begin
            # Test exception type definitions
        end

        # ====================================================================
        # INTEGRATION TESTS
        # ====================================================================
        Test.@testset "State! Exceptions" begin
            # Test duplicate state definition
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2)

            Test.@test_throws Exceptions.PreconditionError begin
                CTModels.state!(ocp, 3)
            end

            # Verify exception content
            try
                CTModels.state!(ocp, 3)
            catch e
                Test.@test e isa Exceptions.PreconditionError
                Test.@test e.msg == "State already set"
                Test.@test !isnothing(e.reason)
                Test.@test !isnothing(e.suggestion)
                Test.@test !isnothing(e.context)
                Test.@test occursin("state has already been defined", e.reason)
                Test.@test occursin("Create a new OCP instance", e.suggestion)
                Test.@test occursin("duplicate definition check", e.context)
            end
        end

        Test.@testset "Control! Exceptions" begin
            # Test duplicate control definition
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2)
            CTModels.control!(ocp, 1)

            Test.@test_throws Exceptions.PreconditionError begin
                CTModels.control!(ocp, 2)
            end

            # Verify exception content
            try
                CTModels.control!(ocp, 2)
            catch e
                Test.@test e isa Exceptions.PreconditionError
                Test.@test e.msg == "Control already set"
                Test.@test !isnothing(e.reason)
                Test.@test !isnothing(e.suggestion)
                Test.@test !isnothing(e.context)
                Test.@test occursin("control has already been defined", e.reason)
                Test.@test occursin("Create a new OCP instance", e.suggestion)
                Test.@test occursin("duplicate definition check", e.context)
            end
        end

        Test.@testset "Variable! Exceptions" begin
            # Test variable ordering violations
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2)
            CTModels.control!(ocp, 1)
            CTModels.time!(ocp, t0=0, tf=1)

            # Set objective first (should fail)
            CTModels.objective!(ocp, :min, mayer=(x0, xf, v) -> x0[1])

            Test.@test_throws Exceptions.PreconditionError begin
                CTModels.variable!(ocp, 1)
            end

            # Verify exception content
            try
                CTModels.variable!(ocp, 1)
            catch e
                Test.@test e isa Exceptions.PreconditionError
                Test.@test e.msg == "Variable must be set before objective"
                Test.@test !isnothing(e.reason)
                Test.@test !isnothing(e.suggestion)
                Test.@test !isnothing(e.context)
                Test.@test occursin("objective has already been defined", e.reason)
                Test.@test occursin(
                    "Call variable!(ocp, dimension) before objective!", e.suggestion
                )
                Test.@test occursin("objective ordering check", e.context)
            end
        end

        Test.@testset "Times! Exceptions" begin
            # Test duplicate time definition
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2)
            CTModels.time!(ocp, t0=0, tf=1)

            Test.@test_throws Exceptions.PreconditionError begin
                CTModels.time!(ocp, t0=1, tf=2)
            end

            # Verify exception content
            try
                CTModels.time!(ocp, t0=1, tf=2)
            catch e
                Test.@test e isa Exceptions.PreconditionError
                Test.@test e.msg == "Time already set"
                Test.@test !isnothing(e.reason)
                Test.@test !isnothing(e.suggestion)
                Test.@test !isnothing(e.context)
                Test.@test occursin("time has already been defined", e.reason)
                Test.@test occursin("Create a new OCP instance", e.suggestion)
                Test.@test occursin("duplicate definition check", e.context)
            end
        end

        Test.@testset "Objective! Exceptions" begin
            # Test objective without prerequisites
            ocp = CTModels.PreModel()

            Test.@test_throws Exceptions.PreconditionError begin
                CTModels.objective!(ocp, :min, mayer=(x0, xf, v) -> x0[1])
            end

            # Verify exception content (should be state validation first)
            try
                CTModels.objective!(ocp, :min, mayer=(x0, xf, v) -> x0[1])
            catch e
                Test.@test e isa Exceptions.PreconditionError
                Test.@test e.msg == "State must be set before objective"
                Test.@test !isnothing(e.reason)
                Test.@test !isnothing(e.suggestion)
                Test.@test !isnothing(e.context)
                Test.@test occursin("state has not been defined yet", e.reason)
                Test.@test occursin(
                    "Call state!(ocp, dimension) before objective!", e.suggestion
                )
                Test.@test occursin("state validation", e.context)
            end

            # Test with state set but not control
            CTModels.state!(ocp, 2)
            try
                CTModels.objective!(ocp, :min, mayer=(x0, xf, v) -> x0[1])
            catch e
                Test.@test e isa Exceptions.PreconditionError
                Test.@test e.msg == "Control must be set before objective"
                Test.@test occursin("control has not been defined yet", e.reason)
                Test.@test occursin(
                    "Call control!(ocp, dimension) before objective!", e.suggestion
                )
                Test.@test occursin("control validation", e.context)
            end
        end

        Test.@testset "Dynamics! Exceptions" begin
            # Test dynamics without prerequisites
            ocp = CTModels.PreModel()

            Test.@test_throws Exceptions.PreconditionError begin
                CTModels.dynamics!(ocp, (out, t, x, u, v) -> out .= x)
            end

            # Verify exception content
            try
                CTModels.dynamics!(ocp, (out, t, x, u, v) -> out .= x)
            catch e
                Test.@test e isa Exceptions.PreconditionError
                Test.@test e.msg == "State must be set before defining dynamics"
                Test.@test !isnothing(e.reason)
                Test.@test !isnothing(e.suggestion)
                Test.@test !isnothing(e.context)
                Test.@test occursin("state has not been defined yet", e.reason)
                Test.@test occursin(
                    "Call state!(ocp, dimension) before dynamics!", e.suggestion
                )
                Test.@test occursin("state validation", e.context)
            end

            # Test duplicate dynamics
            ocp2 = CTModels.PreModel()
            CTModels.state!(ocp2, 2)
            CTModels.control!(ocp2, 1)
            CTModels.time!(ocp2, t0=0, tf=1)
            CTModels.dynamics!(ocp2, (out, t, x, u, v) -> out .= x)

            Test.@test_throws Exceptions.PreconditionError begin
                CTModels.dynamics!(ocp2, (out, t, x, u, v) -> out .= 2*x)
            end

            # Verify duplicate dynamics exception
            try
                CTModels.dynamics!(ocp2, (out, t, x, u, v) -> out .= 2*x)
            catch e
                Test.@test e isa Exceptions.PreconditionError
                Test.@test e.msg == "Dynamics already set"
                Test.@test occursin("dynamics have already been defined", e.reason)
                Test.@test occursin("Create a new OCP instance", e.suggestion)
                Test.@test occursin("duplicate definition check", e.context)
            end
        end

        Test.@testset "Constraint! Exceptions" begin
            # Test constraint without prerequisites
            ocp = CTModels.PreModel()

            Test.@test_throws Exceptions.PreconditionError begin
                CTModels.constraint!(ocp, :state, lb=[0], ub=[1])
            end

            # Verify exception content
            try
                CTModels.constraint!(ocp, :state, lb=[0], ub=[1])
            catch e
                Test.@test e isa Exceptions.PreconditionError
                Test.@test e.msg == "State must be set before adding constraints"
                Test.@test !isnothing(e.reason)
                Test.@test !isnothing(e.suggestion)
                Test.@test !isnothing(e.context)
                Test.@test occursin("state has not been defined yet", e.reason)
                Test.@test occursin(
                    "Call state!(ocp, dimension) before adding constraints", e.suggestion
                )
                Test.@test occursin("state validation", e.context)
            end

            # Test duplicate constraint
            ocp2 = CTModels.PreModel()
            CTModels.state!(ocp2, 2)
            CTModels.control!(ocp2, 1)
            CTModels.time!(ocp2, t0=0, tf=1)
            CTModels.constraint!(ocp2, :state, lb=[0, 0], ub=[1, 1], label=:test)

            Test.@test_throws Exceptions.PreconditionError begin
                CTModels.constraint!(ocp2, :state, lb=[0, 0], ub=[2, 2], label=:test)
            end

            # Verify duplicate constraint exception
            try
                CTModels.constraint!(ocp2, :state, lb=[0, 0], ub=[2, 2], label=:test)
            catch e
                Test.@test e isa Exceptions.PreconditionError
                Test.@test e.msg == "Constraint already exists"
                Test.@test occursin("constraint with label", e.reason)
                Test.@test occursin("Use a different label", e.suggestion)
                Test.@test occursin("duplicate label validation", e.context)
            end
        end

        Test.@testset "IncorrectArgument in Constraints" begin
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2)
            CTModels.control!(ocp, 1)
            CTModels.time!(ocp, t0=0, tf=1)

            # Test bounds dimension mismatch
            Test.@test_throws Exceptions.IncorrectArgument begin
                CTModels.constraint!(ocp, :state, lb=[0, 1], ub=[2])  # Different lengths
            end

            # Verify exception content
            try
                CTModels.constraint!(ocp, :state, lb=[0, 1], ub=[2])
            catch e
                Test.@test e isa Exceptions.IncorrectArgument
                Test.@test e.msg == "Bounds dimension mismatch"
                Test.@test !isnothing(e.got)
                Test.@test !isnothing(e.expected)
                Test.@test !isnothing(e.suggestion)
                Test.@test !isnothing(e.context)
                Test.@test occursin("lb length=2, ub length=1", e.got)
                Test.@test occursin("lb and ub with same length", e.expected)
                Test.@test occursin("constraint!(ocp, type", e.suggestion)
                Test.@test occursin("validating bounds dimensions", e.context)
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_ocp_integration() = TestOCPIntegration.test_ocp_exception_integration()
