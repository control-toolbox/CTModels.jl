# ------------------------------------------------------------------------------ #
# SETTER
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Set the model definition of the optimal control problem.

"""
function definition!(ocp::PreModel, definition::Expr)::Nothing
    ocp.definition = definition
    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the model definition of the optimal control problem.

"""
function definition(ocp::Model)::Expr
    return ocp.definition
end

"""
$(TYPEDSIGNATURES)

Return the model definition of the optimal control problem or `nothing`.

"""
function definition(ocp::PreModel)
    return ocp.definition
end

# ------------------------------------------------------------------------------ #
# PRINT
# ------------------------------------------------------------------------------ #
function __print(e::Expr, io::IO, l::Int)
    @match e begin
        :(($a, $b)) => println(io, " "^l, a, ", ", b)
        _ => println(io, " "^l, e)
    end
end

"""
$(TYPEDSIGNATURES)

Print the optimal control problem.
"""
function Base.show(io::IO, ::MIME"text/plain", ocp::Model)

    # some checks
    @assert hasproperty(definition(ocp), :head)

    # ------------------------------------------------------------------------------ #
    # print the code
    tab = 4
    code = striplines(definition(ocp))
    @match code.head begin
        :block => [__print(code.args[i], io, tab) for i in eachindex(code.args)]
        _ => __print(code, io, tab)
    end

    #
    some_printing = true

    # ------------------------------------------------------------------------------ #
    # print in mathematical form

    # dimensions
    x_dim = state_dimension(ocp)
    u_dim = control_dimension(ocp)
    v_dim = variable_dimension(ocp)

    is_variable_dependent = v_dim > 0

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
    t_ = !is_autonomous(ocp) ? t_name * ", " : "" 
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
    !is_autonomous(ocp) ? 
	    printstyled(io, "(non autonomous) ", bold = true) :
	    printstyled(io, "(autonomous) ", bold = true)
    printstyled(io, "optimal control problem is of the form:\n"; bold=true)
    println(io)

    # J
    printstyled(io, "    minimize  "; color=:blue)
    print(io, "J(" * x_name * ", " * u_name * _v * ") = ")

    # Mayer
    has_mayer_cost(ocp) && print(io, "g(" * bounds_args_names * ")")
    (has_mayer_cost(ocp) && has_lagrange_cost(ocp)) && print(io, " + ")

    # Lagrange
    if has_lagrange_cost(ocp)
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

    # other constraints: path, boundary, state, control, variable, boundary
    dim_path_cons_nl = dim_path_constraints_nl(ocp)
    dim_boundary_cons_nl = dim_boundary_constraints_nl(ocp)
    dim_state_cons_box = dim_state_constraints_box(ocp)
    dim_control_cons_box = dim_control_constraints_box(ocp)
    dim_variable_cons_box = dim_variable_constraints_box(ocp)

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

    some_printing = true

    # ------------------------------------------------------------------------------ #
    # print summary table

    #
    some_printing && println(io)
    printstyled(io, "Declarations "; bold=true)
    printstyled(io, "(* required):\n"; bold=false)
    #println(io)

    # print table of settings
    header = [
        "times*", "state*", "control*", "variable", "dynamics*", "objective*", "constraints"
    ]
    data = hcat(
        __is_times_set(ocp) ? "V" : "X",
        __is_state_set(ocp) ? "V" : "X",
        __is_control_set(ocp) ? "V" : "X",
    )
    begin
        (data = hcat(data, is_variable_dependent ? "V" : "X"))
    end
    data = hcat(
        data,
        __is_dynamics_set(ocp) ? "V" : "X",
        __is_objective_set(ocp) ? "V" : "X",
        isempty_constraints(ocp) ? "X" : "V",
    )
    println("")
    h1 = Highlighter((data, i, j) -> data[i, j] == "X"; bold=true, foreground=:red)
    h2 = Highlighter((data, i, j) -> data[i, j] == "V"; bold=true, foreground=:green)
    pretty_table(
        io,
        data;
        tf=tf_unicode_rounded,
        header=header,
        header_crayon=crayon"yellow",
        crop=:none,
        highlighters=(h1, h2),
        alignment=:c,
        compact_printing=true,
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

        # some checks
        @assert hasproperty(definition(ocp), :head)

        # ------------------------------------------------------------------------------ #
        # print the code
        tab = 4
        code = striplines(definition(ocp))
        @match code.head begin
            :block => [__print(code.args[i], io, tab) for i in eachindex(code.args)]
            _ => __print(code, io, tab)
        end

        #
        some_printing = true
    end

    # ------------------------------------------------------------------------------ #
    # print in mathematical form

    v_dim = dimension(ocp.variable)
    is_variable_dependent = v_dim > 0

    if __is_consistent(ocp)

        # dimensions
        x_dim = dimension(ocp.state)
        u_dim = dimension(ocp.control)

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
        t_ = !is_autonomous(ocp) ? t_name * ", " : "" 
        _v = is_variable_dependent ? ", " * v_name : ""

        # other names
        bounds_args_names =
            x_name * "(" * t0_name * "), " * x_name * "(" * tf_name * ")" * _v
        mixed_args_names =
            t_ * x_name * "(" * t_name * "), " * u_name * "(" * t_name * ")" * _v
        state_args_names = x_name * "(" * t_name * ")"
        control_args_names = u_name * "(" * t_name * ")"
        variable_args_names = v_name

        #
        some_printing && println(io)
        printstyled(io, "The "; bold=true)
        !is_autonomous(ocp) ? 
            printstyled(io, "(non autonomous) ", bold = true) :
            printstyled(io, "(autonomous) ", bold = true)
        printstyled(io, "optimal control problem is of the form:\n"; bold=true)
        println(io)

        # J
        printstyled(io, "    minimize  "; color=:blue)
        print(io, "J(" * x_name * ", " * u_name * _v * ") = ")

        # Mayer
        has_mayer_cost(ocp.objective) && print(io, "g(" * bounds_args_names * ")")
        (has_mayer_cost(ocp.objective) && has_lagrange_cost(ocp.objective)) &&
            print(io, " + ")

        # Lagrange
        if has_lagrange_cost(ocp.objective)
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

        # other constraints: path, boundary, state, control, variable, boundary
        constraints = build_constraints(ocp.constraints)
        dim_path_cons_nl = dim_path_constraints_nl(constraints)
        dim_boundary_cons_nl = dim_boundary_constraints_nl(constraints)
        dim_state_cons_box = dim_state_constraints_box(constraints)
        dim_control_cons_box = dim_control_constraints_box(constraints)
        dim_variable_cons_box = dim_variable_constraints_box(constraints)
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
            # print
            print(io, "    where ", x_name_space, " and ", u_name_space, ".\n")
        end

        some_printing = true
    end

    # ------------------------------------------------------------------------------ #
    # print summary table

    #
    some_printing && println(io)
    printstyled(io, "Declarations "; bold=true)
    printstyled(io, "(* required):\n"; bold=false)
    #println(io)

    # print table of settings
    header = [
        "times*", "state*", "control*", "variable", "dynamics*", "objective*", "constraints"
    ]
    data = hcat(
        __is_times_set(ocp) ? "V" : "X",
        __is_state_set(ocp) ? "V" : "X",
        __is_control_set(ocp) ? "V" : "X",
    )
    begin
        (data = hcat(data, is_variable_dependent ? "V" : "X"))
    end
    data = hcat(
        data,
        __is_dynamics_set(ocp) ? "V" : "X",
        __is_objective_set(ocp) ? "V" : "X",
        Base.isempty(ocp.constraints) ? "X" : "V",
    )
    println("")
    h1 = Highlighter((data, i, j) -> data[i, j] == "X"; bold=true, foreground=:red)
    h2 = Highlighter((data, i, j) -> data[i, j] == "V"; bold=true, foreground=:green)
    pretty_table(
        io,
        data;
        tf=tf_unicode_rounded,
        header=header,
        header_crayon=crayon"yellow",
        crop=:none,
        highlighters=(h1, h2),
        alignment=:c,
        compact_printing=true,
    )

    #
    return nothing
end

"""
$(TYPEDSIGNATURES)

"""
function Base.show_default(io::IO, ocp::PreModel)
    return print(io, typeof(ocp))
end
