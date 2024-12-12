"""
$(TYPEDSIGNATURES)

Used to set the default value of the label of a constraint.
A unique value is given to each constraint using the `gensym` function and prefixing by `:unamed`.
"""
__constraint_label() = gensym(:unamed)

function constraint!(
    ocp_constraints::ConstraintsDictType,
    type::Symbol,
    n::Dimension,
    m::Dimension,
    q::Dimension;
    rg::Union{OrdinalRange{<:Int}, Nothing} = nothing,
    f::Union{Function, Nothing} = nothing,
    lb::Union{ctVector, Nothing} = nothing,
    ub::Union{ctVector, Nothing} = nothing,
    label::Symbol = __constraint_label(),
)

    # checkings: the constraint must not be set before
    label ∈ keys(ocp_constraints) &&
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

    # add the constraint
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
            constraint!(ocp_constraints, type, n, m, q; rg = rg, lb = lb, ub = ub, label = label)
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
            ocp_constraints[label] = (type, rg, lb, ub)
        end

        (::Nothing, ::Function, ::ctVector, ::ctVector) => begin
            # set the constraint
            if type ∈ [:boundary, :variable, :path]
                ocp_constraints[label] = (type, f, lb, ub)
            else
                throw(
                    CTBase.IncorrectArgument(
                        "the following type of constraint is not valid: " *
                        String(type) *
                        ". Please choose in [ :boundary, :variable, :path ] or check the arguments of the constraint! method.",
                    ),
                )
            end
        end

        _ => throw(CTBase.IncorrectArgument("Provided arguments are inconsistent."))
    end
    return nothing

end

function constraint!(
    ocp::PreModel,
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

    # dimensions
    n = dimension(ocp.state)
    m = dimension(ocp.control)
    q = dimension(ocp.variable)

    # add the constraint
    constraint!(ocp.constraints, type, n, m, q; rg = rg, f = f, lb = lb, ub = ub, label = label)

end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

# From ContraintsModel
constraint(ocp::Model, label::Symbol)::Tuple = ocp.constraints[label]

function constraints(ocp::Model)

    path_cons_nl_f   = Vector{Function}() # nonlinear path constraints
    path_cons_nl_dim = Vector{Int}()
    path_cons_nl_lb  = Vector{ctNumber}()
    path_cons_nl_ub  = Vector{ctNumber}()

    variable_cons_nl_f   = Vector{Function}() # nonlinear variable constraints
    variable_cons_nl_dim = Vector{Int}()
    variable_cons_nl_lb  = Vector{ctNumber}()
    variable_cons_nl_ub  = Vector{ctNumber}()

    boundary_cons_nl_f   = Vector{Function}() # nonlinear boundary constraints
    boundary_cons_nl_dim = Vector{Int}()
    boundary_cons_nl_lb  = Vector{ctNumber}()
    boundary_cons_nl_ub  = Vector{ctNumber}()

    state_cons_box_ind = Vector{Int}() # state range
    state_cons_box_lb  = Vector{ctNumber}()
    state_cons_box_ub  = Vector{ctNumber}()

    control_cons_box_ind = Vector{Int}() # control range
    control_cons_box_lb  = Vector{ctNumber}()
    control_cons_box_ub  = Vector{ctNumber}()

    variable_cons_box_ind = Vector{Int}() # variable range
    variable_cons_box_lb  = Vector{ctNumber}()
    variable_cons_box_ub  = Vector{ctNumber}()

    for (_, c) ∈ ocp.constraints
        @match c begin
            (:path, f::Function, lb, ub) => begin
                push!(path_cons_nl_f, f)
                push!(path_cons_nl_dim, length(lb))
                append!(path_cons_nl_lb, lb)
                append!(path_cons_nl_ub, ub)
            end
            (:variable, f::Function, lb, ub) => begin
                push!(variable_cons_nl_f, f)
                push!(variable_cons_nl_dim, length(lb))
                append!(variable_cons_nl_lb, lb)
                append!(variable_cons_nl_ub, ub)
            end
            (:boundary, f::Function, lb, ub) => begin
                push!(boundary_cons_nl_f, f)
                push!(boundary_cons_nl_dim, length(lb))
                append!(boundary_cons_nl_lb, lb)
                append!(boundary_cons_nl_ub, ub)
            end
            (:state, rg::OrdinalRange{<:Int}, lb, ub) => begin
                append!(state_cons_box_ind, rg)
                append!(state_cons_box_lb, lb)
                append!(state_cons_box_ub, ub)
            end
            (:control, rg::OrdinalRange{<:Int}, lb, ub) => begin
                append!(control_cons_box_ind, rg)
                append!(control_cons_box_lb, lb)
                append!(control_cons_box_ub, ub)
            end
            (:variable, rg::OrdinalRange{<:Int}, lb, ub) => begin
                append!(variable_cons_box_ind, rg)
                append!(variable_cons_box_lb, lb)
                append!(variable_cons_box_ub, ub)
            end
            _ => error("Internal error")
        end
    end

    @assert length(path_cons_nl_f) == length(path_cons_nl_dim)
    @assert length(path_cons_nl_lb) == length(path_cons_nl_ub)
    @assert length(variable_cons_nl_f) == length(variable_cons_nl_dim)
    @assert length(variable_cons_nl_lb) == length(variable_cons_nl_ub)
    @assert length(boundary_cons_nl_f) == length(boundary_cons_nl_dim)
    @assert length(boundary_cons_nl_lb) == length(boundary_cons_nl_ub)
    @assert length(state_cons_box_ind) == length(state_cons_box_lb)
    @assert length(state_cons_box_lb) == length(state_cons_box_ub)
    @assert length(control_cons_box_ind) == length(control_cons_box_lb)
    @assert length(control_cons_box_lb) == length(control_cons_box_ub)
    @assert length(variable_cons_box_ind) == length(variable_cons_box_lb)
    @assert length(variable_cons_box_lb) == length(variable_cons_box_ub)

    function path_cons_nl!(val, t, x, u, v) # nonlinear path constraints (in place)
        j = 1
        for i ∈ 1:length(path_cons_nl_f)
            li = path_cons_nl_dim[i]
            path_cons_nl_f[i](@view(val[j:(j + li - 1)]), t, x, u, v)
            j = j + li
        end
        return nothing
    end

    function variable_cons_nl!(val, v) # nonlinear variable constraints
        j = 1
        for i ∈ 1:length(variable_cons_nl_f)
            li = variable_cons_nl_dim[i]
            variable_cons_nl_f[i](@view(val[j:(j + li - 1)]), v)
            j = j + li
        end
        return nothing
    end

    function boundary_cons_nl!(val, x0, xf, v) # nonlinear boundary constraints
        j = 1
        for i ∈ 1:length(boundary_cons_nl_f)
            li = boundary_cons_nl_dim[i]
            boundary_cons_nl_f[i](@view(val[j:(j + li - 1)]), x0, xf, v)
            j = j + li
        end
        return nothing
    end

    return (path_cons_nl_lb, path_cons_nl!, path_cons_nl_ub),
    (variable_cons_nl_lb, variable_cons_nl!, variable_cons_nl_ub),
    (boundary_cons_nl_lb, boundary_cons_nl!, boundary_cons_nl_ub),
    (state_cons_box_lb,    state_cons_box_ind,    state_cons_box_ub),
    (control_cons_box_lb,  control_cons_box_ind,  control_cons_box_ub),
    (variable_cons_box_lb, variable_cons_box_ind, variable_cons_box_ub)

end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear path constraints.
"""
function dim_path_cons_nl(ocp::Model)

    dim = 0
    for (_, c) ∈ ocp.constraints
        dim += @match c begin
            (:path, f::Function, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end

"""
$(TYPEDSIGNATURES)

Return the dimension of the boundary constraints.
"""
function dim_boundary_cons_nl(ocp::Model) 

    dim = 0
    for (_, c) ∈ ocp.constraints
        dim += @match c begin
            (:boundary, f::Function, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear variable constraints.
"""
function dim_variable_cons_nl(ocp::Model)

    dim = 0
    for (_, c) ∈ ocp.constraints
        dim += @match c begin
            (:variable, f::Function, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on state.
"""
function dim_state_cons_box(ocp::Model)

    dim = 0
    for (_, c) ∈ ocp.constraints
        dim += @match c begin
            (:state, rg::OrdinalRange{<:Int}, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on control.
"""
function dim_control_cons_box(ocp::Model)

    dim = 0
    for (_, c) ∈ ocp.constraints
        dim += @match c begin
            (:control, rg::OrdinalRange{<:Int}, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on variable.
"""
function dim_variable_cons_box(ocp::Model)

    dim = 0
    for (_, c) ∈ ocp.constraints
        dim += @match c begin
            (:variable, rg::OrdinalRange{<:Int}, lb, ub) => length(lb)
            _ => 0
        end
    end
    return dim

end