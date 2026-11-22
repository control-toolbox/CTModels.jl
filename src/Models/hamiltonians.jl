# ==============================================================================
# Hamiltonians of an optimal control problem
#
# The pseudo-Hamiltonian H̃(t,x,p,u,v) = p·f(t,x,u,v) + p⁰ℓ(t,x,u,v) and the Hamiltonian
# of a control-free problem H(t,x,p,v) = p·f(t,x,v) + p⁰ℓ(t,x,v) depend only on the
# model. They are always maximised (ct-conventions SGN4): p⁰ ≤ 0 for a minimisation,
# p⁰ ≥ 0 for a maximisation, p⁰ = ∓1 in the normal case, p⁰ = 0 in the abnormal case.
#
# TD/VD are type parameters of the functors, so dispatch selects the natural-arity call
# without runtime branches. The state, control and variable are passed to the model
# functions as received — a scalar for a 1-D quantity, a vector otherwise (DIM1) — and
# the derivative buffer is always a length-n_x vector built like the state.
# ==============================================================================

# ------------------------------------------------------------------------------
# Buffers and p⁰
# ------------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Allocate a zero-filled buffer of element type `T` and length `n` like `template`:
`similar(template, T, n)` for an array, so a GPU state gets a GPU buffer, and a `Vector`
for a scalar (1-D) state.

See also: [`CTModels.Models.PseudoHamiltonianFunction`](@extref).
"""
function _buffer_like(template::AbstractArray, ::Type{T}, n::Int) where {T}
    return fill!(similar(template, T, n), zero(T))
end
_buffer_like(::Any, ::Type{T}, n::Int) where {T} = zeros(T, n)

"""
$(TYPEDSIGNATURES)

The value of `p⁰` in the normal case (ct-conventions `SGN4`): `-1` for a minimisation,
`+1` for a maximisation.

See also: [`CTModels.Models._checked_p0`](@extref).
"""
_normal_p0(ocp::Model) = Components.criterion(ocp) === :min ? -1.0 : 1.0

"""
$(TYPEDSIGNATURES)

Check that `p0` has the sign the criterion of `ocp` requires (ct-conventions `SGN4`):
`p0 ≤ 0` for a minimisation, `p0 ≥ 0` for a maximisation, `p0 = 0` being the abnormal
case. Return it as a `Float64`.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if `p0` is not finite, or if its sign
  contradicts the criterion.

See also: [`CTModels.Models._normal_p0`](@extref).
"""
function _checked_p0(ocp::Model, p0::Real, context::String)
    criterion = Components.criterion(ocp)
    expected = criterion === :min ? "p0 ≤ 0" : "p0 ≥ 0"
    valid = isfinite(p0) && (criterion === :min ? p0 <= 0 : p0 >= 0)
    valid || throw(
        Exceptions.IncorrectArgument(
            "p0 does not have the sign of the criterion";
            got="p0 = $p0 for a :$criterion problem",
            expected="$expected (p0 = $(_normal_p0(ocp)) in the normal case, p0 = 0 in the abnormal case)",
            suggestion="The pseudo-Hamiltonian p·f + p0·ℓ is always maximised: only the sign of p0 depends on the criterion",
            context=context,
        ),
    )
    return Float64(p0)
end

"""
$(TYPEDSIGNATURES)

The Lagrange cost `ℓ(t, x, u, v)` of `ocp`, or `nothing` if it has none (Mayer problem).
"""
function _lagrange_or_nothing(ocp::Model)
    return Components.has_lagrange_cost(ocp) ? Components.lagrange(ocp) : nothing
end

# ------------------------------------------------------------------------------
# Pseudo-Hamiltonian functor
# ------------------------------------------------------------------------------

"""
$(TYPEDEF)

The pseudo-Hamiltonian of an optimal control problem,
`H̃(t, x, p, u, v) = p·f(t, x, u, v) + p⁰ ℓ(t, x, u, v)`, built from the dynamics, the
Lagrange cost and `p⁰`. Wrapped in a `CTBase.Data.PseudoHamiltonian` by
[`CTBase.Data.pseudo_hamiltonian`](@extref); see there for the convention.

# Type Parameters
- `TD`, `VD`: time and variable dependence of the model, selecting the natural arity.
- `DF`: type of the in-place dynamics `f!(r, t, x, u, v)`.
- `LF`: type of the Lagrange cost `ℓ(t, x, u, v)`, or `Nothing` for a Mayer problem.

# Fields
- `dynamics!::DF`: the in-place dynamics of the model.
- `lagrange::LF`: the Lagrange cost of the model, or `nothing`.
- `p0::Float64`: the multiplier of the cost.
- `n::Int`: the state dimension.

See also: [`CTModels.Models.HamiltonianFunction`](@extref).
"""
struct PseudoHamiltonianFunction{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    DF<:Function,
    LF<:Union{Function,Nothing},
} <: Function
    dynamics!::DF
    lagrange::LF
    p0::Float64
    n::Int
end

"""
$(TYPEDSIGNATURES)

Value `p·f(t, x, u, v) + p⁰ ℓ(t, x, u, v)`. `x`, `u` and `v` are passed to the model
functions as received; `v === nothing` stands for a problem without variable, which
receives an empty vector.

See also: [`CTModels.Models.PseudoHamiltonianFunction`](@extref).
"""
function _pseudo_H(h::PseudoHamiltonianFunction, t, x, p, u, v)
    T = Base.promote_op(*, eltype(x), eltype(u))
    vv = v === nothing ? _buffer_like(x, T, 0) : v
    v === nothing || (T = Base.promote_op(*, T, eltype(v)))
    r = _buffer_like(x, T, h.n)
    h.dynamics!(r, t, x, u, vv)
    val = sum(p .* r)                       # p·f — scalar p (1-D) or vector p
    h.lagrange === nothing || (val += h.p0 * h.lagrange(t, x, u, vv))
    return val
end

function (h::PseudoHamiltonianFunction{Traits.Autonomous,Traits.Fixed})(x, p, u)
    return _pseudo_H(h, 0.0, x, p, u, nothing)
end
function (h::PseudoHamiltonianFunction{Traits.NonAutonomous,Traits.Fixed})(t, x, p, u)
    return _pseudo_H(h, t, x, p, u, nothing)
end
function (h::PseudoHamiltonianFunction{Traits.Autonomous,Traits.NonFixed})(x, p, u, v)
    return _pseudo_H(h, 0.0, x, p, u, v)
end
function (h::PseudoHamiltonianFunction{Traits.NonAutonomous,Traits.NonFixed})(t, x, p, u, v)
    return _pseudo_H(h, t, x, p, u, v)
end

# ------------------------------------------------------------------------------
# Hamiltonian functor of a control-free problem
# ------------------------------------------------------------------------------

"""
$(TYPEDEF)

The Hamiltonian of a **control-free** optimal control problem,
`H(t, x, p, v) = p·f(t, x, v) + p⁰ ℓ(t, x, v)`, built from the dynamics, the Lagrange
cost and `p⁰`; the model functions receive an empty control. Wrapped in a
`CTBase.Data.Hamiltonian` by [`CTBase.Data.hamiltonian`](@extref).

# Type Parameters
- `TD`, `VD`: time and variable dependence of the model, selecting the natural arity.
- `DF`: type of the in-place dynamics `f!(r, t, x, u, v)`.
- `LF`: type of the Lagrange cost `ℓ(t, x, u, v)`, or `Nothing` for a Mayer problem.

# Fields
- `dynamics!::DF`: the in-place dynamics of the model.
- `lagrange::LF`: the Lagrange cost of the model, or `nothing`.
- `p0::Float64`: the multiplier of the cost.
- `n::Int`: the state dimension.

See also: [`CTModels.Models.PseudoHamiltonianFunction`](@extref).
"""
struct HamiltonianFunction{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    DF<:Function,
    LF<:Union{Function,Nothing},
} <: Function
    dynamics!::DF
    lagrange::LF
    p0::Float64
    n::Int
end

"""
$(TYPEDSIGNATURES)

Value `p·f(t, x, ∅, v) + p⁰ ℓ(t, x, ∅, v)`, with an empty control. `x` and `v` are passed
as received; `v === nothing` stands for a problem without variable, which receives an
empty vector.

See also: [`CTModels.Models.HamiltonianFunction`](@extref).
"""
function _control_free_H(h::HamiltonianFunction, t, x, p, v)
    T = v === nothing ? eltype(x) : Base.promote_op(*, eltype(x), eltype(v))
    u = _buffer_like(x, T, 0)               # empty control
    vv = v === nothing ? u : v
    r = _buffer_like(x, T, h.n)
    h.dynamics!(r, t, x, u, vv)
    val = sum(p .* r)
    h.lagrange === nothing || (val += h.p0 * h.lagrange(t, x, u, vv))
    return val
end

function (h::HamiltonianFunction{Traits.Autonomous,Traits.Fixed})(x, p)
    return _control_free_H(h, 0.0, x, p, nothing)
end
function (h::HamiltonianFunction{Traits.NonAutonomous,Traits.Fixed})(t, x, p)
    return _control_free_H(h, t, x, p, nothing)
end
function (h::HamiltonianFunction{Traits.Autonomous,Traits.NonFixed})(x, p, v)
    return _control_free_H(h, 0.0, x, p, v)
end
function (h::HamiltonianFunction{Traits.NonAutonomous,Traits.NonFixed})(t, x, p, v)
    return _control_free_H(h, t, x, p, v)
end

# ------------------------------------------------------------------------------
# Raw control laws: arity check and wrapping
# ------------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Natural arity of a function of `(x, p)` (a control law or a multiplier) for `ocp`: 2,
plus 1 for the time if the problem is non-autonomous, plus 1 for the variable if it has
one.

See also: [`CTModels.Models._arity_issue`](@extref).
"""
_expected_arity(ocp::Model) = 2 + !Traits.is_autonomous(ocp) + Traits.is_variable(ocp)

"""
$(TYPEDSIGNATURES)

Natural syntax of a function of `(x, p)` named `name` for `ocp`, e.g. `"u(t, x, p)"`, for
error messages.

See also: [`CTModels.Models._arity_issue`](@extref).
"""
function _natural_syntax(name::AbstractString, ocp::Model)
    args = String[]
    Traits.is_autonomous(ocp) || push!(args, "t")
    push!(args, "x", "p")
    Traits.is_variable(ocp) && push!(args, "v")
    return "$name($(join(args, ", ")))"
end

"""
$(TYPEDSIGNATURES)

A one-line diagnostic if the raw function `f` has a single method whose arity is not the
natural arity for `ocp`, `nothing` otherwise. A function with several methods is not
checked: the intended arity cannot be known.

See also: [`CTModels.Models._expected_arity`](@extref).
"""
function _arity_issue(f::Function, ocp::Model, name::AbstractString, kind::AbstractString)
    length(methods(f)) == 1 || return nothing
    arity = first(methods(f)).nargs - 1
    expected = _expected_arity(ocp)
    arity == expected && return nothing
    return "$kind `$name` has arity $arity, expected $expected: natural syntax is `$(_natural_syntax(name, ocp))`"
end

"""
$(TYPEDSIGNATURES)

Wrap the raw control law `u` in a `CTBase.Data.DynClosedLoop` law with the time and
variable dependence of `ocp`, after checking its arity.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if `u` has a single method and an arity that is
  not the natural arity for `ocp`.

See also: [`CTModels.Models._arity_issue`](@extref).
"""
function _control_law(ocp::Model, u::Function, context::String)
    issue = _arity_issue(u, ocp, "u", "control law")
    issue === nothing || throw(
        Exceptions.IncorrectArgument(
            "control law arity mismatch";
            got=issue,
            expected="a control law with the time and variable dependence of the problem",
            suggestion="Pass a CTBase.Data.DynClosedLoop law built with the time and variable dependence you intend",
            context=context,
        ),
    )
    return Data.DynClosedLoop(
        u; is_autonomous=Traits.is_autonomous(ocp), is_variable=Traits.is_variable(ocp)
    )
end

"""
$(TYPEDSIGNATURES)

Return a dynamic closed-loop control law as is.
"""
function _control_law(
    ::Model, law::Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback}, ::String
)
    return law
end

"""
$(TYPEDSIGNATURES)

Reject an open-loop or closed-loop control law: the Hamiltonian needs the control as a
function of the costate.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: always.
"""
function _control_law(::Model, law::Data.ControlLaw, context::String)
    return throw(
        Exceptions.IncorrectArgument(
            "the control law must be a dynamic closed-loop law u(t, x, p, v)";
            got="a control law with feedback $(nameof(Traits.feedback(law)))",
            expected="a CTBase.Data.DynClosedLoop law, or a function of (x, p) with the natural arity of the problem",
            suggestion="Build the law with CTBase.Data.DynClosedLoop",
            context=context,
        ),
    )
end

# ------------------------------------------------------------------------------
# Control-dependence guards
# ------------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Throw a `CTBase.Exceptions.PreconditionError` unless `ocp` has a control.
"""
function _require_control(ocp::Model, msg::String, suggestion::String, context::String)
    Traits.control_dependence(ocp) === Traits.WithControl || throw(
        Exceptions.PreconditionError(
            msg;
            reason="the problem is control-free",
            suggestion=suggestion,
            context=context,
        ),
    )
    return nothing
end

"""
$(TYPEDSIGNATURES)

Throw a `CTBase.Exceptions.PreconditionError` unless `ocp` is control-free.
"""
function _require_control_free(ocp::Model, msg::String, suggestion::String, context::String)
    Traits.control_dependence(ocp) === Traits.ControlFree || throw(
        Exceptions.PreconditionError(
            msg;
            reason="the problem has a control",
            suggestion=suggestion,
            context=context,
        ),
    )
    return nothing
end

# ------------------------------------------------------------------------------
# Public getters (methods of the CTBase.Data generic functions)
# ------------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Return the pseudo-Hamiltonian of the optimal control problem `ocp`,

```math
\\tilde H(t, x, p, u, v) = p \\cdot f(t, x, u, v) + p^0\\, \\ell(t, x, u, v),
```

as a `CTBase.Data.PseudoHamiltonian` with the time and variable dependence of `ocp`,
where `f` is the dynamics and `ℓ` the Lagrange cost (absent for a Mayer problem). It
does not depend on any control law.

The pseudo-Hamiltonian is always **maximised** (ct-conventions `SGN4`): only the sign of
`p⁰` depends on the criterion.

# Arguments
- `ocp::Model`: an optimal control problem **with a control**.
- `p0::Real`: the multiplier of the cost; `-1` for `:min` and `+1` for `:max` by default
  (normal case), `0` for the abnormal case. Its sign must agree with the criterion.

# Returns
- `CTBase.Data.PseudoHamiltonian`: callable with its natural signature,
  `H̃(x, p, u)`, `H̃(t, x, p, u)`, `H̃(x, p, u, v)` or `H̃(t, x, p, u, v)`, and with the
  uniform signature `H̃(t, x, p, u, v)`. A one-dimensional state, control or variable is a
  number.

# Throws
- `CTBase.Exceptions.PreconditionError`: if `ocp` is control-free (use
  [`CTBase.Data.hamiltonian`](@extref) instead).
- `CTBase.Exceptions.IncorrectArgument`: if the sign of `p0` contradicts the criterion.

# Example

```julia-repl
julia> H̃ = CTModels.Models.pseudo_hamiltonian(ocp)          # ẋ = u, ∫ x² → min

julia> H̃(1.0, 2.0, 0.5)                                    # p·u − x² = 0.0
0.0

julia> CTModels.Models.pseudo_hamiltonian(ocp; p0=0)(1.0, 2.0, 0.5)   # abnormal: p·u
1.0
```

See also: [`CTBase.Data.hamiltonian`](@extref),
[`CTModels.Models.PseudoHamiltonianFunction`](@extref).
"""
function Data.pseudo_hamiltonian(ocp::Model; p0::Real=_normal_p0(ocp))
    context = "pseudo_hamiltonian(ocp; p0)"
    _require_control(
        ocp,
        "the pseudo-Hamiltonian of a control-free problem is not defined",
        "Use hamiltonian(ocp) for the Hamiltonian of a control-free problem",
        context,
    )
    return _pseudo_hamiltonian(ocp, _checked_p0(ocp, p0, context))
end

"""
$(TYPEDSIGNATURES)

Build the `CTBase.Data.PseudoHamiltonian` of `ocp` for a checked `p0`.

See also: [`CTBase.Data.pseudo_hamiltonian`](@extref).
"""
function _pseudo_hamiltonian(ocp::Model, p0::Float64)
    TD = Traits.time_dependence(ocp)
    VD = Traits.variable_dependence(ocp)
    dyn! = dynamics(ocp)
    lag = _lagrange_or_nothing(ocp)
    f = PseudoHamiltonianFunction{TD,VD,typeof(dyn!),typeof(lag)}(
        dyn!, lag, p0, state_dimension(ocp)
    )
    return Data.PseudoHamiltonian(f, TD, VD)
end

"""
$(TYPEDSIGNATURES)

Return the Hamiltonian of the **control-free** optimal control problem `ocp`,

```math
H(t, x, p, v) = p \\cdot f(t, x, v) + p^0\\, \\ell(t, x, v),
```

as a `CTBase.Data.Hamiltonian` with the time and variable dependence of `ocp`.

# Arguments
- `ocp::Model`: a control-free optimal control problem.
- `p0::Real`: the multiplier of the cost; `-1` for `:min` and `+1` for `:max` by default
  (normal case), `0` for the abnormal case. Its sign must agree with the criterion
  (ct-conventions `SGN4`).

# Returns
- `CTBase.Data.Hamiltonian`: callable as `H([t, ]x, p[, v])` and `H(t, x, p, v)`.

# Throws
- `CTBase.Exceptions.PreconditionError`: if `ocp` has a control (give a control law:
  `hamiltonian(ocp, u)`).
- `CTBase.Exceptions.IncorrectArgument`: if the sign of `p0` contradicts the criterion.

See also: [`CTBase.Data.pseudo_hamiltonian`](@extref),
[`CTModels.Models.HamiltonianFunction`](@extref).
"""
function Data.hamiltonian(ocp::Model; p0::Real=_normal_p0(ocp))
    context = "hamiltonian(ocp; p0)"
    _require_control_free(
        ocp,
        "the Hamiltonian of a problem with a control needs a control law",
        "Use hamiltonian(ocp, u) with a control law u, or pseudo_hamiltonian(ocp)",
        context,
    )
    p0 = _checked_p0(ocp, p0, context)
    TD = Traits.time_dependence(ocp)
    VD = Traits.variable_dependence(ocp)
    dyn! = dynamics(ocp)
    lag = _lagrange_or_nothing(ocp)
    f = HamiltonianFunction{TD,VD,typeof(dyn!),typeof(lag)}(
        dyn!, lag, p0, state_dimension(ocp)
    )
    return Data.Hamiltonian(f, TD, VD)
end

"""
$(TYPEDSIGNATURES)

Return the Hamiltonian of the optimal control problem `ocp` for the control law `u`,

```math
H(t, x, p, v) = \\tilde H(t, x, p, u(t, x, p, v), v),
```

where `H̃` is [`CTBase.Data.pseudo_hamiltonian`](@extref)`(ocp; p0)`, as a
`CTBase.Data.ComposedHamiltonian`. Differentiating it gives the total derivative,
through the control law.

# Arguments
- `ocp::Model`: an optimal control problem with a control.
- `u`: the control law in feedback form, either a `CTBase.Data.DynClosedLoop` law, or a
  function with the natural arity of the problem: `u(x, p)`, `u(t, x, p)`, `u(x, p, v)`
  or `u(t, x, p, v)`.
- `p0::Real`: the multiplier of the cost; see [`CTBase.Data.pseudo_hamiltonian`](@extref).

# Returns
- `CTBase.Data.ComposedHamiltonian`: callable as `H([t, ]x, p[, v])` and `H(t, x, p, v)`,
  with the joined time and variable dependence of the problem and the law.

# Throws
- `CTBase.Exceptions.PreconditionError`: if `ocp` is control-free (use
  `hamiltonian(ocp)`).
- `CTBase.Exceptions.IncorrectArgument`: if `u` is an open-loop or closed-loop law, if
  a raw `u` has a single method with the wrong arity, or if the sign of `p0` contradicts
  the criterion.

# Example

```julia-repl
julia> H = CTModels.Models.hamiltonian(ocp, (x, p) -> p)    # ẋ = u, ∫ x² → min, u = p

julia> H(1.0, 2.0)                                         # p² − x²
3.0
```

See also: [`CTBase.Data.pseudo_hamiltonian`](@extref), `CTBase.Data.ComposedHamiltonian`.
"""
function Data.hamiltonian(
    ocp::Model, u::Union{Function,Data.ControlLaw}; p0::Real=_normal_p0(ocp)
)
    context = "hamiltonian(ocp, u; p0)"
    _require_control(
        ocp,
        "a control law is given for a control-free problem",
        "Use hamiltonian(ocp) for the Hamiltonian of a control-free problem",
        context,
    )
    h̃ = _pseudo_hamiltonian(ocp, _checked_p0(ocp, p0, context))
    return Data.ComposedHamiltonian(h̃, _control_law(ocp, u, context))
end
