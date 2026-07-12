"""
Regression guard for the `where`-clause bound-dropping pitfall (see
`.reports/2026-07-12_alias-where-bounds-audit.md` and the Handbook rule in
`philosophy/types-traits-interfaces.md#aliases-and-where`).

A `where {X}` clause that names a type parameter without repeating the bound the
struct already declares for it silently widens it to `<:Any`. This is invisible
via `isa` on concrete instances, but it breaks Julia's method-specificity ranking
the moment a competing method exists — either mis-dispatching silently or throwing
`MethodError: ... is ambiguous`.

CTModels has no parametric aliases, so the CTFlows-style `Alias <: Parent` guard
does not apply. Instead this test asserts, for each method whose `where`-clause was
tightened, that the induced `TypeVar`'s upper bound is the intended bound and not
`Any`. A future edit that drops one of these bounds again fails loudly here.
"""

module TestWhereBounds

import Test: Test
import CTBase.Traits: Traits
import CTModels.Components: Components
import CTModels.Models: Models

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Upper bound of the outermost `where`-var of the method dispatched for `argtypes`.
# Returns `nothing` when the signature is not a `UnionAll` (i.e. no `where`-var at
# all), which fails the `=== expected` assertions below just as a widened bound does.
function _where_ub(f, argtypes::Type{<:Tuple})
    m = which(f, argtypes)
    return m.sig isa UnionAll ? m.sig.var.ub : nothing
end

function test_where_bounds()
    Test.@testset "where-clause bound-dropping regression guard" verbose = VERBOSE showtiming =
        SHOWTIMING begin

        # The 5 ConstraintsModel accessors: each restricts 4 params to <:Tuple in the
        # type-parameter position and extracts the 5th via a `where`-clause that must
        # repeat the same <:Tuple bound (constraints_accessors.jl). `which` on a bare
        # ConstraintsModel argument selects the ConstraintsModel-specific method (the
        # convenience Model-forwarding overload does not match a ConstraintsModel).
        Test.@testset "ConstraintsModel accessors — where-var ub === Tuple" begin
            CM = Tuple{Components.ConstraintsModel}
            Test.@test _where_ub(Components.path_constraints_nl, CM) === Tuple
            Test.@test _where_ub(Components.boundary_constraints_nl, CM) === Tuple
            Test.@test _where_ub(Components.state_constraints_box, CM) === Tuple
            Test.@test _where_ub(Components.control_constraints_box, CM) === Tuple
            Test.@test _where_ub(Components.variable_constraints_box, CM) === Tuple
        end

        # Model's time-dependence trait reads TD from the type parameter; the method's
        # `where`-clause must repeat the `TD<:TimeDependence` bound the Model struct
        # declares (model.jl).
        Test.@testset "Model time_dependence — where-var ub === TimeDependence" begin
            Test.@test _where_ub(Traits.time_dependence, Tuple{Models.Model}) ===
                Components.TimeDependence
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_where_bounds() = TestWhereBounds.test_where_bounds()
