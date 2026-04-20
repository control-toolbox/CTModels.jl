# ------------------------------------------------------------------------------ #
# Mathematical definition printing
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Print the mathematical definition of an optimal control problem.

Displays the problem in standard mathematical notation with objective,
dynamics, and constraints.

When `u_dim == 0` (no control input), all control-dependent parts of the
output are suppressed:
- The objective is rendered as `J(x, v)` instead of `J(x, u, v)`.
- Dynamics arguments omit the control: `f(t, x, v)` instead of `f(t, x, u, v)`.
- The "where" clause lists only `x` (and `v` if variable-dependent).
- Box constraints on control are not listed.

# Returns

- `Bool`: `true` if something was printed.
"""
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
    is_control_free_ocp::Bool,
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
    _u = !is_control_free_ocp ? ", " * u_name * "(" * t_name * ")" : ""

    # other names
    bounds_args_names = x_name * "(" * t0_name * "), " * x_name * "(" * tf_name * ")" * _v
    mixed_args_names = t_ * x_name * "(" * t_name * ")" * _u * _v
    state_args_names = x_name * "(" * t_name * ")"
    control_args_names = u_name * "(" * t_name * ")"
    variable_args_names = v_name

    #
    some_printing && println(io)
    _print_ansi_styled(io, "The ", :default, true)
    if is_time_dependent
        _print_ansi_styled(io, "(non autonomous) ", :default, true)
    else
        _print_ansi_styled(io, "(autonomous) ", :default, true)
    end
    _print_ansi_styled(io, "optimal control problem is of the form:\n", :default, true)
    println(io)

    # J
    _print_ansi_styled(io, "    minimize  ", :blue, false)
    # Only include control in objective if !is_control_free_ocp
    u_in_obj = !is_control_free_ocp ? ", " * u_name : ""
    print(io, "J(" * x_name * u_in_obj * _v * ") = ")

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
    _print_ansi_styled(io, "    subject to\n", :blue, false)
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

    # control name and space (only if !is_control_free_ocp)
    u_name_space = ""
    if !is_control_free_ocp
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
    end

    # Build the "where" clause based on what's present
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
        # print with or without control
        if !is_control_free_ocp
            print(
                io,
                "    where ",
                x_name_space,
                ", ",
                u_name_space,
                " and ",
                v_name_space,
                ".\n",
            )
        else
            print(io, "    where ", x_name_space, " and ", v_name_space, ".\n")
        end
    else
        # print with or without control
        if !is_control_free_ocp
            print(io, "    where ", x_name_space, " and ", u_name_space, ".\n")
        else
            print(io, "    where ", x_name_space, ".\n")
        end
    end
    return true
end
