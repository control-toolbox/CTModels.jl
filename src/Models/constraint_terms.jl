# ==============================================================================
# Constraint terms of the Hamiltonians, by label
#
# A path constraint, a state box or a control box `lb ≤ c(t,x,u,v) ≤ ub` is adjoined to
# the pseudo-Hamiltonian with its multiplier y, in the sign convention of the duals of a
# solution (ct-conventions SGN2–SGN4), component by component:
#
#   lower bound only            y·(c − lb)          y ≥ 0
#   upper bound only            y·(ub − c)          y ≥ 0
#   two bounds, or equality     −y·(c − b)          y signed, b = ub if y > 0, lb otherwise
#
# that is μ·g with g ≥ 0 the constraint on its active side and μ ≥ 0 its multiplier. The
# side of a two-sided constraint is read on the sign of y, so it never has to be given;
# the term is continuous at y = 0. A label that is not given is inactive (y = 0).
# ==============================================================================

# ------------------------------------------------------------------------------
# One labelled constraint
# ------------------------------------------------------------------------------

"""
Side code of a constraint component with a finite lower bound only: term `y (c − lb)`.
"""
const _LOWER = 1

"""
Side code of a constraint component with a finite upper bound only: term `y (ub − c)`.
"""
const _UPPER = 2

"""
Side code of a constraint component with two finite bounds, or an equality: term
`−y (c − b)`, with `b = ub` if `y > 0` and `b = lb` otherwise.
"""
const _BOTH = 3

"""
$(TYPEDEF)

The value of a labelled state box (`Slot = :state`) or control box (`Slot = :control`):
the bounded components of the state or of the control, always a vector.

# Fields
- `components::Vector{Int}`: the bounded components.
"""
struct _BoxValue{Slot}
    components::Vector{Int}
end

"""
$(TYPEDSIGNATURES)

Component `i` of a state or control: the number itself for a one-dimensional quantity
(ct-conventions `DIM1`), `z[i]` otherwise.
"""
_component(z::Number, ::Int) = z
_component(z::AbstractVector, i::Int) = z[i]
"""
$(TYPEDSIGNATURES)

Value of a box: the bounded components of the state (`:state`) or of the control
(`:control`), as a vector.
"""
(c::_BoxValue{:state})(t, x, u, v) = map(i -> _component(x, i), c.components)
(c::_BoxValue{:control})(t, x, u, v) = map(i -> _component(u, i), c.components)

"""
$(TYPEDEF)

The term of one labelled constraint `lb ≤ c(t, x, u, v) ≤ ub` in the constrained
pseudo-Hamiltonian, `(t, x, u, y, v) ↦ Σᵢ termᵢ`, where `y` is the multiplier in the sign
convention of the duals of a solution (see [`CTModels.Models._side_term`](@extref)).

# Fields
- `label::Symbol`: the label of the constraint in the model.
- `c::C`: the value of the constraint, always a vector: a
  [`CTModels.Models.SubPathConstraint`](@extref) on a vector of rows, or a
  [`CTModels.Models._BoxValue`](@extref).
- `side::Vector{Int}`: `_LOWER`, `_UPPER` or `_BOTH`, per component.
- `lb::Vector{Float64}`, `ub::Vector{Float64}`: the bounds, per component.

See also: [`CTModels.Models.ConstrainedPseudoHamiltonianFunction`](@extref).
"""
struct _ConstraintTerm{C}
    label::Symbol
    c::C
    side::Vector{Int}
    lb::Vector{Float64}
    ub::Vector{Float64}
end

"""
$(TYPEDSIGNATURES)

Number of components of the constraint of a term, that is of its multiplier.
"""
_dimension(τ::_ConstraintTerm) = length(τ.side)

"""
$(TYPEDSIGNATURES)

The term of one component `lb ≤ c ≤ ub` with multiplier `y`, in the sign convention of
the duals (ct-conventions `SGN2`, `SGN3`): `y (c − lb)` for a lower bound only,
`y (ub − c)` for an upper bound only, `−y (c − b)` for two bounds or an equality, with
`b = ub` if `y > 0` and `b = lb` otherwise.
"""
function _side_term(side::Int, lb::Float64, ub::Float64, c, y)
    side == _LOWER && return y * (c - lb)
    side == _UPPER && return y * (ub - c)
    return -y * (c - ifelse(y > 0, ub, lb))
end

"""
$(TYPEDSIGNATURES)

Value of the term of a labelled constraint for the multiplier `y` (a number for a
one-dimensional constraint, a vector otherwise): the sum over its components of
[`CTModels.Models._side_term`](@extref).
"""
function (τ::_ConstraintTerm)(t, x, u, y, v)
    return sum(_side_term.(τ.side, τ.lb, τ.ub, τ.c(t, x, u, v), y))
end

"""
$(TYPEDSIGNATURES)

The side code of one component `lb ≤ c ≤ ub`, from the bounds that are finite.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if neither bound is finite.
"""
function _side(label::Symbol, lb::Real, ub::Real, context::String)
    lo, up = isfinite(lb), isfinite(ub)
    lo && up && return _BOTH
    lo && return _LOWER
    up && return _UPPER
    return throw(
        Exceptions.IncorrectArgument(
            "the constraint :$label has a component with no finite bound";
            got="$lb ≤ c ≤ $ub",
            expected="a finite lower or upper bound",
            context=context,
        ),
    )
end

"""
$(TYPEDSIGNATURES)

The value functor of the constraint `label` of kind `kind` in `ocp`.
"""
function _constraint_value(ocp::Model, label::Symbol, kind::Symbol)
    if kind === :path
        cp = Components.path_constraints_nl(ocp)
        return SubPathConstraint(cp[2], length(cp[1]), _nl_rows(cp, label))   # rows: a vector
    elseif kind === :state
        return _BoxValue{:state}(
            _box_components(Components.state_constraints_box(ocp), label)
        )
    else
        return _BoxValue{:control}(
            _box_components(Components.control_constraints_box(ocp), label)
        )
    end
end

"""
$(TYPEDSIGNATURES)

The [`CTModels.Models._ConstraintTerm`](@extref) of the constraint labelled `label` in
`ocp`: a path constraint, a state box or a control box.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if the label is unknown, or names a boundary
  constraint or a variable box, which do not enter the Hamiltonian.
"""
function _constraint_term(ocp::Model, label::Symbol, context::String)
    kind, _, lb, ub = constraint(ocp, label)
    kind in (:path, :state, :control) || throw(
        Exceptions.IncorrectArgument(
            "the constraint :$label does not enter the Hamiltonian";
            got="a $(kind === :boundary ? "boundary constraint" : "variable box")",
            expected="the label of a path constraint, a state box or a control box",
            suggestion="Boundary constraints and bounds on the variable do not depend on time: they give the transversality conditions, not a term of the Hamiltonian",
            context=context,
        ),
    )
    lbs, ubs = Float64.(vcat(lb)), Float64.(vcat(ub))
    sides = [_side(label, l, u, context) for (l, u) in zip(lbs, ubs)]
    return _ConstraintTerm(label, _constraint_value(ocp, label, kind), sides, lbs, ubs)
end

"""
$(TYPEDSIGNATURES)

The terms of the constraints labelled `labels` in `ocp`, as a tuple, in the order given.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if a label is given twice, or cannot be adjoined
  (see [`CTModels.Models._constraint_term`](@extref)).
"""
function _constraint_terms(ocp::Model, labels, context::String)
    seen = Symbol[]
    for label in labels
        label in seen && throw(
            Exceptions.IncorrectArgument(
                "the constraint :$label is given twice";
                got="$(collect(labels))",
                expected="each label at most once",
                context=context,
            ),
        )
        push!(seen, label)
    end
    return Tuple(_constraint_term(ocp, label, context) for label in labels)
end

# ------------------------------------------------------------------------------
# Constrained pseudo-Hamiltonian functor
# ------------------------------------------------------------------------------

"""
$(TYPEDEF)

The constrained pseudo-Hamiltonian of an optimal control problem,
`H(t, x, p, u, μ, v) = H̃(t, x, p, u, v) + Σ_k term_k(t, x, u, μ_k, v)`, where `H̃` is the
pseudo-Hamiltonian of the model and `μ = (μ_1, …, μ_K)` stacks the multipliers of the
labelled constraints, in their order. Wrapped in a `CTBase.Data.ConstrainedPseudoHamiltonian`
by [`CTBase.Data.pseudo_hamiltonian`](@extref).

# Type Parameters
- `TD`, `VD`: time and variable dependence of the model, selecting the natural arity.
- `PH`: type of the pseudo-Hamiltonian functor.
- `T`: type of the tuple of constraint terms.

# Fields
- `h̃::PH`: the pseudo-Hamiltonian of the model.
- `terms::T`: the [`CTModels.Models._ConstraintTerm`](@extref)s, one per label.
- `ranges::R`: the components of `μ` of each term, a tuple of ranges.
- `dim::Int`: the total number of components of `μ`; `μ` is a number when it is 1.

See also: [`CTModels.Models.PseudoHamiltonianFunction`](@extref).
"""
struct ConstrainedPseudoHamiltonianFunction{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    PH<:PseudoHamiltonianFunction,
    T<:Tuple,
    R<:Tuple,
} <: Function
    h̃::PH
    terms::T
    ranges::R
    dim::Int
end

"""
$(TYPEDSIGNATURES)

Build the constrained pseudo-Hamiltonian functor from the pseudo-Hamiltonian functor and
the constraint terms, computing the components of `μ` of each term.
"""
function ConstrainedPseudoHamiltonianFunction(
    h̃::PseudoHamiltonianFunction{TD,VD}, terms::Tuple
) where {TD,VD}
    dims = map(_dimension, terms)
    ends = cumsum(collect(dims))
    ranges = ntuple(k -> (ends[k] - dims[k] + 1):ends[k], length(terms))
    return ConstrainedPseudoHamiltonianFunction{
        TD,VD,typeof(h̃),typeof(terms),typeof(ranges)
    }(
        h̃, terms, ranges, sum(dims)
    )
end

"""
$(TYPEDSIGNATURES)

The multiplier of one term, read from the stacked multiplier `μ`: a number for a
one-dimensional constraint, a view otherwise.
"""
_multiplier_part(μ::Number, ::UnitRange{Int}) = μ
function _multiplier_part(μ::AbstractVector, r::UnitRange{Int})
    return length(r) == 1 ? μ[first(r)] : view(μ, r)
end

"""
$(TYPEDSIGNATURES)

Check that the stacked multiplier `μ` has `dim` components: a number when `dim == 1`, a
vector of length `dim` otherwise.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: otherwise.
"""
function _check_multiplier_dimension(h::ConstrainedPseudoHamiltonianFunction, μ)
    n = μ isa Number ? 1 : length(μ)
    (n == h.dim && (h.dim == 1 || !(μ isa Number))) || throw(
        Exceptions.IncorrectArgument(
            "the multiplier does not have the dimension of the constraints";
            got="a multiplier with $n component(s)",
            expected="$(h.dim) component(s), for $(join((":$(τ.label)" for τ in h.terms), ", ")) in this order (a number if 1)",
            context="constrained pseudo-Hamiltonian H(t, x, p, u, μ, v)",
        ),
    )
    return nothing
end

"""
$(TYPEDSIGNATURES)

Value `H̃(t, x, p, u, v) + Σ_k term_k(t, x, u, μ_k, v)`; `v === nothing` stands for a
problem without variable, whose constraints receive an empty vector.
"""
function _constrained_pseudo_H(h::ConstrainedPseudoHamiltonianFunction, t, x, p, u, μ, v)
    _check_multiplier_dimension(h, μ)
    val = _pseudo_H(h.h̃, t, x, p, u, v)
    vv = v === nothing ? _buffer_like(x, eltype(x), 0) : v
    terms = map((τ, r) -> τ(t, x, u, _multiplier_part(μ, r), vv), h.terms, h.ranges)
    return val + sum(terms)
end

"""
$(TYPEDSIGNATURES)

Call operators of [`CTModels.Models.ConstrainedPseudoHamiltonianFunction`](@extref), one
natural arity per `(TD, VD)` pair: `H(x, p, u, μ)`, `H(t, x, p, u, μ)`, `H(x, p, u, μ, v)`
and `H(t, x, p, u, μ, v)`.
"""
function (h::ConstrainedPseudoHamiltonianFunction{Traits.Autonomous,Traits.Fixed})(
    x, p, u, μ
)
    return _constrained_pseudo_H(h, 0.0, x, p, u, μ, nothing)
end
function (h::ConstrainedPseudoHamiltonianFunction{Traits.NonAutonomous,Traits.Fixed})(
    t, x, p, u, μ
)
    return _constrained_pseudo_H(h, t, x, p, u, μ, nothing)
end
function (h::ConstrainedPseudoHamiltonianFunction{Traits.Autonomous,Traits.NonFixed})(
    x, p, u, μ, v
)
    return _constrained_pseudo_H(h, 0.0, x, p, u, μ, v)
end
function (h::ConstrainedPseudoHamiltonianFunction{Traits.NonAutonomous,Traits.NonFixed})(
    t, x, p, u, μ, v
)
    return _constrained_pseudo_H(h, t, x, p, u, μ, v)
end

# ------------------------------------------------------------------------------
# Multipliers in feedback form, stacked in the order of the labels
# ------------------------------------------------------------------------------

"""
$(TYPEDEF)

The multipliers of the labelled constraints in feedback form, stacked in the order of
the labels: `(t, x, p, v) ↦ (μ_1(t, x, p, v), …, μ_K(t, x, p, v))`, a number when there is
one component in all. Its natural arity is given by `TD` and `VD`, the join of the time
and variable dependences of the multipliers.

# Fields
- `parts::M`: the `CTBase.Data.Multiplier`s, one per label, called with their uniform
  signature `μ_k(t, x, p, v)`.
- `labels::Vector{Symbol}`: the labels, for error messages.
- `dims::Vector{Int}`: the number of components of each constraint.

See also: [`CTBase.Data.hamiltonian`](@extref).
"""
struct _StackedMultiplier{
    TD<:Traits.TimeDependence,VD<:Traits.VariableDependence,M<:Tuple
} <: Function
    parts::M
    labels::Vector{Symbol}
    dims::Vector{Int}
end

"""
$(TYPEDSIGNATURES)

Value of the `k`-th multiplier, checked against the dimension of its constraint.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if it does not have the number of components of
  its constraint (a number for a one-dimensional constraint).
"""
function _checked_part(m::_StackedMultiplier, k::Int, y)
    d = m.dims[k]
    ok = d == 1 ? (y isa Number || length(y) == 1) : (!(y isa Number) && length(y) == d)
    ok || throw(
        Exceptions.IncorrectArgument(
            "the multiplier of :$(m.labels[k]) does not have the dimension of its constraint";
            got="a value with $(y isa Number ? 1 : length(y)) component(s)",
            expected="$d component(s) (a number if 1)",
            context="hamiltonian(ocp, u; multipliers) — multiplier of :$(m.labels[k])",
        ),
    )
    return d == 1 ? only(y) : y
end

"""
$(TYPEDSIGNATURES)

The stacked value of the multipliers at `(t, x, p, v)`, each checked against the
dimension of its constraint: a number if there is one component in all.
"""
function _stacked_value(m::_StackedMultiplier, t, x, p, v)
    ks = ntuple(identity, length(m.parts))
    values = map((μk, k) -> _checked_part(m, k, μk(t, x, p, v)), m.parts, ks)
    return length(values) == 1 ? only(values) : reduce(vcat, values)
end

"""
$(TYPEDSIGNATURES)

Call operators of [`CTModels.Models._StackedMultiplier`](@extref), one natural arity per
`(TD, VD)` pair: `μ(x, p)`, `μ(t, x, p)`, `μ(x, p, v)` and `μ(t, x, p, v)`.
"""
function (m::_StackedMultiplier{Traits.Autonomous,Traits.Fixed})(x, p)
    return _stacked_value(m, 0.0, x, p, nothing)
end
function (m::_StackedMultiplier{Traits.NonAutonomous,Traits.Fixed})(t, x, p)
    return _stacked_value(m, t, x, p, nothing)
end
function (m::_StackedMultiplier{Traits.Autonomous,Traits.NonFixed})(x, p, v)
    return _stacked_value(m, 0.0, x, p, v)
end
function (m::_StackedMultiplier{Traits.NonAutonomous,Traits.NonFixed})(t, x, p, v)
    return _stacked_value(m, t, x, p, v)
end

"""
$(TYPEDSIGNATURES)

The pairs `label => multiplier` of a `multipliers` argument: a `Pair`, a tuple or vector
of pairs, a `NamedTuple` or a dictionary.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: for anything else.
"""
_multiplier_pairs(spec::Pair, ::String) = [spec]
_multiplier_pairs(spec::NamedTuple, ::String) = collect(pairs(spec))
_multiplier_pairs(spec::AbstractDict, ::String) = collect(pairs(spec))
function _multiplier_pairs(spec::Union{Tuple,AbstractVector}, c::String)
    return reduce(vcat, (_multiplier_pairs(s, c) for s in spec); init=Pair[])
end
function _multiplier_pairs(spec, context::String)
    return throw(
        Exceptions.IncorrectArgument(
            "unsupported multipliers specification";
            got="$(typeof(spec))",
            expected="label => μ pairs (a Pair, a tuple of pairs, a NamedTuple or a Dict)",
            context=context,
        ),
    )
end

"""
$(TYPEDSIGNATURES)

The multiplier of the constraint `label` as a `CTBase.Data.Multiplier`: as is, or a raw
function wrapped with the time and variable dependence of `ocp` after an arity check.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if a raw function has a single method and an
  arity that is not the natural arity for `ocp`, or if it is neither.
"""
_multiplier(::Model, ::Symbol, μ::Data.Multiplier, ::String) = μ
function _multiplier(ocp::Model, label::Symbol, μ::Function, context::String)
    issue = _arity_issue(μ, ocp, "μ", "multiplier of :$label")
    issue === nothing || throw(
        Exceptions.IncorrectArgument(
            "multiplier arity mismatch";
            got=issue,
            expected="a multiplier with the time and variable dependence of the problem",
            suggestion="Pass a CTBase.Data.Multiplier built with the time and variable dependence you intend",
            context=context,
        ),
    )
    return Data.Multiplier(
        μ; is_autonomous=Traits.is_autonomous(ocp), is_variable=Traits.is_variable(ocp)
    )
end
function _multiplier(::Model, label::Symbol, μ, context::String)
    return throw(
        Exceptions.IncorrectArgument(
            "unsupported multiplier for :$label";
            got="$(typeof(μ))",
            expected="a function μ(x, p) with the natural arity of the problem, or a CTBase.Data.Multiplier",
            context=context,
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Stack the multipliers `μs` of the constraint terms `terms` into one `CTBase.Data.Multiplier`.
"""
function _stacked_multiplier(terms::Tuple, μs::Tuple)
    TD = Traits.join_time_dependence(map(Traits.time_dependence, μs)...)
    VD = Traits.join_variable_dependence(map(Traits.variable_dependence, μs)...)
    f = _StackedMultiplier{TD,VD,typeof(μs)}(
        μs, [τ.label for τ in terms], [_dimension(τ) for τ in terms]
    )
    return Data.Multiplier(f, TD, VD)
end

# ------------------------------------------------------------------------------
# Public getters with constraints
# ------------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Normalise a `constraints` argument (a `Symbol`, or a tuple or vector of `Symbol`s) into a
vector of labels.
"""
_labels(label::Symbol) = [label]
_labels(labels::Union{Tuple,AbstractVector}) = Symbol[labels...]

"""
$(TYPEDSIGNATURES)

Build the `CTBase.Data.ConstrainedPseudoHamiltonian` of `ocp` for a checked `p0` and the
constraint terms `terms`.
"""
function _constrained_pseudo_hamiltonian(ocp::Model, p0::Float64, terms::Tuple)
    h̃ = _pseudo_hamiltonian(ocp, p0).f
    TD = Traits.time_dependence(ocp)
    VD = Traits.variable_dependence(ocp)
    return Data.ConstrainedPseudoHamiltonian(
        ConstrainedPseudoHamiltonianFunction(h̃, terms), TD, VD
    )
end
