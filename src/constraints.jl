"""
$(TYPEDSIGNATURES)

Used to set the default value of the label of a constraint.
A unique value is given to each constraint using the `gensym` function and prefixing by `:unamed`.
"""
__constraint_label() = gensym(:unamed)

function constraint!(
    ocp::OptimalControlModelMutable,
    type::Symbol;
    rg::Union{OrdinalRange{<:Int}, Nothing} = nothing,
    f::Union{Function, Nothing} = nothing,
    lb::Union{ctVector, Nothing} = nothing,
    ub::Union{ctVector, Nothing} = nothing,
    label::Symbol = __constraint_label(),
)

    # checkings: times, state and control must be set before adding constraints
    !__is_state_set(ocp) && throw(CTBase.UnauthorizedCall("the state must be set before adding constraints."))
    !__is_control_set(ocp) && throw(CTBase.UnauthorizedCall("the control must be set before adding constraints."))
    !__is_times_set(ocp) && throw(CTBase.UnauthorizedCall("the times must be set before adding constraints."))

    # checkings: if the ocp has no variable, then the constraint! function cannot be used with type=:variable
    !__is_variable_set(ocp) && type == :variable &&
        throw(
            CTBase.UnauthorizedCall(
                "the ocp has no variable" *
                ", you cannot use constraint! function with type=:variable. If it is a mistake, please set the variable first.",
            ),
        )

    # checkings: the constraint must not be set before
    label ∈ constraints_labels(ocp) &&
        throw(CTBase.UnauthorizedCall("the constraint named " * String(label) * " already exists."))

    # checkings: lb and ub cannot be both nothing
    (isnothing(lb) && isnothing(ub)) &&
        throw(CTBase.UnauthorizedCall("The lower bound `lb` and the upper bound `ub` cannot be both nothing."))

    # bounds
    isnothing(lb) && (lb = -Inf * ones(eltype(ub), length(ub)))
    isnothing(ub) && (ub = Inf * ones(eltype(lb), length(lb)))

    # lb and ub must have the same length
    length(lb) != length(ub) &&
        throw(CTBase.IncorrectArgument("the lower bound `lb` and the upper bound `ub` must have the same length."))

    # dimensions
    n = dimension(ocp.state)
    m = dimension(ocp.control)
    q = dimension(ocp.variable)

    @match (rg, f, lb, ub) begin

        (::Nothing, ::Nothing, ::ctVector, ::ctVector) => begin
            if type == :state
                rg = 1:n
                txt = "the lower bound `lb` and the upper bound `ub` must be of dimension $n"
            elseif type == :control
                rg = 1:m
                txt = "the lower bound `lb` and the upper bound `ub` must be of dimension $m"
            elseif type == :variable
                rg = 1:q
                txt = "the lower bound `lb` and the upper bound `ub` must be of dimension $q"
            else
                throw(
                    CTBase.IncorrectArgument(
                        "the following type of constraint is not valid: " *
                        String(type) *
                        ". Please choose in [ :control, :state, :variable ] or check the arguments of the constraint! method.",
                    ),
                )
            end
            (length(rg) != length(lb)) && throw(CTBase.IncorrectArgument(txt))
            constraint!(ocp, type; rg = rg, lb = lb, ub = ub, label = label)
        end

        (::OrdinalRange{<:Int}, ::Nothing, ::ctVector, ::ctVector) => begin
            txt = "the range `rg`, the lower bound `lb` and the upper bound `ub` must have the same dimension"
            (length(rg) != length(lb)) && throw(CTBase.IncorrectArgument(txt))
            # check if the range is valid
            if type == :state
                !all(1 .≤ rg .≤ n) && throw(
                    CTBase.IncorrectArgument(
                        "the range of the state constraint must be contained in 1:$n",
                    ),
                )
            elseif type == :control
                !all(1 .≤ rg .≤ m) && throw(
                    CTBase.IncorrectArgument(
                        "the range of the control constraint must be contained in 1:$m",
                    ),
                )
            elseif type == :variable
                !all(1 .≤ rg .≤ q) && throw(
                    CTBase.IncorrectArgument(
                        "the range of the variable constraint must be contained in 1:$q",
                    ),
                )
            else 
                throw(
                    CTBase.IncorrectArgument(
                        "the following type of constraint is not valid: " *
                        String(type) *
                        ". Please choose in [ :control, :state, :variable ] or check the arguments of the constraint! method.",
                    ),
                )
            end
            # set the constraint
            ocp.constraints[label] = (type, rg, lb, ub)
        end

        (::Nothing, ::Function, ::ctVector, ::ctVector) => begin
            # set the constraint
            if type ∈ [:boundary, :control, :state, :variable, :mixed]
                ocp.constraints[label] = (type, f, lb, ub)
            else
                throw(
                    CTBase.IncorrectArgument(
                        "the following type of constraint is not valid: " *
                        String(type) *
                        ". Please choose in [ :boundary, :control, :state, :variable, :mixed ] or check the arguments of the constraint! method.",
                    ),
                )
            end
        end

        _ => throw(CTBase.IncorrectArgument("Provided arguments are inconsistent."))
    end
    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

# From ContraintsModel
constraints_labels(ocp::OptimalControlModelMutable) = keys(ocp.constraints)

# From OptimalControlModel
# (constraints(model::OptimalControlModel{T, S, C, V, D, O, B})::B) where {
#     T<:AbstractTimesModel,
#     S<:AbstractStateModel, 
#     C<:AbstractControlModel, 
#     V<:AbstractVariableModel, 
#     D<:Function,
#     O<:AbstractObjectiveModel,
#     B<:ConstraintsTypeAlias} = model.constraints

constraint(ocp::OptimalControlModel, label::Symbol)::Tuple = ocp.constraints[label]

function constraints(ocp::OptimalControlModel)

    ηf = Vector{Function}() # nonlinear state constraints
    ηs = Vector{Int}()
    ηl = Vector{ctNumber}()
    ηu = Vector{ctNumber}()

    ξf = Vector{Function}() # nonlinear control constraints
    ξs = Vector{Int}()
    ξl = Vector{ctNumber}()
    ξu = Vector{ctNumber}()

    θf = Vector{Function}() # nonlinear variable constraints
    θs = Vector{Int}()
    θl = Vector{ctNumber}()
    θu = Vector{ctNumber}()

    ψf = Vector{Function}() # nonlinear mixed constraints
    ψs = Vector{Int}()
    ψl = Vector{ctNumber}()
    ψu = Vector{ctNumber}()

    ϕf = Vector{Function}() # nonlinear boundary constraints
    ϕs = Vector{Int}()
    ϕl = Vector{ctNumber}()
    ϕu = Vector{ctNumber}()

    xind = Vector{Int}() # state range
    xl = Vector{ctNumber}()
    xu = Vector{ctNumber}()

    uind = Vector{Int}() # control range
    ul = Vector{ctNumber}()
    uu = Vector{ctNumber}()

    vind = Vector{Int}() # variable range
    vl = Vector{ctNumber}()
    vu = Vector{ctNumber}()

    for (_, c) ∈ ocp.constraints
        @match c begin
            (:state, f::Function, lb, ub) => begin
                push!(ηf, f)
                push!(ηs, length(lb))
                append!(ηl, lb)
                append!(ηu, ub)
            end
            (:state, rg::OrdinalRange{<:Int}, lb, ub) => begin
                append!(xind, rg)
                append!(xl, lb)
                append!(xu, ub)
            end
            (:control, f::Function, lb, ub) => begin
                push!(ξf, f)
                push!(ξs, length(lb))
                append!(ξl, lb)
                append!(ξu, ub)
            end
            (:control, rg::OrdinalRange{<:Int}, lb, ub) => begin
                append!(uind, rg)
                append!(ul, lb)
                append!(uu, ub)
            end
            (:variable, f::Function, lb, ub) => begin
                push!(θf, f)
                push!(θs, length(lb))
                append!(θl, lb)
                append!(θu, ub)
            end
            (:variable, rg::OrdinalRange{<:Int}, lb, ub) => begin
                append!(vind, rg)
                append!(vl, lb)
                append!(vu, ub)
            end
            (:mixed, f::Function, lb, ub) => begin
                push!(ψf, f)
                push!(ψs, length(lb))
                append!(ψl, lb)
                append!(ψu, ub)
            end
            (:boundary, f::Function, lb, ub) => begin
                push!(ϕf, f)
                push!(ϕs, length(lb))
                append!(ϕl, lb)
                append!(ϕu, ub)
            end
            _ => error("Internal error")
        end
    end

    @assert length(ξl) == length(ξu)
    @assert length(ξf) == length(ξs)
    @assert length(ηl) == length(ηu)
    @assert length(ηf) == length(ηs)
    @assert length(ψl) == length(ψu)
    @assert length(ψf) == length(ψs)
    @assert length(ϕl) == length(ϕu)
    @assert length(ϕf) == length(ϕs)
    @assert length(θl) == length(θu)
    @assert length(θf) == length(θs)
    @assert length(ul) == length(uu)
    @assert length(xl) == length(xu)
    @assert length(vl) == length(vu)

    function η!(val, t, x, v) # nonlinear state constraints (in place)
        j = 1
        for i ∈ 1:length(ηf)
            li = ηs[i]
            ηf[i](@view(val[j:(j + li - 1)]), t, x, v)
            j = j + li
        end
        return nothing
    end

    function ξ!(val, t, u, v) # nonlinear control constraints (in place)
        j = 1
        for i ∈ 1:length(ξf)
            li = ξs[i]
            ξf[i](@view(val[j:(j + li - 1)]), t, u, v)
            j = j + li
        end
        return nothing
    end

    function θ!(val, v) # nonlinear variable constraints
        j = 1
        for i ∈ 1:length(θf)
            li = θs[i]
            θf[i](@view(val[j:(j + li - 1)]), v)
            j = j + li
        end
        return nothing
    end

    function ψ!(val, t, x, u, v) # nonlinear mixed constraints (in place)
        j = 1
        for i ∈ 1:length(ψf)
            li = ψs[i]
            ψf[i](@view(val[j:(j + li - 1)]), t, x, u, v)
            j = j + li
        end
        return nothing
    end

    function ϕ!(val, x0, xf, v) # nonlinear boundary constraints
        j = 1
        for i ∈ 1:length(ϕf)
            li = ϕs[i]
            ϕf[i](@view(val[j:(j + li - 1)]), x0, xf, v)
            j = j + li
        end
        return nothing
    end

    return (ξl, ξ!, ξu),
    (ηl, η!, ηu),
    (ψl, ψ!, ψu),
    (ϕl, ϕ!, ϕu),
    (θl, θ!, θu),
    (ul, uind, uu),
    (xl, xind, xu),
    (vl, vind, vu)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear state constraints.
"""
function dim_state_constraints(ocp::OptimalControlModel)

    dim = 0
    for (_, c) ∈ constraints(ocp)
        dim += @match c begin
            (:state, f::Function, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear control constraints.
"""
function dim_control_constraints(ocp::OptimalControlModel)

    dim = 0
    for (_, c) ∈ constraints(ocp)
        dim += @match c begin
            (:control, f::Function, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear variable constraints.
"""
function dim_variable_constraints(ocp::OptimalControlModel)

    dim = 0
    for (_, c) ∈ constraints(ocp)
        dim += @match c begin
            (:variable, f::Function, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear mixed constraints.
"""
function dim_mixed_constraints(ocp::OptimalControlModel)

    dim = 0
    for (_, c) ∈ constraints(ocp)
        dim += @match c begin
            (:mixed, f::Function, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear path (state + control + mixed) constraints.
"""
function dim_path_constraints(ocp::OptimalControlModel)
    return dim_state_constraints(ocp) + dim_control_constraints(ocp) + dim_mixed_constraints(ocp)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the boundary constraints.
"""
function dim_boundary_constraints(ocp::OptimalControlModel) 

    dim = 0
    for (_, c) ∈ constraints(ocp)
        dim += @match c begin
            (:boundary, f::Function, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end

"""
$(TYPEDSIGNATURES)

Return the dimension of range constraints on state.
"""
function dim_state_range(ocp::OptimalControlModel)

    dim = 0
    for (_, c) ∈ constraints(ocp)
        dim += @match c begin
            (:state, rg::OrdinalRange{<:Int}, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end

"""
$(TYPEDSIGNATURES)

Return the dimension of range constraints on control.
"""
function dim_control_range(ocp::OptimalControlModel)

    dim = 0
    for (_, c) ∈ constraints(ocp)
        dim += @match c begin
            (:control, rg::OrdinalRange{<:Int}, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end

"""
$(TYPEDSIGNATURES)

Return the dimension of range constraints on variable.
"""
function dim_variable_range(ocp::OptimalControlModel)

    dim = 0
    for (_, c) ∈ constraints(ocp)
        dim += @match c begin
            (:variable, rg::OrdinalRange{<:Int}, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end