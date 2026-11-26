"""
Tests of the Hamiltonian getters of a model: `pseudo_hamiltonian(ocp; p0)`,
`hamiltonian(ocp; p0)` (control-free) and `hamiltonian(ocp, u; p0)`.
"""

module TestHamiltonians

using Test: Test
using CTBase: Data, Exceptions, Traits
using CTModels: CTModels
using CTModels: Building, Models
using ForwardDiff: ForwardDiff
using JET: JET

include(joinpath("..", "..", "problems", "TestProblems.jl"))
using .TestProblems: TestProblems

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Model functions (module top-level)
# ==============================================================================

# 1-D, autonomous, fixed: ẋ = u, ∫ x² (the order-one example of the OptimalControl docs).
dyn_1d!(r, t, x, u, v) = (r[1]=u; nothing)
lag_1d(t, x, u, v) = x^2

# 2-D, non-autonomous, with a variable: ẋ = (x₂, t·u + v), ∫ (u² + t), Mayer xf₁.
dyn_2d!(r, t, x, u, v) = (r[1]=x[2]; r[2]=t * u + sum(v); nothing)   # v = [] if no variable
lag_2d(t, x, u, v) = u^2 + t
mayer_2d(x0, xf, v) = xf[1]

# 2-D control-free: ẋ = (x₂, −x₁), ∫ x₁².
dyn_cf!(r, t, x, u, v) = (r[1]=x[2]; r[2]=-x[1]; nothing)
lag_cf(t, x, u, v) = x[1]^2

# 1-D control-free, for the four arities: ẋ = t + v, ∫ x.
dyn_tv!(r, t, x, u, v) = (r[1]=t + sum(v); nothing)
lag_tv(t, x, u, v) = x

# Spies: model functions recording what they receive.
mutable struct SpyDynamics <: Function
    args::Any
    buffer_type::Any
    calls::Int
end
SpyDynamics() = SpyDynamics(nothing, nothing, 0)
function (s::SpyDynamics)(r, t, x, u, v)
    s.args = (t, x, u, v)
    s.buffer_type = typeof(r)
    s.calls += 1
    return nothing                       # writes nothing: the buffer must be zero
end

mutable struct SpyLagrange <: Function
    args::Any
    calls::Int
end
SpyLagrange() = SpyLagrange(nothing, 0)
function (s::SpyLagrange)(t, x, u, v)
    s.args = (t, x, u, v)
    s.calls += 1
    return 7.0
end

# Batched states (CTFlows#358): one column per point, linear dynamics valid for a
# vector or a matrix state.
const A_BATCH = [0.0 1.0; -1.0 0.0]
const B_BATCH = [0.0, 1.0]
dyn_batch!(r, t, x, u, v) = (r.=A_BATCH * x .+ B_BATCH .* u; nothing)
dyn_batch_cf!(r, t, x, u, v) = (r.=A_BATCH * x; nothing)
mayer_zero(x0, xf, v) = 0.0

# A control law with two methods: its arity cannot be checked.
law_two_methods(x, p) = p
law_two_methods(t, x, p) = p

# ==============================================================================
# Model builders (module top-level)
# ==============================================================================

function build_ocp(;
    n=1,
    m=1,
    q=0,
    autonomous=true,
    criterion=:min,
    dynamics=dyn_1d!,
    lagrange=lag_1d,
    mayer=nothing,
)
    pre = Building.PreModel()
    q > 0 && Building.variable!(pre, q)
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, n)
    m > 0 && Building.control!(pre, m)
    Building.dynamics!(pre, dynamics)
    if lagrange === nothing
        Building.objective!(pre, criterion; mayer=mayer)
    elseif mayer === nothing
        Building.objective!(pre, criterion; lagrange=lagrange)
    else
        Building.objective!(pre, criterion; mayer=mayer, lagrange=lagrange)
    end
    Building.time_dependence!(pre; autonomous=autonomous)
    Building.definition!(pre, quote end)
    return Building.build(pre)
end

ocp_1d(; kwargs...) = build_ocp(; kwargs...)
function ocp_2d(; autonomous=false, q=1, kwargs...)
    return build_ocp(;
        n=2,
        q=q,
        autonomous=autonomous,
        dynamics=dyn_2d!,
        lagrange=lag_2d,
        mayer=mayer_2d,
        kwargs...,
    )
end
ocp_cf(; kwargs...) = build_ocp(; n=2, m=0, dynamics=dyn_cf!, lagrange=lag_cf, kwargs...)

# Closed forms, written independently of the getters.
H̃_1d(x, p, u; p0=-1) = p * u + p0 * x^2
H̃_2d(t, x, p, u, v; p0=-1) = p[1] * x[2] + p[2] * (t * u + v) + p0 * (u^2 + t)
H_cf(x, p; p0=-1) = p[1] * x[2] - p[2] * x[1] + p0 * x[1]^2

# ==============================================================================
# Constrained models (module top-level)
# ==============================================================================

const LB = 0.1

# The order-one example of the OptimalControl docs, x ≥ lb written as a path constraint
# (:x_con) and as a state box (:x_box): ẋ = u, ∫ x² → min, |u| ≤ 1 (:u_box).
x_con!(r, t, x, u, v) = (r[1]=x - LB; nothing)

function ocp_bd(; as_box=false, criterion=:min)
    pre = Building.PreModel()
    Building.time!(pre; t0=0.0, tf=2.0)
    Building.state!(pre, 1)
    Building.control!(pre, 1)
    Building.dynamics!(pre, dyn_1d!)
    Building.objective!(
        pre, criterion; lagrange=criterion === :min ? lag_1d : (t, x, u, v) -> -x^2
    )
    if as_box
        Building.constraint!(pre, :state; rg=1:1, lb=[LB], ub=[Inf], label=:x_box)
    else
        Building.constraint!(pre, :path; f=x_con!, lb=[0.0], ub=[Inf], label=:x_con)
    end
    Building.constraint!(pre, :control; rg=1:1, lb=[-1.0], ub=[1.0], label=:u_box)
    Building.time_dependence!(pre; autonomous=true)
    Building.definition!(pre, quote end)
    return Building.build(pre)
end

# Every kind of constraint: 2-D state, 1-D control, 1-D variable.
mixed!(r, t, x, u, v) = (r[1]=x[1] + u; nothing)                  # −1 ≤ x₁ + u ≤ 1
pv!(r, t, x, u, v) = (r[1]=x[1]^2; r[2]=x[2]; nothing)          # x₁² ≤ 4, x₂ = 0
dyn_c!(r, t, x, u, v) = (r[1]=x[2]; r[2]=u; nothing)
lag_c(t, x, u, v) = u^2
bc!(r, x0, xf, v) = (r[1]=x0[1]; nothing)

function ocp_all(; autonomous=true, path=mixed!)
    pre = Building.PreModel()
    Building.variable!(pre, 1)
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 2)
    Building.control!(pre, 1)
    Building.dynamics!(pre, dyn_c!)
    Building.objective!(pre, :min; lagrange=lag_c)
    Building.constraint!(pre, :path; f=path, lb=[-1.0], ub=[1.0], label=:mixed)
    Building.constraint!(pre, :path; f=pv!, lb=[-Inf, 0.0], ub=[4.0, 0.0], label=:pv)
    Building.constraint!(pre, :state; rg=2:2, lb=[-Inf], ub=[1.2], label=:vmax)
    Building.constraint!(pre, :control; rg=1:1, lb=[-1.0], ub=[1.0], label=:ubox)
    Building.constraint!(pre, :boundary; f=bc!, lb=[0.0], ub=[0.0], label=:bc)
    Building.constraint!(pre, :variable; rg=1:1, lb=[0.0], ub=[10.0], label=:vbox)
    Building.time_dependence!(pre; autonomous=autonomous)
    Building.definition!(pre, quote end)
    return Building.build(pre)
end

# Closed forms of the terms, in the sign convention of the duals.
term_mixed(x, u, y) = -y * (x[1] + u - (y > 0 ? 1.0 : -1.0))
term_pv(x, y) = y[1] * (4.0 - x[1]^2) - y[2] * x[2]
term_vmax(x, y) = y * (1.2 - x[2])
term_ubox(u, y) = -y * (u - (y > 0 ? 1.0 : -1.0))

# One state component bounded under two labels (`:a` and `:b`, intersected to
# `0 ≤ x₁ ≤ 1`), and another component under `:c`.
function ocp_alias()
    pre = Building.PreModel()
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 2)
    Building.control!(pre, 1)
    Building.dynamics!(pre, dyn_c!)
    Building.objective!(pre, :min; lagrange=lag_c)
    Building.constraint!(pre, :state; rg=1:1, lb=[0.0], ub=[Inf], label=:a)
    Building.constraint!(pre, :state; rg=1:1, lb=[-Inf], ub=[1.0], label=:b)
    Building.constraint!(pre, :state; rg=2:2, lb=[-Inf], ub=[2.0], label=:c)
    Building.time_dependence!(pre; autonomous=true)
    Building.definition!(pre, quote end)
    return Test.@test_logs (:warn, r"Multiple bound declarations") Building.build(pre)
end

# Batched constrained problem: every function is written on the columns, so that it is
# valid for a vector or a matrix state (one column per point), like dyn_batch!.
lag_batch(t, x, u, v) = 0.5 * sum(abs2, u)                     # Σ over the points
pc_batch!(r, t, x, u, v) = (r[1:1, :].=x[1:1, :] .+ u; nothing)  # −1 ≤ x₁ + u ≤ 1
pc2_batch!(r, t, x, u, v) = (r[1:1, :].=x[2:2, :] .^ 2; nothing) # x₂² ≤ 4

function ocp_batch(; two_paths=true)
    pre = Building.PreModel()
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 2)
    Building.control!(pre, 1)
    Building.dynamics!(pre, dyn_batch!)
    Building.objective!(pre, :min; lagrange=lag_batch)
    Building.constraint!(pre, :path; f=pc_batch!, lb=[-1.0], ub=[1.0], label=:pc)
    two_paths &&
        Building.constraint!(pre, :path; f=pc2_batch!, lb=[-Inf], ub=[4.0], label=:pc2)
    Building.constraint!(pre, :state; rg=2:2, lb=[-Inf], ub=[1.2], label=:vmax)
    Building.constraint!(pre, :control; rg=1:1, lb=[-1.0], ub=[1.0], label=:ubox)
    Building.time_dependence!(pre; autonomous=true)
    Building.definition!(pre, quote end)
    return Building.build(pre)
end

const X_BATCH = [1.0 2.0 -1.0; 0.5 -0.3 2.0]
const P_BATCH = [0.3 -1.0 0.7; 1.2 0.4 -0.6]
const U_BATCH = [0.2 -0.4 0.5]
const M_BATCH = [0.5 -0.2 1.0; 0.3 0.7 0.1; 2.0 1.0 0.4; -1.0 0.5 0.3]

# Multipliers in feedback form, on the columns (batched) and on one point.
μ_pc_batch(x, p) = x[1:1, :]
μ_pc2_batch(x, p) = p[2:2, :]
μ_vmax_batch(x, p) = p[1:1, :]
law_batch(x, p) = p[2:2, :]
μ_pc_point(x, p) = x[1]
μ_pc2_point(x, p) = p[2]
μ_vmax_point(x, p) = p[1]
law_point(x, p) = p[2]

# A path constraint recording what it receives.
mutable struct SpyConstraint <: Function
    args::Any
    calls::Int
end
SpyConstraint() = SpyConstraint(nothing, 0)
function (s::SpyConstraint)(r, t, x, u, v)
    s.args = (t, x, u, v)
    s.calls += 1
    r[1] = 0.0
    return nothing
end

# A multiplier recording what it receives.
mutable struct SpyMultiplier <: Function
    args::Any
    calls::Int
end
SpyMultiplier() = SpyMultiplier(nothing, 0)
function (s::SpyMultiplier)(args...)
    s.args = args
    s.calls += 1
    return 0.5
end

function test_hamiltonians()
    Test.@testset "Hamiltonians of a model" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ======================================================================
        # UNIT — pseudo_hamiltonian: type, traits, natural and uniform calls
        # ======================================================================

        Test.@testset "Unit: pseudo_hamiltonian has the traits of the model" begin
            for (aut, q, TD, VD) in (
                (true, 0, Traits.Autonomous, Traits.Fixed),
                (false, 0, Traits.NonAutonomous, Traits.Fixed),
                (true, 1, Traits.Autonomous, Traits.NonFixed),
                (false, 1, Traits.NonAutonomous, Traits.NonFixed),
            )
                H̃ = Models.pseudo_hamiltonian(ocp_2d(; autonomous=aut, q=q))
                Test.@test H̃ isa Data.PseudoHamiltonian
                Test.@test Traits.time_dependence(H̃) === TD
                Test.@test Traits.variable_dependence(H̃) === VD
            end
        end

        Test.@testset "Unit: pseudo_hamiltonian, 1-D (Autonomous, Fixed), scalars" begin
            H̃ = Models.pseudo_hamiltonian(ocp_1d())
            Test.@test H̃(1.5, 2.0, 0.5) ≈ H̃_1d(1.5, 2.0, 0.5)
            Test.@test H̃(9.0, 1.5, 2.0, 0.5, nothing) ≈ H̃_1d(1.5, 2.0, 0.5)   # uniform
        end

        Test.@testset "Unit: pseudo_hamiltonian, 2-D, the four arities" begin
            x, p, u, t, v = [1.0, 2.0], [3.0, 4.0], 0.5, 2.0, 0.7
            H = Models.pseudo_hamiltonian(ocp_2d(; autonomous=false, q=1))
            Test.@test H(t, x, p, u, v) ≈ H̃_2d(t, x, p, u, v)
            H = Models.pseudo_hamiltonian(ocp_2d(; autonomous=true, q=1))
            Test.@test H(x, p, u, v) ≈ H̃_2d(0.0, x, p, u, v)                 # t = 0
            Test.@test H(t, x, p, u, v) ≈ H̃_2d(0.0, x, p, u, v)              # t ignored
            H = Models.pseudo_hamiltonian(ocp_2d(; autonomous=false, q=0))
            Test.@test H(t, x, p, u) ≈ H̃_2d(t, x, p, u, 0.0)
            H = Models.pseudo_hamiltonian(ocp_2d(; autonomous=true, q=0))
            Test.@test H(x, p, u) ≈ H̃_2d(0.0, x, p, u, 0.0)
        end

        Test.@testset "Unit: pseudo_hamiltonian, Mayer problem has no cost term" begin
            ocp = build_ocp(; lagrange=nothing, mayer=(x0, xf, v) -> xf^2)
            H̃ = Models.pseudo_hamiltonian(ocp)
            Test.@test H̃(1.5, 2.0, 0.5) ≈ 2.0 * 0.5
            Test.@test Models.pseudo_hamiltonian(ocp; p0=0)(1.5, 2.0, 0.5) ≈ 2.0 * 0.5
        end

        Test.@testset "Unit: pseudo_hamiltonian, Bolza problem keeps only the Lagrange cost" begin
            H̃ = Models.pseudo_hamiltonian(ocp_2d(; autonomous=true, q=0))
            x, p, u = [1.0, 2.0], [3.0, 4.0], 0.5
            Test.@test H̃(x, p, u) ≈ p[1] * x[2] + p[2] * 0.0 * u - u^2   # t = 0, v = 0
        end

        # ======================================================================
        # UNIT — p0 (ct-conventions SGN4)
        # ======================================================================

        Test.@testset "Unit: p0 defaults to -1 for :min and +1 for :max" begin
            Test.@test Models.pseudo_hamiltonian(ocp_1d())(1.5, 2.0, 0.5) ≈
                H̃_1d(1.5, 2.0, 0.5; p0=-1)
            Test.@test Models.pseudo_hamiltonian(ocp_1d(; criterion=:max))(1.5, 2.0, 0.5) ≈
                H̃_1d(1.5, 2.0, 0.5; p0=1)
        end

        Test.@testset "Unit: p0 = 0 (abnormal) and a scaled p0" begin
            ocp = ocp_1d()
            Test.@test Models.pseudo_hamiltonian(ocp; p0=0)(1.5, 2.0, 0.5) ≈ 2.0 * 0.5
            Test.@test Models.pseudo_hamiltonian(ocp; p0=-2)(1.5, 2.0, 0.5) ≈
                H̃_1d(1.5, 2.0, 0.5; p0=-2)
            Test.@test Models.pseudo_hamiltonian(ocp_1d(; criterion=:max); p0=0)(
                1.5, 2.0, 0.5
            ) ≈ 2.0 * 0.5
            Test.@test Models.pseudo_hamiltonian(ocp; p0=-1//2)(1.5, 2.0, 0.5) ≈   # any Real
                H̃_1d(1.5, 2.0, 0.5; p0=-0.5)
        end

        Test.@testset "Unit: min ∫ℓ and max ∫(−ℓ) have the same pseudo-Hamiltonian (SGN4)" begin
            ocp_min = ocp_1d()
            ocp_max = build_ocp(; criterion=:max, lagrange=(t, x, u, v) -> -x^2)
            for (x, p, u) in ((1.5, 2.0, 0.5), (-0.3, 0.1, -2.0))
                Test.@test Models.pseudo_hamiltonian(ocp_min)(x, p, u) ≈
                    Models.pseudo_hamiltonian(ocp_max)(x, p, u)
            end
        end

        # ======================================================================
        # UNIT — hamiltonian of a control-free problem
        # ======================================================================

        Test.@testset "Unit: hamiltonian(ocp) of a control-free problem" begin
            H = Models.hamiltonian(ocp_cf())
            x, p = [1.0, 2.0], [3.0, 4.0]
            Test.@test H isa Data.Hamiltonian
            Test.@test Traits.time_dependence(H) === Traits.Autonomous
            Test.@test Traits.variable_dependence(H) === Traits.Fixed
            Test.@test H(x, p) ≈ H_cf(x, p)
            Test.@test H(0.0, x, p, nothing) ≈ H_cf(x, p)
            Test.@test Models.hamiltonian(ocp_cf(); p0=0)(x, p) ≈ H_cf(x, p; p0=0)
            Test.@test Models.hamiltonian(ocp_cf(; criterion=:max))(x, p) ≈ H_cf(x, p; p0=1)
        end

        Test.@testset "Unit: hamiltonian(ocp) of a control-free problem, the four arities" begin
            x, p, t, v = 1.0, 2.0, 3.0, 0.5
            for (aut, q, call) in (
                (true, 0, H -> H(x, p)),
                (false, 0, H -> H(t, x, p)),
                (true, 1, H -> H(x, p, v)),
                (false, 1, H -> H(t, x, p, v)),
            )
                ocp = build_ocp(;
                    m=0, q=q, autonomous=aut, dynamics=dyn_tv!, lagrange=lag_tv
                )
                tt = aut ? 0.0 : t
                vv = q == 0 ? 0.0 : v      # an empty variable sums to 0 in t + v
                Test.@test call(Models.hamiltonian(ocp)) ≈ p * (tt + vv) - x
            end
        end

        # ======================================================================
        # UNIT — hamiltonian(ocp, u)
        # ======================================================================

        Test.@testset "Unit: hamiltonian(ocp, u) with a raw control law" begin
            H = Models.hamiltonian(ocp_1d(), (x, p) -> p)
            Test.@test H isa Data.ComposedHamiltonian
            Test.@test H(1.5, 2.0) ≈ H̃_1d(1.5, 2.0, 2.0)
            Test.@test H(0.0, 1.5, 2.0, nothing) ≈ H̃_1d(1.5, 2.0, 2.0)
            Test.@test Data.pseudo_hamiltonian(H)(1.5, 2.0, 0.5) ≈ H̃_1d(1.5, 2.0, 0.5)
        end

        Test.@testset "Unit: hamiltonian(ocp, u), raw law with the arity of each model" begin
            x, p, t, v = [1.0, 2.0], [3.0, 4.0], 2.0, 0.7
            u = 0.5
            cases = (
                (true, 0, (x, p) -> u, H -> H(x, p), 0.0, 0.0),
                (false, 0, (t, x, p) -> u, H -> H(t, x, p), t, 0.0),
                (true, 1, (x, p, v) -> u, H -> H(x, p, v), 0.0, v),
                (false, 1, (t, x, p, v) -> u, H -> H(t, x, p, v), t, v),
            )
            for (aut, q, law, call, tt, vv) in cases
                H = Models.hamiltonian(ocp_2d(; autonomous=aut, q=q), law)
                Test.@test call(H) ≈ H̃_2d(tt, x, p, u, vv)
            end
        end

        Test.@testset "Unit: hamiltonian(ocp, law) with a DynClosedLoop law, traits joined" begin
            # a time-varying feedback on an autonomous problem gives a non-autonomous H
            law = Data.DynClosedLoop((t, x, p) -> t * p; is_autonomous=false)
            H = Models.hamiltonian(ocp_1d(), law)
            Test.@test Traits.time_dependence(H) === Traits.NonAutonomous
            Test.@test H(2.0, 1.5, 3.0) ≈ H̃_1d(1.5, 3.0, 6.0)
        end

        Test.@testset "Unit: a raw law with several methods is not arity-checked" begin
            H = Models.hamiltonian(ocp_1d(), law_two_methods)
            Test.@test H(1.5, 2.0) ≈ H̃_1d(1.5, 2.0, 2.0)
        end

        Test.@testset "Unit: a variadic raw law is not arity-checked" begin
            H = Models.hamiltonian(ocp_1d(), (args...) -> last(args))
            Test.@test H(1.5, 2.0) ≈ H̃_1d(1.5, 2.0, 2.0)
        end

        Test.@testset "Unit: hamiltonian(ocp, u; p0)" begin
            Test.@test Models.hamiltonian(ocp_1d(), (x, p) -> p; p0=0)(1.5, 2.0) ≈ 4.0
        end

        # ======================================================================
        # UNIT — what the model functions receive (spies)
        # ======================================================================

        Test.@testset "Unit: autonomous fixed problem: t = 0, empty variable, scalars stay scalars" begin
            spy_f, spy_ℓ = SpyDynamics(), SpyLagrange()
            H̃ = Models.pseudo_hamiltonian(build_ocp(; dynamics=spy_f, lagrange=spy_ℓ))
            val = H̃(1.5, 2.0, 0.5)
            Test.@test spy_f.calls == 1 && spy_ℓ.calls == 1
            t, x, u, v = spy_f.args
            Test.@test t == 0.0
            Test.@test x === 1.5 && u === 0.5
            Test.@test v isa AbstractVector && isempty(v)
            Test.@test spy_ℓ.args == spy_f.args
            Test.@test val ≈ -7.0                        # zero buffer: only p0·ℓ remains
        end

        Test.@testset "Unit: non-autonomous problem with variable: t and v forwarded" begin
            spy_f, spy_ℓ = SpyDynamics(), SpyLagrange()
            ocp = build_ocp(; n=2, q=2, autonomous=false, dynamics=spy_f, lagrange=spy_ℓ)
            x, p, u, v = [1.0, 2.0], [3.0, 4.0], 0.5, [0.1, 0.2]
            Models.pseudo_hamiltonian(ocp)(2.0, x, p, u, v)
            Test.@test spy_f.args == (2.0, x, u, v)
            Test.@test spy_f.args[4] === v
            Test.@test spy_ℓ.args == spy_f.args
        end

        Test.@testset "Unit: the derivative buffer is built like the state" begin
            spy_f = SpyDynamics()
            ocp = build_ocp(;
                n=2, dynamics=spy_f, lagrange=nothing, mayer=(x0, xf, v) -> 0.0
            )
            Models.pseudo_hamiltonian(ocp)(Float32[1, 2], Float32[3, 4], 0.5f0)
            Test.@test spy_f.buffer_type == Vector{Float32}
            Models.pseudo_hamiltonian(build_ocp(; dynamics=spy_f))(1.5, 2.0, 0.5)
            Test.@test spy_f.buffer_type == Vector{Float64}        # 1-D: a host Vector
        end

        Test.@testset "Unit: a batched (Matrix) state gets an n × batch buffer" begin
            spy_f = SpyDynamics()
            ocp = build_ocp(; n=2, dynamics=spy_f, lagrange=nothing, mayer=mayer_zero)
            Models.pseudo_hamiltonian(ocp)(ones(2, 3), ones(2, 3), ones(1, 3))
            Test.@test spy_f.buffer_type == Matrix{Float64}
            Test.@test size(spy_f.args[2]) == (2, 3)
        end

        Test.@testset "Unit: batched (Matrix) state, the value sums the columns" begin
            X = [1.0 2.0 -1.0; 0.5 -0.3 2.0]
            P = [0.3 -1.0 0.7; 1.2 0.4 -0.6]
            U = [0.2 -0.4 1.5]
            H̃ = Models.pseudo_hamiltonian(
                build_ocp(; n=2, dynamics=dyn_batch!, lagrange=nothing, mayer=mayer_zero)
            )
            Test.@test H̃(X, P, U) ≈ sum(H̃(X[:, j], P[:, j], U[1, j]) for j in 1:3)
            ocp_cf_batch = build_ocp(;
                n=2, m=0, dynamics=dyn_batch_cf!, lagrange=nothing, mayer=mayer_zero
            )
            H = Models.hamiltonian(ocp_cf_batch)
            Test.@test H(X, P) ≈ sum(H(X[:, j], P[:, j]) for j in 1:3)
        end

        Test.@testset "Unit: batched (Matrix) state, the gradient is taken column by column" begin
            X = [1.0 2.0; 0.5 -0.3]
            P = [0.3 -1.0; 1.2 0.4]
            U = [0.2 -0.4]
            H̃ = Models.pseudo_hamiltonian(
                build_ocp(; n=2, dynamics=dyn_batch!, lagrange=nothing, mayer=mayer_zero)
            )
            ∇X = ForwardDiff.gradient(Y -> H̃(Y, P, U), X)
            Test.@test size(∇X) == size(X)
            for j in 1:2
                ∇x = ForwardDiff.gradient(y -> H̃(y, P[:, j], U[1, j]), X[:, j])
                Test.@test ∇X[:, j] ≈ ∇x
            end
        end

        Test.@testset "Unit: control-free problem: the model functions get an empty control" begin
            spy_f, spy_ℓ = SpyDynamics(), SpyLagrange()
            H = Models.hamiltonian(build_ocp(; n=2, m=0, dynamics=spy_f, lagrange=spy_ℓ))
            H([1.0, 2.0], [3.0, 4.0])
            t, x, u, v = spy_f.args
            Test.@test t == 0.0 && x == [1.0, 2.0]
            Test.@test u isa AbstractVector && isempty(u)
            Test.@test v isa AbstractVector && isempty(v)
        end

        # ======================================================================
        # UNIT — automatic differentiation through the getters
        # ======================================================================

        Test.@testset "Unit: ForwardDiff through the pseudo-Hamiltonian" begin
            H̃ = Models.pseudo_hamiltonian(ocp_2d(; autonomous=false, q=1))
            t, x, p, u, v = 2.0, [1.0, 2.0], [3.0, 4.0], 0.5, 0.7
            Test.@test ForwardDiff.gradient(x_ -> H̃(t, x_, p, u, v), x) ≈ [0.0, p[1]]
            Test.@test ForwardDiff.gradient(p_ -> H̃(t, x, p_, u, v), p) ≈ [x[2], t * u + v]
            Test.@test ForwardDiff.derivative(u_ -> H̃(t, x, p, u_, v), u) ≈ p[2] * t - 2u
            Test.@test ForwardDiff.derivative(v_ -> H̃(t, x, p, u, v_), v) ≈ p[2]
        end

        Test.@testset "Unit: ForwardDiff, 1-D scalars and the total derivative of H(ocp, u)" begin
            H̃ = Models.pseudo_hamiltonian(ocp_1d())
            Test.@test ForwardDiff.derivative(x_ -> H̃(x_, 2.0, 0.5), 1.5) ≈ -3.0
            H = Models.hamiltonian(ocp_1d(), (x, p) -> p)       # H = p² − x²
            Test.@test ForwardDiff.derivative(p_ -> H(1.5, p_), 2.0) ≈ 4.0   # total: 2p
            Test.@test ForwardDiff.derivative(p_ -> H̃(1.5, p_, 2.0), 2.0) ≈ 2.0  # partial: u
        end

        # ======================================================================
        # UNIT — type stability
        # ======================================================================

        Test.@testset "Unit: ForwardDiff in t of a non-autonomous problem" begin
            # the buffer of the dynamics takes the type of t: a Dual in t is not written
            # into a Float64 buffer
            H̃ = Models.pseudo_hamiltonian(ocp_2d())
            x, p, u, v = [1.0, 2.0], [0.5, -1.5], 0.3, 2.0
            Test.@test ForwardDiff.derivative(t -> H̃(t, x, p, u, v), 0.7) ≈ p[2] * u - 1
            Hc = Models.pseudo_hamiltonian(
                ocp_all(; autonomous=false); constraints=(:mixed, :vmax)
            )
            dHc = ForwardDiff.derivative(t -> Hc(t, x, p, u, [0.4, 0.2], v), 0.7)
            Test.@test dHc ≈ 0.0 atol = 1e-12   # nothing depends on t in ocp_all
        end

        Test.@testset "Unit: calls are type-stable" begin
            H̃1 = Models.pseudo_hamiltonian(ocp_1d())
            Test.@test (Test.@inferred H̃1(1.5, 2.0, 0.5)) isa Float64
            H̃2 = Models.pseudo_hamiltonian(ocp_2d(; autonomous=false, q=1))
            Test.@test (Test.@inferred H̃2(2.0, [1.0, 2.0], [3.0, 4.0], 0.5, 0.7)) isa
                Float64
            H = Models.hamiltonian(ocp_cf())
            Test.@test (Test.@inferred H([1.0, 2.0], [3.0, 4.0])) isa Float64
            Hu = Models.hamiltonian(ocp_1d(), (x, p) -> p)
            Test.@test (Test.@inferred Hu(1.5, 2.0)) isa Float64
        end

        # ======================================================================
        # NON-REGRESSION — fixed values
        # ======================================================================

        Test.@testset "Non-regression: golden values" begin
            # computed by hand from the closed forms above
            Test.@test Models.pseudo_hamiltonian(ocp_1d())(1.5, 2.0, 0.5) == -1.25
            Test.@test Models.pseudo_hamiltonian(ocp_2d(; autonomous=false, q=1))(
                2.0, [1.0, 2.0], [3.0, 4.0], 0.5, 0.7
            ) ≈ 6.0 + 4.0 * 1.7 - 2.25
            Test.@test Models.hamiltonian(ocp_cf())([1.0, 2.0], [3.0, 4.0]) == 1.0
            Test.@test Models.hamiltonian(ocp_1d(), (x, p) -> p)(1.5, 2.0) == 1.75
        end

        # ======================================================================
        # INTEGRATION — a full model (Beam: boundary, state box, control box)
        # ======================================================================

        Test.@testset "Integration: Beam, pseudo-Hamiltonian = p·f + p0·ℓ" begin
            ocp = TestProblems.Beam().ocp
            H̃ = Models.pseudo_hamiltonian(ocp)
            f! = Models.dynamics(ocp)
            for (x, p, u) in
                (([0.05, 0.1], [1.0, -2.0], 0.3), ([0.0, 1.0], [0.5, 0.5], -4.0))
                r = zeros(2)
                f!(r, 0.0, x, [u], Float64[])
                ℓ = CTModels.Components.lagrange(ocp)(0.0, x, [u], Float64[])
                Test.@test H̃(x, p, [u]) ≈ sum(p .* r) - ℓ
                Test.@test Models.hamiltonian(ocp, (x, p) -> [p[2] / 2])(x, p) ≈
                    H̃(x, p, [p[2] / 2])
            end
        end

        # ======================================================================
        # UNIT — constraints by label (pseudo_hamiltonian(ocp; constraints))
        # ======================================================================

        Test.@testset "Unit: constrained pseudo-Hamiltonian type, traits and calls" begin
            ocp = ocp_all()
            H = Models.pseudo_hamiltonian(ocp; constraints=:vmax)
            Test.@test H isa Data.ConstrainedPseudoHamiltonian
            Test.@test Traits.time_dependence(H) === Traits.Autonomous
            Test.@test Traits.variable_dependence(H) === Traits.NonFixed
            x, p, u, v = [0.5, 1.5], [1.0, 2.0], 0.3, 2.0
            base = Models.pseudo_hamiltonian(ocp)(x, p, u, v)
            Test.@test H(x, p, u, 0.7, v) ≈ base + term_vmax(x, 0.7)
            Test.@test H(9.0, x, p, u, 0.7, v) ≈ base + term_vmax(x, 0.7)   # uniform
            Hn = Models.pseudo_hamiltonian(ocp_all(; autonomous=false); constraints=:vmax)
            Test.@test Traits.time_dependence(Hn) === Traits.NonAutonomous
            Test.@test Hn(1.0, x, p, u, 0.7, v) ≈ base + term_vmax(x, 0.7)
        end

        Test.@testset "Unit: the term of each kind of constraint (dual convention)" begin
            ocp = ocp_all()
            x, p, u, v = [0.5, 1.5], [1.0, 2.0], 0.3, 2.0
            base = Models.pseudo_hamiltonian(ocp)(x, p, u, v)
            H(label) = Models.pseudo_hamiltonian(ocp; constraints=label)
            # upper bound only (state box): y (ub − c)
            Test.@test H(:vmax)(x, p, u, 0.7, v) - base ≈ 0.7 * (1.2 - 1.5)
            # two bounds, upper side active (y > 0): −y (c − ub) = y (ub − c)
            Test.@test H(:mixed)(x, p, u, 0.4, v) - base ≈ 0.4 * (1.0 - (x[1] + u))
            # two bounds, lower side active (y < 0): −y (c − lb) = |y| (c − lb)
            Test.@test H(:mixed)(x, p, u, -0.4, v) - base ≈ 0.4 * (x[1] + u + 1.0)
            # control box, both sides
            Test.@test H(:ubox)(x, p, u, 0.5, v) - base ≈ 0.5 * (1.0 - u)
            Test.@test H(:ubox)(x, p, u, -0.5, v) - base ≈ 0.5 * (u + 1.0)
            # a vector label: upper bound only, then an equality, with both signs
            Test.@test H(:pv)(x, p, u, [0.2, 0.9], v) - base ≈ term_pv(x, [0.2, 0.9])
            Test.@test H(:pv)(x, p, u, [0.2, -0.9], v) - base ≈ term_pv(x, [0.2, -0.9])
        end

        Test.@testset "Unit: lower bound only, path and state box (SGN5: same term)" begin
            x, p, u, y = 0.7, 2.0, 0.3, 1.4
            Hc = Models.pseudo_hamiltonian(ocp_bd(); constraints=:x_con)
            Hb = Models.pseudo_hamiltonian(ocp_bd(; as_box=true); constraints=:x_box)
            Test.@test Hc(x, p, u, y) ≈ H̃_1d(x, p, u) + y * (x - LB)
            Test.@test Hb(x, p, u, y) ≈ Hc(x, p, u, y)
        end

        Test.@testset "Unit: the term is continuous at y = 0 and vanishes there" begin
            ocp = ocp_all()
            x, p, u, v = [0.5, 1.5], [1.0, 2.0], 0.3, 2.0
            base = Models.pseudo_hamiltonian(ocp)(x, p, u, v)
            H = Models.pseudo_hamiltonian(ocp; constraints=:mixed)
            Test.@test H(x, p, u, 0.0, v) == base
            Test.@test abs(H(x, p, u, 1e-12, v) - H(x, p, u, -1e-12, v)) < 1e-10
        end

        Test.@testset "Unit: several labels, μ stacked in the order given" begin
            ocp = ocp_all()
            x, p, u, v = [0.5, 1.5], [1.0, 2.0], 0.3, 2.0
            base = Models.pseudo_hamiltonian(ocp)(x, p, u, v)
            H1 = Models.pseudo_hamiltonian(ocp; constraints=(:vmax, :mixed, :pv, :ubox))
            μ1 = [0.7, -0.4, 0.2, 0.9, 0.5]
            expected =
                base +
                term_vmax(x, 0.7) +
                term_mixed(x, u, -0.4) +
                term_pv(x, [0.2, 0.9]) +
                term_ubox(u, 0.5)
            Test.@test H1(x, p, u, μ1, v) ≈ expected
            H2 = Models.pseudo_hamiltonian(ocp; constraints=[:pv, :ubox, :vmax, :mixed])
            Test.@test H2(x, p, u, [0.2, 0.9, 0.5, 0.7, -0.4], v) ≈ expected
        end

        Test.@testset "Unit: a zero multiplier gives the unconstrained pseudo-Hamiltonian" begin
            ocp = ocp_all()
            x, p, u, v = [0.5, 1.5], [1.0, 2.0], 0.3, 2.0
            H = Models.pseudo_hamiltonian(ocp; constraints=(:vmax, :pv))
            Test.@test H(x, p, u, zeros(3), v) == Models.pseudo_hamiltonian(ocp)(x, p, u, v)
        end

        Test.@testset "Unit: freeze_multiplier on the constrained pseudo-Hamiltonian" begin
            H = Models.pseudo_hamiltonian(ocp_bd(); constraints=:x_con)
            H̃ = Data.freeze_multiplier(H, 1.4)
            Test.@test H̃ isa Data.PseudoHamiltonian
            Test.@test H̃(0.7, 2.0, 0.3) == H(0.7, 2.0, 0.3, 1.4)
        end

        Test.@testset "Unit: constrained pseudo-Hamiltonian with p0" begin
            H0 = Models.pseudo_hamiltonian(ocp_bd(); constraints=:x_con, p0=0)
            Test.@test H0(0.7, 2.0, 0.3, 1.4) ≈ 2.0 * 0.3 + 1.4 * (0.7 - LB)
            Hmax = Models.pseudo_hamiltonian(ocp_bd(; criterion=:max); constraints=:x_con)
            Test.@test Hmax(0.7, 2.0, 0.3, 1.4) ≈
                Models.pseudo_hamiltonian(ocp_bd(); constraints=:x_con)(
                0.7, 2.0, 0.3, 1.4
            )
        end

        # ======================================================================
        # UNIT — constraints in feedback form (hamiltonian(ocp, u; multipliers))
        # ======================================================================

        Test.@testset "Unit: hamiltonian(ocp, u; multipliers), the boundary arc of the docs" begin
            h = Models.hamiltonian(
                ocp_bd(), (x, p) -> 0.0; multipliers=(:x_con => (x, p) -> 2x)
            )
            Test.@test h isa Data.ComposedConstrainedHamiltonian
            Test.@test h(1.0, 2.0) ≈ -1.0 + 2.0 * (1.0 - LB)
            Test.@test h(0.0, 1.0, 2.0, nothing) ≈ h(1.0, 2.0)
            Test.@test h(LB, 0.0) ≈ -LB^2                   # on the arc, g = 0
        end

        Test.@testset "Unit: every form of the multipliers argument gives the same h" begin
            ocp = ocp_all()
            x, p, v = [0.5, 1.5], [1.0, 2.0], 2.0
            law = (x, p, v) -> 0.3
            μv = (x, p, v) -> 0.7
            μp = (x, p, v) -> [0.2, 0.9]
            ref = Models.hamiltonian(ocp, law; multipliers=(:vmax => μv, :pv => μp))(
                x, p, v
            )
            expected =
                Models.pseudo_hamiltonian(ocp)(x, p, 0.3, v) +
                term_vmax(x, 0.7) +
                term_pv(x, [0.2, 0.9])
            Test.@test ref ≈ expected
            for spec in (
                (vmax=μv, pv=μp),
                Dict(:vmax => μv, :pv => μp),
                [:pv => μp, :vmax => μv],
                (:vmax => Data.Multiplier(μv; is_variable=true), :pv => μp),
            )
                Test.@test Models.hamiltonian(ocp, law; multipliers=spec)(x, p, v) ≈ ref
            end
            Test.@test Models.hamiltonian(ocp, law; multipliers=:vmax => μv)(x, p, v) ≈
                Models.pseudo_hamiltonian(ocp)(x, p, 0.3, v) + term_vmax(x, 0.7)
        end

        Test.@testset "Unit: hamiltonian(ocp, u; multipliers) without multipliers is unconstrained" begin
            ocp = ocp_bd()
            Test.@test Models.hamiltonian(ocp, (x, p) -> p; multipliers=()) isa
                Data.ComposedHamiltonian
        end

        Test.@testset "Unit: traits joined with a time-varying multiplier" begin
            μ = Data.Multiplier((t, x, p) -> 2x + t; is_autonomous=false)
            h = Models.hamiltonian(ocp_bd(), (x, p) -> 0.0; multipliers=(:x_con => μ,))
            Test.@test Traits.time_dependence(h) === Traits.NonAutonomous
            Test.@test h(1.0, 0.5, 2.0) ≈ -0.25 + (1.0 + 1.0) * (0.5 - LB)
        end

        Test.@testset "Unit: control box on a saturated arc is inert (KKT)" begin
            # on u = 1 = ub, the term μ·(ub − u) vanishes, as do its derivatives in x, p
            ocp = ocp_bd()
            h = Models.hamiltonian(ocp, (x, p) -> 1.0; multipliers=(:u_box => (x, p) -> p))
            h0 = Models.hamiltonian(ocp, (x, p) -> 1.0)
            for (x, p) in ((0.5, 2.0), (-1.0, 0.3))
                Test.@test h(x, p) ≈ h0(x, p)
                Test.@test ForwardDiff.derivative(x_ -> h(x_, p), x) ≈
                    ForwardDiff.derivative(x_ -> h0(x_, p), x)
                Test.@test ForwardDiff.derivative(p_ -> h(x, p_), p) ≈
                    ForwardDiff.derivative(p_ -> h0(x, p_), p)
                # the multiplier is the one of the stationarity: ∂H̃/∂u = p = μ
                H̃ = Models.pseudo_hamiltonian(ocp)
                Test.@test ForwardDiff.derivative(u_ -> H̃(x, p, u_), 1.0) ≈ p
            end
        end

        # ======================================================================
        # UNIT — what the constraint and the multiplier receive (spies)
        # ======================================================================

        Test.@testset "Unit: the constraint gets (t, x, u, v), v empty without variable" begin
            spy = SpyConstraint()
            pre = Building.PreModel()
            Building.time!(pre; t0=0.0, tf=1.0)
            Building.state!(pre, 1)
            Building.control!(pre, 1)
            Building.dynamics!(pre, dyn_1d!)
            Building.objective!(pre, :min; lagrange=lag_1d)
            Building.constraint!(pre, :path; f=spy, lb=[0.0], ub=[Inf], label=:s)
            Building.time_dependence!(pre; autonomous=true)
            Building.definition!(pre, quote end)
            H = Models.pseudo_hamiltonian(Building.build(pre); constraints=:s)
            H(1.5, 2.0, 0.5, 3.0)
            Test.@test spy.calls == 1
            t, x, u, v = spy.args
            Test.@test t == 0.0 && x === 1.5 && u === 0.5
            Test.@test v isa AbstractVector && isempty(v)
        end

        Test.@testset "Unit: each multiplier is called once with its natural arguments" begin
            spy = SpyMultiplier()
            h = Models.hamiltonian(ocp_all(), (x, p, v) -> 0.3; multipliers=(:vmax => spy,))
            x, p, v = [0.5, 1.5], [1.0, 2.0], 2.0
            h(x, p, v)
            Test.@test spy.calls == 1
            Test.@test spy.args == (x, p, v)
        end

        # ======================================================================
        # UNIT — automatic differentiation with constraints
        # ======================================================================

        Test.@testset "Unit: ForwardDiff through the constrained pseudo-Hamiltonian" begin
            ocp = ocp_all()
            H = Models.pseudo_hamiltonian(ocp; constraints=(:vmax, :pv))
            x, p, u, v, μ = [0.5, 1.5], [1.0, 2.0], 0.3, 2.0, [0.7, 0.2, 0.9]
            # H = p₁x₂ + p₂u − u² + 0.7(1.2 − x₂) + 0.2(4 − x₁²) − 0.9 x₂
            Test.@test ForwardDiff.gradient(x_ -> H(x_, p, u, μ, v), x) ≈
                [-2 * 0.2 * x[1], p[1] - 0.7 - 0.9]
            Test.@test ForwardDiff.gradient(p_ -> H(x, p_, u, μ, v), p) ≈ [x[2], u]
            Test.@test ForwardDiff.derivative(u_ -> H(x, p, u_, μ, v), u) ≈ p[2] - 2u
            Test.@test ForwardDiff.gradient(μ_ -> H(x, p, u, μ_, v), μ) ≈
                [1.2 - x[2], 4.0 - x[1]^2, -x[2]]
        end

        Test.@testset "Unit: total derivative of h adds g·∂μ/∂x to the partial one" begin
            ocp = ocp_bd()
            h = Models.hamiltonian(ocp, (x, p) -> 0.0; multipliers=(:x_con => (x, p) -> 2x))
            H = Models.pseudo_hamiltonian(ocp; constraints=:x_con)
            for x in (1.5, 0.4)
                total = ForwardDiff.derivative(x_ -> h(x_, 0.0), x)
                partial = ForwardDiff.derivative(x_ -> H(x_, 0.0, 0.0, 2x), x)
                Test.@test partial ≈ 0.0                    # −2x + μ, μ = 2x
                Test.@test total - partial ≈ 2 * (x - LB)   # g · ∂μ/∂x
            end
        end

        Test.@testset "Unit: constrained calls are type-stable" begin
            ocp = ocp_all()
            x, p, u, v = [0.5, 1.5], [1.0, 2.0], 0.3, 2.0
            H = Models.pseudo_hamiltonian(ocp; constraints=(:vmax, :mixed, :pv, :ubox))
            μ = [0.7, -0.4, 0.2, 0.9, 0.5]
            Test.@test (Test.@inferred H(x, p, u, μ, v)) isa Float64
            JET.@test_opt target_modules = (CTModels,) H(x, p, u, μ, v)
            h = Models.hamiltonian(
                ocp,
                (x, p, v) -> 0.3;
                multipliers=(:vmax => (x, p, v) -> 0.7, :pv => (x, p, v) -> [0.2, 0.9]),
            )
            Test.@test (Test.@inferred h(x, p, v)) isa Float64
            Hb = Models.pseudo_hamiltonian(ocp_bd(); constraints=:x_con)
            Test.@test (Test.@inferred Hb(0.7, 2.0, 0.3, 1.4)) isa Float64
        end

        # ======================================================================
        # NON-REGRESSION — the boundary arc of the docs
        # ======================================================================

        Test.@testset "Non-regression: on the boundary arc x = lb, total = partial and ṗ = 0" begin
            ocp = ocp_bd()
            h = Models.hamiltonian(ocp, (x, p) -> 0.0; multipliers=(:x_con => (x, p) -> 2x))
            H = Models.pseudo_hamiltonian(ocp; constraints=:x_con)
            total = ForwardDiff.derivative(x_ -> h(x_, 0.0), LB)
            partial = ForwardDiff.derivative(x_ -> H(x_, 0.0, 0.0, 2LB), LB)
            Test.@test total ≈ partial atol = 1e-14
            Test.@test total ≈ 0.0 atol = 1e-14
            Test.@test H(0.7, 2.0, 0.3, 1.4) ≈ 2.0 * 0.3 - 0.49 + 1.4 * 0.6     # golden
        end

        # ======================================================================
        # ERROR — constraints and multipliers
        # ======================================================================

        Test.@testset "Error: labels that cannot be adjoined" begin
            ocp = ocp_all()
            for label in (:bc, :vbox)
                Test.@test_throws Exceptions.IncorrectArgument Models.pseudo_hamiltonian(
                    ocp; constraints=label
                )
            end
            e = try
                Models.pseudo_hamiltonian(ocp; constraints=:bc)
            catch err
                err
            end
            Test.@test occursin("boundary", e.got)
            Test.@test occursin("transversality", e.suggestion)
            Test.@test_throws Exceptions.IncorrectArgument Models.pseudo_hamiltonian(
                ocp; constraints=(:vmax, :vmax)
            )
            Test.@test_throws Exceptions.IncorrectArgument Models.pseudo_hamiltonian(
                ocp; constraints=:unknown
            )
            Test.@test_throws Exceptions.IncorrectArgument Models.hamiltonian(
                ocp, (x, p, v) -> 0.3; multipliers=(:bc => (x, p, v) -> 1.0)
            )
        end

        Test.@testset "Unit: batched (Matrix) state, the constrained value sums the columns" begin
            X, P, U, M = X_BATCH, P_BATCH, U_BATCH, M_BATCH
            labels = (:pc, :pc2, :vmax, :ubox)
            H = Models.pseudo_hamiltonian(ocp_batch(); constraints=labels)
            Test.@test H(X, P, U, M) ≈
                sum(H(X[:, j], P[:, j], U[1, j], M[:, j]) for j in 1:3)
            Test.@test (Test.@inferred H(X, P, U, M)) isa Float64
            JET.@test_opt target_modules = (CTModels,) H(X, P, U, M)
            # a multiplier that is not batched is shared by all the points
            Test.@test H(X, P, U, M[:, 1]) ≈
                sum(H(X[:, j], P[:, j], U[1, j], M[:, 1]) for j in 1:3)
            # a single path constraint: its function gets the n × batch buffer itself
            H1 = Models.pseudo_hamiltonian(
                ocp_batch(; two_paths=false); constraints=(:pc, :ubox)
            )
            M1 = M[[1, 4], :]
            Test.@test H1(X, P, U, M1) ≈
                sum(H1(X[:, j], P[:, j], U[1, j], M1[:, j]) for j in 1:3)
        end

        Test.@testset "Unit: batched (Matrix) state, the constrained gradient is taken column by column" begin
            X, P, U, M = X_BATCH, P_BATCH, U_BATCH, M_BATCH
            H = Models.pseudo_hamiltonian(
                ocp_batch(); constraints=(:pc, :pc2, :vmax, :ubox)
            )
            ∇X = ForwardDiff.gradient(Y -> H(Y, P, U, M), X)
            for j in 1:3
                ∇x = ForwardDiff.gradient(y -> H(y, P[:, j], U[1, j], M[:, j]), X[:, j])
                Test.@test ∇X[:, j] ≈ ∇x
            end
        end

        Test.@testset "Unit: batched (Matrix) state, the rows of a constraint" begin
            ocp = ocp_batch()
            _, c, _, _ = Models.constraint(ocp, :pc2)
            Test.@test c(0.0, X_BATCH, U_BATCH, zeros(0, 3)) ≈ X_BATCH[2:2, :] .^ 2
            Test.@test c(0.0, X_BATCH[:, 2], U_BATCH[1, 2], Float64[]) ≈ X_BATCH[2, 2]^2
        end

        Test.@testset "Unit: batched (Matrix) state, hamiltonian(ocp, u; multipliers)" begin
            ocp = ocp_batch()
            h = Models.hamiltonian(
                ocp,
                law_batch;
                multipliers=(:pc => μ_pc_batch, :pc2 => μ_pc2_batch, :vmax => μ_vmax_batch),
            )
            hp = Models.hamiltonian(
                ocp,
                law_point;
                multipliers=(:pc => μ_pc_point, :pc2 => μ_pc2_point, :vmax => μ_vmax_point),
            )
            Test.@test h(X_BATCH, P_BATCH) ≈
                sum(hp(X_BATCH[:, j], P_BATCH[:, j]) for j in 1:3)
        end

        Test.@testset "Unit: a box label gives the effective, intersected box" begin
            ocp = ocp_alias()
            x, p, u = [0.5, 1.0], [1.0, 1.0], 0.2
            H̃ = Models.pseudo_hamiltonian(ocp)
            Ha = Models.pseudo_hamiltonian(ocp; constraints=:a)
            Hb = Models.pseudo_hamiltonian(ocp; constraints=:b)
            # :a was written x₁ ≥ 0, but its box is 0 ≤ x₁ ≤ 1: two-sided, y signed
            Test.@test Ha(x, p, u, 2.0) ≈ H̃(x, p, u) - 2.0 * (x[1] - 1.0)
            Test.@test Ha(x, p, u, -2.0) ≈ H̃(x, p, u) + 2.0 * (x[1] - 0.0)
            Test.@test Hb(x, p, u, 2.0) ≈ Ha(x, p, u, 2.0)
            Hac = Models.pseudo_hamiltonian(ocp; constraints=(:a, :c))
            Test.@test Hac(x, p, u, [2.0, 3.0]) ≈ Ha(x, p, u, 2.0) + 3.0 * (2.0 - x[2])
        end

        Test.@testset "Error: constraints not given by their labels" begin
            ocp = ocp_all()
            for bad in ("mixed", nothing, (:mixed, "pv"), ["mixed"], 1)
                Test.@test_throws Exceptions.IncorrectArgument Models.pseudo_hamiltonian(
                    ocp; constraints=bad
                )
            end
            e = try
                Models.pseudo_hamiltonian(ocp; constraints="mixed")
            catch err
                err
            end
            Test.@test occursin("\"mixed\"", e.got)
            Test.@test occursin("Symbol", e.expected)
        end

        Test.@testset "Error: two labels of the same box component" begin
            ocp = ocp_alias()
            Test.@test_throws Exceptions.IncorrectArgument Models.pseudo_hamiltonian(
                ocp; constraints=(:a, :b)
            )
            Test.@test_throws Exceptions.IncorrectArgument Models.pseudo_hamiltonian(
                ocp; constraints=[:c, :b, :a]
            )
            Test.@test_throws Exceptions.IncorrectArgument Models.hamiltonian(
                ocp, (x, p) -> 0.3; multipliers=(:a => (x, p) -> 1.0, :b => (x, p) -> 1.0)
            )
            e = try
                Models.pseudo_hamiltonian(ocp; constraints=(:a, :b))
            catch err
                err
            end
            Test.@test occursin(":a and :b", e.msg)
            Test.@test occursin("[1]", e.got)
            Test.@test occursin("effective box", e.suggestion)
        end

        Test.@testset "Error: a multiplier without the dimension of the constraints" begin
            ocp = ocp_all()
            x, p, u, v = [0.5, 1.5], [1.0, 2.0], 0.3, 2.0
            H = Models.pseudo_hamiltonian(ocp; constraints=(:vmax, :pv))
            Test.@test_throws Exceptions.IncorrectArgument H(x, p, u, [1.0, 2.0], v)
            Test.@test_throws Exceptions.IncorrectArgument H(x, p, u, 1.0, v)
            Hpv = Models.pseudo_hamiltonian(ocp; constraints=:pv)
            Test.@test_throws Exceptions.IncorrectArgument Hpv(x, p, u, 1.0, v)
            h = Models.hamiltonian(
                ocp, (x, p, v) -> 0.3; multipliers=(:pv => (x, p, v) -> 1.0,)
            )
            Test.@test_throws Exceptions.IncorrectArgument h(x, p, v)
            hv = Models.hamiltonian(
                ocp, (x, p, v) -> 0.3; multipliers=(:vmax => (x, p, v) -> [1.0, 2.0],)
            )
            Test.@test_throws Exceptions.IncorrectArgument hv(x, p, v)
        end

        Test.@testset "Error: a batched multiplier without one column per point" begin
            H = Models.pseudo_hamiltonian(
                ocp_batch(); constraints=(:pc, :pc2, :vmax, :ubox)
            )
            Test.@test_throws Exceptions.IncorrectArgument H(
                X_BATCH, P_BATCH, U_BATCH, M_BATCH[:, 1:2]
            )
            Test.@test_throws Exceptions.IncorrectArgument H(
                X_BATCH, P_BATCH, U_BATCH, M_BATCH[1:3, :]
            )
            h = Models.hamiltonian(
                ocp_batch(), law_batch; multipliers=(:pc => (x, p) -> [x; p])
            )
            Test.@test_throws Exceptions.IncorrectArgument h(X_BATCH, P_BATCH)
        end

        Test.@testset "Error: multipliers given in an unsupported way" begin
            ocp = ocp_all()
            law = (x, p, v) -> 0.3
            Test.@test_throws Exceptions.IncorrectArgument Models.hamiltonian(
                ocp, law; multipliers=(x, p, v) -> 1.0
            )
            Test.@test_throws Exceptions.IncorrectArgument Models.hamiltonian(
                ocp, law; multipliers=(:vmax => 1.0,)
            )
            Test.@test_throws Exceptions.IncorrectArgument Models.hamiltonian(
                ocp,
                law;
                multipliers=(:vmax => (x, p) -> 1.0,),          # wrong arity
            )
        end

        Test.@testset "Error: constraints on a control-free problem" begin
            Test.@test_throws Exceptions.PreconditionError Models.pseudo_hamiltonian(
                ocp_cf(); constraints=:x
            )
            Test.@test_throws Exceptions.PreconditionError Models.hamiltonian(
                ocp_cf(); multipliers=(:x => (x, p) -> 1.0,)
            )
        end

        # ======================================================================
        # CONTRACT — the getters are methods of the CTBase.Data generic functions
        # ======================================================================

        Test.@testset "Contract: Models re-exports the CTBase.Data functions" begin
            Test.@test Models.pseudo_hamiltonian === Data.pseudo_hamiltonian
            Test.@test Models.hamiltonian === Data.hamiltonian
            Test.@test :pseudo_hamiltonian in names(Models)
            Test.@test :hamiltonian in names(Models)
            Test.@test !(:pseudo_hamiltonian in names(CTModels))   # MOD8
        end

        # ======================================================================
        # ERROR — preconditions and arguments
        # ======================================================================

        Test.@testset "Error: pseudo_hamiltonian of a control-free problem" begin
            Test.@test_throws Exceptions.PreconditionError Models.pseudo_hamiltonian(
                ocp_cf()
            )
            e = try
                Models.pseudo_hamiltonian(ocp_cf())
            catch err
                err
            end
            Test.@test occursin("hamiltonian(ocp)", e.suggestion)
        end

        Test.@testset "Error: hamiltonian(ocp) of a problem with a control" begin
            Test.@test_throws Exceptions.PreconditionError Models.hamiltonian(ocp_1d())
            e = try
                Models.hamiltonian(ocp_1d())
            catch err
                err
            end
            Test.@test occursin("hamiltonian(ocp, u)", e.suggestion)
        end

        Test.@testset "Error: hamiltonian(ocp, u) of a control-free problem" begin
            Test.@test_throws Exceptions.PreconditionError Models.hamiltonian(
                ocp_cf(), (x, p) -> p
            )
        end

        Test.@testset "Error: p0 with the wrong sign, or not finite" begin
            for (ocp, p0) in (
                (ocp_1d(), 1),
                (ocp_1d(; criterion=:max), -1),
                (ocp_1d(), NaN),
                (ocp_1d(), -Inf),
            )
                Test.@test_throws Exceptions.IncorrectArgument Models.pseudo_hamiltonian(
                    ocp; p0=p0
                )
            end
            Test.@test_throws Exceptions.IncorrectArgument Models.hamiltonian(
                ocp_cf(); p0=1
            )
            Test.@test_throws Exceptions.IncorrectArgument Models.hamiltonian(
                ocp_1d(), (x, p) -> p; p0=1
            )
            e = try
                Models.pseudo_hamiltonian(ocp_1d(); p0=1)
            catch err
                err
            end
            Test.@test occursin(":min", e.got)
            Test.@test occursin("p0 ≤ 0", e.expected)
        end

        Test.@testset "Error: a raw control law with the wrong arity" begin
            Test.@test_throws Exceptions.IncorrectArgument Models.hamiltonian(
                ocp_1d(), (t, x, p) -> p
            )
            e = try
                Models.hamiltonian(ocp_2d(; autonomous=false, q=1), (x, p) -> 0.0)
            catch err
                err
            end
            Test.@test occursin("u(t, x, p, v)", e.got)
        end

        Test.@testset "Error: an open-loop or closed-loop law" begin
            Test.@test_throws Exceptions.IncorrectArgument Models.hamiltonian(
                ocp_1d(), Data.OpenLoop(t -> 1.0)
            )
            Test.@test_throws Exceptions.IncorrectArgument Models.hamiltonian(
                ocp_1d(), Data.ClosedLoop(x -> -x)
            )
        end
    end
end

end # module TestHamiltonians

# CRITICAL: Redefine in outer scope for TestRunner
test_hamiltonians() = TestHamiltonians.test_hamiltonians()
