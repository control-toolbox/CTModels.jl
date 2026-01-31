module TestExceptionOCPIntegration

using Test
using CTModels
using CTModels.Exceptions

"""
Tests for exception integration in OCP components
Tests that enriched exceptions are properly thrown in OCP workflows
"""
function test_ocp_exception_integration()
    @testset "OCP Exception Integration" verbose = true begin
        
        @testset "State! Exceptions" begin
            # Test duplicate state definition
            ocp = OCP()
            state!(ocp, 2)
            
            @test_throws Exceptions.UnauthorizedCall begin
                state!(ocp, 3)
            end
            
            # Verify exception content
            try
                state!(ocp, 3)
            catch e
                @test e isa Exceptions.UnauthorizedCall
                @test e.msg == "State already set"
                @test !isnothing(e.reason)
                @test !isnothing(e.suggestion)
                @test !isnothing(e.context)
                @test occursin("state has already been defined", e.reason)
                @test occursin("Create a new OCP instance", e.suggestion)
                @test occursin("duplicate definition check", e.context)
            end
        end
        
        @testset "Control! Exceptions" begin
            # Test duplicate control definition
            ocp = OCP()
            state!(ocp, 2)
            control!(ocp, 1)
            
            @test_throws Exceptions.UnauthorizedCall begin
                control!(ocp, 2)
            end
            
            # Verify exception content
            try
                control!(ocp, 2)
            catch e
                @test e isa Exceptions.UnauthorizedCall
                @test e.msg == "Control already set"
                @test !isnothing(e.reason)
                @test !isnothing(e.suggestion)
                @test !isnothing(e.context)
                @test occursin("control has already been defined", e.reason)
                @test occursin("Create a new OCP instance", e.suggestion)
                @test occursin("duplicate definition check", e.context)
            end
        end
        
        @testset "Variable! Exceptions" begin
            # Test variable ordering violations
            ocp = OCP()
            state!(ocp, 2)
            control!(ocp, 1)
            times!(ocp, t0=0, tf=1)
            
            # Set objective first (should fail)
            objective!(ocp, :min, mayer=(x0, xf, v) -> x0[1])
            
            @test_throws Exceptions.UnauthorizedCall begin
                variable!(ocp, 1)
            end
            
            # Verify exception content
            try
                variable!(ocp, 1)
            catch e
                @test e isa Exceptions.UnauthorizedCall
                @test e.msg == "Variable must be set before objective"
                @test !isnothing(e.reason)
                @test !isnothing(e.suggestion)
                @test !isnothing(e.context)
                @test occursin("objective has already been defined", e.reason)
                @test occursin("Call variable!(ocp, dimension) before objective!", e.suggestion)
                @test occursin("objective ordering check", e.context)
            end
        end
        
        @testset "Times! Exceptions" begin
            # Test duplicate time definition
            ocp = OCP()
            state!(ocp, 2)
            times!(ocp, t0=0, tf=1)
            
            @test_throws Exceptions.UnauthorizedCall begin
                times!(ocp, t0=1, tf=2)
            end
            
            # Verify exception content
            try
                times!(ocp, t0=1, tf=2)
            catch e
                @test e isa Exceptions.UnauthorizedCall
                @test e.msg == "Time already set"
                @test !isnothing(e.reason)
                @test !isnothing(e.suggestion)
                @test !isnothing(e.context)
                @test occursin("time has already been defined", e.reason)
                @test occursin("Create a new OCP instance", e.suggestion)
                @test occursin("duplicate definition check", e.context)
            end
        end
        
        @testset "Objective! Exceptions" begin
            # Test objective without prerequisites
            ocp = OCP()
            
            @test_throws Exceptions.UnauthorizedCall begin
                objective!(ocp, :min, mayer=(x0, xf, v) -> x0[1])
            end
            
            # Verify exception content (should be state validation first)
            try
                objective!(ocp, :min, mayer=(x0, xf, v) -> x0[1])
            catch e
                @test e isa Exceptions.UnauthorizedCall
                @test e.msg == "State must be set before objective"
                @test !isnothing(e.reason)
                @test !isnothing(e.suggestion)
                @test !isnothing(e.context)
                @test occursin("state has not been defined yet", e.reason)
                @test occursin("Call state!(ocp, dimension) before objective!", e.suggestion)
                @test occursin("state validation", e.context)
            end
            
            # Test with state set but not control
            state!(ocp, 2)
            try
                objective!(ocp, :min, mayer=(x0, xf, v) -> x0[1])
            catch e
                @test e isa Exceptions.UnauthorizedCall
                @test e.msg == "Control must be set before objective"
                @test occursin("control has not been defined yet", e.reason)
                @test occursin("Call control!(ocp, dimension) before objective!", e.suggestion)
                @test occursin("control validation", e.context)
            end
        end
        
        @testset "Dynamics! Exceptions" begin
            # Test dynamics without prerequisites
            ocp = OCP()
            
            @test_throws Exceptions.UnauthorizedCall begin
                dynamics!(ocp, (out, t, x, u, v) -> out .= x)
            end
            
            # Verify exception content
            try
                dynamics!(ocp, (out, t, x, u, v) -> out .= x)
            catch e
                @test e isa Exceptions.UnauthorizedCall
                @test e.msg == "State must be set before defining dynamics"
                @test !isnothing(e.reason)
                @test !isnothing(e.suggestion)
                @test !isnothing(e.context)
                @test occursin("state has not been defined yet", e.reason)
                @test occursin("Call state!(ocp, dimension) before dynamics!", e.suggestion)
                @test occursin("state validation", e.context)
            end
            
            # Test duplicate dynamics
            ocp2 = OCP()
            state!(ocp2, 2)
            control!(ocp2, 1)
            times!(ocp2, t0=0, tf=1)
            dynamics!(ocp2, (out, t, x, u, v) -> out .= x)
            
            @test_throws Exceptions.UnauthorizedCall begin
                dynamics!(ocp2, (out, t, x, u, v) -> out .= 2*x)
            end
            
            # Verify duplicate dynamics exception
            try
                dynamics!(ocp2, (out, t, x, u, v) -> out .= 2*x)
            catch e
                @test e isa Exceptions.UnauthorizedCall
                @test e.msg == "Dynamics already set"
                @test occursin("dynamics have already been defined", e.reason)
                @test occursin("Create a new OCP instance", e.suggestion)
                @test occursin("duplicate definition check", e.context)
            end
        end
        
        @testset "Constraint! Exceptions" begin
            # Test constraint without prerequisites
            ocp = OCP()
            
            @test_throws Exceptions.UnauthorizedCall begin
                constraint!(ocp, :state, lb=[0], ub=[1])
            end
            
            # Verify exception content
            try
                constraint!(ocp, :state, lb=[0], ub=[1])
            catch e
                @test e isa Exceptions.UnauthorizedCall
                @test e.msg == "State must be set before adding constraints"
                @test !isnothing(e.reason)
                @test !isnothing(e.suggestion)
                @test !isnothing(e.context)
                @test occursin("state has not been defined yet", e.reason)
                @test occursin("Call state!(ocp, dimension) before adding constraints", e.suggestion)
                @test occursin("state validation", e.context)
            end
            
            # Test duplicate constraint
            ocp2 = OCP()
            state!(ocp2, 2)
            control!(ocp2, 1)
            times!(ocp2, t0=0, tf=1)
            constraint!(ocp2, :state, lb=[0], ub=[1], label=:test)
            
            @test_throws Exceptions.UnauthorizedCall begin
                constraint!(ocp2, :state, lb=[0], ub=[2], label=:test)
            end
            
            # Verify duplicate constraint exception
            try
                constraint!(ocp2, :state, lb=[0], ub=[2], label=:test)
            catch e
                @test e isa Exceptions.UnauthorizedCall
                @test e.msg == "Constraint already exists"
                @test occursin("constraint with label", e.reason)
                @test occursin("Use a different label", e.suggestion)
                @test occursin("duplicate label validation", e.context)
            end
        end
        
        @testset "IncorrectArgument in Constraints" begin
            ocp = OCP()
            state!(ocp, 2)
            control!(ocp, 1)
            times!(ocp, t0=0, tf=1)
            
            # Test bounds dimension mismatch
            @test_throws Exceptions.IncorrectArgument begin
                constraint!(ocp, :state, lb=[0, 1], ub=[2])  # Different lengths
            end
            
            # Verify exception content
            try
                constraint!(ocp, :state, lb=[0, 1], ub=[2])
            catch e
                @test e isa Exceptions.IncorrectArgument
                @test e.msg == "Bounds dimension mismatch"
                @test !isnothing(e.got)
                @test !isnothing(e.expected)
                @test !isnothing(e.suggestion)
                @test !isnothing(e.context)
                @test occursin("lb length=2, ub length=1", e.got)
                @test occursin("lb and ub with same length", e.expected)
                @test occursin("constraint!(ocp, type", e.suggestion)
                @test occursin("validating bounds dimensions", e.context)
            end
        end
    end
end

end # module

test_ocp_integration() = TestExceptionOCPIntegration.test_ocp_exception_integration()
