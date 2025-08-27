# ------------------------------------------------------------------------------ #
# PRINT
# ------------------------------------------------------------------------------ #
function __print(e::Expr, io::IO, l::Int)
    @match e begin
        :(($a, $b)) => println(io, " "^l, a, ", ", b)
        _ => println(io, " "^l, e)
    end
end

function __print_abstract_definition(io::IO, ocp::Union{Model,PreModel})
    @assert hasproperty(definition(ocp), :head)
    printstyled(io, "Abstract defintion:\n\n"; bold=true)
    tab = 4
    code = striplines(definition(ocp))
    @match code.head begin
        :block => [__print(code.args[i], io, tab) for i in eachindex(code.args)]
        _ => __print(code, io, tab)
    end
    return true
end

function __print_mathematical_definition(
    io::IO,
    some_printing::Bool,
    # dimensions
    x_dim::Int,
    u_dim::Int,
    v_dim::Int,
    # names
    t_name::String,
    t0_name::String,
    tf_name::String,
    x_name::String,
    u_name::String,
    v_name::String,
    xi_names::Vector{String},
    ui_names::Vector{String},
    vi_names::Vector{String},
    # dependencies
    is_variable_dependent::Bool,
    is_time_dependent::Bool,
    # cost
    has_a_lagrange_cost::Bool,
    has_a_mayer_cost::Bool,
    # constraints dimensions
    dim_path_cons_nl::Int,
    dim_boundary_cons_nl::Int,
    dim_state_cons_box::Int,
    dim_control_cons_box::Int,
    dim_variable_cons_box::Int,
)

    # args
    t_ = is_time_dependent ? t_name * ", " : ""
    _v = is_variable_dependent ? ", " * v_name : ""

    # other names
    bounds_args_names = x_name * "(" * t0_name * "), " * x_name * "(" * tf_name * ")" * _v
    mixed_args_names = t_ * x_name * "(" * t_name * "), " * u_name * "(" * t_name * ")" * _v
    state_args_names = x_name * "(" * t_name * ")"
    control_args_names = u_name * "(" * t_name * ")"
    variable_args_names = v_name

    #
    some_printing && println(io)
    printstyled(io, "The "; bold=true)
    if is_time_dependent
        printstyled(io, "(non autonomous) "; bold=true)
    else
        printstyled(io, "(autonomous) "; bold=true)
    end
    printstyled(io, "optimal control problem is of the form:\n"; bold=true)
    println(io)

    # J
    printstyled(io, "    minimize  "; color=:blue)
    print(io, "J(" * x_name * ", " * u_name * _v * ") = ")

    # Mayer
    has_a_mayer_cost && print(io, "g(" * bounds_args_names * ")")
    (has_a_mayer_cost && has_a_lagrange_cost) && print(io, " + ")

    # Lagrange
    if has_a_lagrange_cost
        println(
            io,
            '\u222B',
            " f⁰(" *
            mixed_args_names *
            ") d" *
            t_name *
            ", over [" *
            t0_name *
            ", " *
            tf_name *
            "]",
        )
    else
        println(io, "")
    end

    # constraints
    println(io, "")
    printstyled(io, "    subject to\n"; color=:blue)
    println(io, "")

    # dynamics
    println(
        io,
        "        " * x_name,
        '\u0307',
        "(" *
        t_name *
        ") = f(" *
        mixed_args_names *
        "), " *
        t_name *
        " in [" *
        t0_name *
        ", " *
        tf_name *
        "] a.e.,",
    )
    println(io, "")

    # constraints
    has_constraints = false
    if dim_path_cons_nl > 0
        has_constraints = true
        println(io, "        ψ₋ ≤ ψ(" * mixed_args_names * ") ≤ ψ₊, ")
    end
    if dim_boundary_cons_nl > 0
        has_constraints = true
        println(io, "        ϕ₋ ≤ ϕ(" * bounds_args_names * ") ≤ ϕ₊, ")
    end
    if dim_state_cons_box > 0
        has_constraints = true
        println(io, "        x₋ ≤ " * state_args_names * " ≤ x₊, ")
    end
    if dim_control_cons_box > 0
        has_constraints = true
        println(io, "        u₋ ≤ " * control_args_names * " ≤ u₊, ")
    end
    if dim_variable_cons_box > 0
        has_constraints = true
        println(io, "        v₋ ≤ " * variable_args_names * " ≤ v₊, ")
    end
    has_constraints ? println(io, "") : nothing

    # spaces
    x_space = "R" * (x_dim == 1 ? "" : CTBase.ctupperscripts(x_dim))
    u_space = "R" * (u_dim == 1 ? "" : CTBase.ctupperscripts(u_dim))

    # state name and space
    if x_dim == 1
        x_name_space = x_name * "(" * t_name * ")"
    else
        x_name_space = x_name * "(" * t_name * ")"
        if xi_names != [x_name * CTBase.ctindices(i) for i in range(1, x_dim)]
            x_name_space *= " = ("
            for i in 1:x_dim
                x_name_space *= xi_names[i] * "(" * t_name * ")"
                i < x_dim && (x_name_space *= ", ")
            end
            x_name_space *= ")"
        end
    end
    x_name_space *= " ∈ " * x_space

    # control name and space
    if u_dim == 1
        u_name_space = u_name * "(" * t_name * ")"
    else
        u_name_space = u_name * "(" * t_name * ")"
        if ui_names != [u_name * CTBase.ctindices(i) for i in range(1, u_dim)]
            u_name_space *= " = ("
            for i in 1:u_dim
                u_name_space *= ui_names[i] * "(" * t_name * ")"
                i < u_dim && (u_name_space *= ", ")
            end
            u_name_space *= ")"
        end
    end
    u_name_space *= " ∈ " * u_space

    if is_variable_dependent
        # space
        v_space = "R" * (v_dim == 1 ? "" : CTBase.ctupperscripts(v_dim))
        # variable name and space
        if v_dim == 1
            v_name_space = v_name
        else
            v_name_space = v_name
            if vi_names != [v_name * CTBase.ctindices(i) for i in range(1, v_dim)]
                v_name_space *= " = ("
                for i in 1:v_dim
                    v_name_space *= vi_names[i]
                    i < v_dim && (v_name_space *= ", ")
                end
                v_name_space *= ")"
            end
        end
        v_name_space *= " ∈ " * v_space
        # print
        print(
            io, "    where ", x_name_space, ", ", u_name_space, " and ", v_name_space, ".\n"
        )
    else
        # print
        print(io, "    where ", x_name_space, " and ", u_name_space, ".\n")
    end
    return true
end

"""
$(TYPEDSIGNATURES)

Print the optimal control problem.
"""
function Base.show(io::IO, ::MIME"text/plain", ocp::Model)

    # ------------------------------------------------------------------------------ #
    # print the code
    some_printing = __print_abstract_definition(io, ocp)

    # ------------------------------------------------------------------------------ #
    # print in mathematical form

    # dimensions
    x_dim = state_dimension(ocp)
    u_dim = control_dimension(ocp)
    v_dim = variable_dimension(ocp)

    # names
    t_name = time_name(ocp)
    t0_name = initial_time_name(ocp)
    tf_name = final_time_name(ocp)
    x_name = state_name(ocp)
    u_name = control_name(ocp)
    v_name = variable_name(ocp)
    xi_names = state_components(ocp)
    ui_names = control_components(ocp)
    vi_names = variable_components(ocp)

    # dependencies
    is_variable_dependent = v_dim > 0
    is_time_dependent = !is_autonomous(ocp)

    # cost
    has_a_lagrange_cost = has_lagrange_cost(ocp)
    has_a_mayer_cost = has_mayer_cost(ocp)

    # constraints dimensions: path, boundary, state, control, variable, boundary
    dim_path_cons_nl = dim_path_constraints_nl(ocp)
    dim_boundary_cons_nl = dim_boundary_constraints_nl(ocp)
    dim_state_cons_box = dim_state_constraints_box(ocp)
    dim_control_cons_box = dim_control_constraints_box(ocp)
    dim_variable_cons_box = dim_variable_constraints_box(ocp)

    #
    some_printing = __print_mathematical_definition(
        io,
        some_printing,
        x_dim,
        u_dim,
        v_dim,
        t_name,
        t0_name,
        tf_name,
        x_name,
        u_name,
        v_name,
        xi_names,
        ui_names,
        vi_names,
        is_variable_dependent,
        is_time_dependent,
        has_a_lagrange_cost,
        has_a_mayer_cost,
        dim_path_cons_nl,
        dim_boundary_cons_nl,
        dim_state_cons_box,
        dim_control_cons_box,
        dim_variable_cons_box,
    )

    #
    return nothing
end

function Base.show_default(io::IO, ocp::Model)
    return print(io, typeof(ocp))
end

# ------------------------------------------------------------------------------ #
# PreModel

"""
$(TYPEDSIGNATURES)

Print the optimal control problem.
"""
function Base.show(io::IO, ::MIME"text/plain", ocp::PreModel)

    # check if the problem is empty
    __is_empty(ocp) && return nothing

    #
    some_printing = false

    if __is_definition_set(ocp)
        # ------------------------------------------------------------------------------ #
        # print the code
        some_printing = __print_abstract_definition(io, ocp)
    end

    # ------------------------------------------------------------------------------ #
    # print in mathematical form

    if __is_consistent(ocp)

        # dimensions
        x_dim = dimension(ocp.state)
        u_dim = dimension(ocp.control)
        v_dim = dimension(ocp.variable)

        # names
        t_name = time_name(ocp.times)
        t0_name = initial_time_name(ocp.times)
        tf_name = final_time_name(ocp.times)
        x_name = name(ocp.state)
        u_name = name(ocp.control)
        v_name = name(ocp.variable)
        xi_names = components(ocp.state)
        ui_names = components(ocp.control)
        vi_names = components(ocp.variable)

        # dependencies
        is_variable_dependent = v_dim > 0
        is_time_dependent = !is_autonomous(ocp)

        # cost
        has_a_lagrange_cost = has_lagrange_cost(ocp.objective)
        has_a_mayer_cost = has_mayer_cost(ocp.objective)

        # constraints dimensions: path, boundary, state, control, variable, boundary
        constraints = build(ocp.constraints)
        dim_path_cons_nl = dim_path_constraints_nl(constraints)
        dim_boundary_cons_nl = dim_boundary_constraints_nl(constraints)
        dim_state_cons_box = dim_state_constraints_box(constraints)
        dim_control_cons_box = dim_control_constraints_box(constraints)
        dim_variable_cons_box = dim_variable_constraints_box(constraints)

        #
        some_printing = __print_mathematical_definition(
            io,
            some_printing,
            x_dim,
            u_dim,
            v_dim,
            t_name,
            t0_name,
            tf_name,
            x_name,
            u_name,
            v_name,
            xi_names,
            ui_names,
            vi_names,
            is_variable_dependent,
            is_time_dependent,
            has_a_lagrange_cost,
            has_a_mayer_cost,
            dim_path_cons_nl,
            dim_boundary_cons_nl,
            dim_state_cons_box,
            dim_control_cons_box,
            dim_variable_cons_box,
        )
    end

    return nothing
end

"""
$(TYPEDSIGNATURES)

"""
function Base.show_default(io::IO, ocp::PreModel)
    return print(io, typeof(ocp))
end
