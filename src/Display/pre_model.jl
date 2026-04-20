# ------------------------------------------------------------------------------ #
# Base.show for PreModel
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Print the optimal control problem.
"""
function Base.show(io::IO, ::MIME"text/plain", ocp::PreModel)

    # check if the problem is empty
    __is_empty(ocp) && return nothing

    # ------------------------------------------------------------------------------ #
    # print the abstract (symbolic) definition, if any
    some_printing = _print_abstract_definition(io, ocp.definition)

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
        is_time_dependent = !ocp.autonomous
        is_control_free_ocp = u_dim == 0

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
            is_control_free_ocp,
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

Default show method for a `PreModel`.

Prints only the type name.
"""
function Base.show_default(io::IO, ocp::PreModel)
    return print(io, typeof(ocp))
end
