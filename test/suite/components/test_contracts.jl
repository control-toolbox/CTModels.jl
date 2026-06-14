module TestContracts

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Models: Models

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ============================================================================
# Fake types — must be at module top-level (world-age constraint)
# ============================================================================

struct FakeStateModel <: Components.AbstractStateModel
    _name::String
    _components::Vector{String}
end
Components.name(m::FakeStateModel)::String = m._name
Components.components(m::FakeStateModel)::Vector{String} = m._components
Components.dimension(m::FakeStateModel)::Components.Dimension = length(m._components)

struct FakeControlModel <: Components.AbstractControlModel
    _name::String
    _components::Vector{String}
end
Components.name(m::FakeControlModel)::String = m._name
Components.components(m::FakeControlModel)::Vector{String} = m._components
Components.dimension(m::FakeControlModel)::Components.Dimension = length(m._components)

struct FakeVariableModel <: Components.AbstractVariableModel
    _name::String
    _components::Vector{String}
end
Components.name(m::FakeVariableModel)::String = m._name
Components.components(m::FakeVariableModel)::Vector{String} = m._components
Components.dimension(m::FakeVariableModel)::Components.Dimension = length(m._components)

struct FakeModel <: Models.AbstractModel end

# ============================================================================
# Generic contract checker functions — dispatch on abstract type
# These prove LSP: code written for the abstract type works with any conforming
# concrete type, including fakes defined above.
# ============================================================================

function check_state_contract(m::Components.AbstractStateModel)::Bool
    n = Components.name(m)
    cs = Components.components(m)
    d = Components.dimension(m)
    return n isa String && cs isa Vector{String} && d isa Int && d == length(cs)
end

function check_control_contract(m::Components.AbstractControlModel)::Bool
    n = Components.name(m)
    cs = Components.components(m)
    d = Components.dimension(m)
    return n isa String && cs isa Vector{String} && d isa Int && d == length(cs)
end

function check_variable_contract(m::Components.AbstractVariableModel)::Bool
    n = Components.name(m)
    cs = Components.components(m)
    d = Components.dimension(m)
    return n isa String && cs isa Vector{String} && d isa Int && d == length(cs)
end

function test_contracts()
    Test.@testset "Contract / LSP Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Contract: AbstractStateModel — LSP substitutability
        # ====================================================================

        Test.@testset "AbstractStateModel LSP" begin
            # Unit — fake satisfies the contract
            fake = FakeStateModel("x", ["x1", "x2"])
            Test.@test check_state_contract(fake)
            Test.@test Components.name(fake) == "x"
            Test.@test Components.components(fake) == ["x1", "x2"]
            Test.@test Components.dimension(fake) == 2

            # Contract — all concrete subtypes also satisfy the contract
            Test.@test check_state_contract(Components.StateModel("y", ["y1"]))
            xf = t -> [sin(t)]
            Test.@test check_state_contract(
                Components.StateModelSolution("x", ["x1"], xf)
            )
        end

        # ====================================================================
        # Contract: AbstractControlModel — LSP substitutability
        # ====================================================================

        Test.@testset "AbstractControlModel LSP" begin
            # Unit — fake satisfies the contract
            fake = FakeControlModel("u", ["u1", "u2"])
            Test.@test check_control_contract(fake)
            Test.@test Components.name(fake) == "u"
            Test.@test Components.components(fake) == ["u1", "u2"]
            Test.@test Components.dimension(fake) == 2

            # Contract — EmptyControlModel sentinel also satisfies the contract
            ec = Components.EmptyControlModel()
            Test.@test check_control_contract(ec)
            Test.@test Components.name(ec) == ""
            Test.@test Components.components(ec) == String[]
            Test.@test Components.dimension(ec) == 0
        end

        # ====================================================================
        # Contract: AbstractVariableModel — LSP substitutability
        # ====================================================================

        Test.@testset "AbstractVariableModel LSP" begin
            # Unit — fake satisfies the contract
            fake = FakeVariableModel("v", ["v1"])
            Test.@test check_variable_contract(fake)
            Test.@test Components.name(fake) == "v"
            Test.@test Components.components(fake) == ["v1"]
            Test.@test Components.dimension(fake) == 1

            # Contract — EmptyVariableModel sentinel also satisfies the contract
            ev = Components.EmptyVariableModel()
            Test.@test check_variable_contract(ev)
            Test.@test Components.name(ev) == ""
            Test.@test Components.components(ev) == String[]
            Test.@test Components.dimension(ev) == 0
        end

        # ====================================================================
        # Contract: AbstractDefinition — expression interface
        # ====================================================================

        Test.@testset "AbstractDefinition contract" begin
            # EmptyDefinition returns an empty block
            ed = Components.EmptyDefinition()
            expr = Components.expression(ed)
            Test.@test expr isa Expr
            Test.@test Meta.isexpr(expr, :block)
            Test.@test all(a -> a isa LineNumberNode, expr.args)

            # Definition wraps and returns its expression intact
            original = :(x = 1)
            d = Components.Definition(original)
            Test.@test Components.expression(d) == original
        end

        # ====================================================================
        # Contract: AbstractModel — stub errors (Liskov stubs)
        # Stubs on AbstractModel must throw PreconditionError so that calling
        # code gets a clear diagnostic when the model type is incomplete.
        # ====================================================================

        Test.@testset "AbstractModel mayer/lagrange stubs" begin
            fm = FakeModel()
            Test.@test_throws Exceptions.PreconditionError Components.mayer(fm)
            Test.@test_throws Exceptions.PreconditionError Components.lagrange(fm)
        end

        Test.@testset "AbstractModel initial_time/final_time stubs" begin
            fm = FakeModel()
            # No-argument forms (fixed-time shortcut) throw on abstract type
            Test.@test_throws Exceptions.PreconditionError Components.initial_time(fm)
            Test.@test_throws Exceptions.PreconditionError Components.final_time(fm)
            # Vector-argument forms (free-time access) throw on abstract type
            Test.@test_throws Exceptions.PreconditionError Components.initial_time(
                fm, [0.0]
            )
            Test.@test_throws Exceptions.PreconditionError Components.final_time(
                fm, [1.0]
            )
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_contracts() = TestContracts.test_contracts()
