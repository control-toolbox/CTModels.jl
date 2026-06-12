# ------------------------------------------------------------------------------ #
# Base.show for PreModel
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Print the optimal control problem.
"""
function Base.show(io::IO, ::MIME"text/plain", ocp::OCP.PreModel)

    # check if the problem is empty
    OCP.__is_empty(ocp) && return nothing

    # ------------------------------------------------------------------------------ #
    # print the abstract (symbolic) definition, if any
    some_printing = _print_abstract_definition(io, ocp.definition)

    # ------------------------------------------------------------------------------ #
    # print in mathematical form

    if OCP.__is_consistent(ocp)

        # dimensions
        x_dim = OCP.dimension(ocp.state)
        u_dim = OCP.dimension(ocp.control)
        v_dim = OCP.dimension(ocp.variable)

        # names
        t_name = OCP.time_name(ocp.times)
        t0_name = OCP.initial_time_name(ocp.times)
        tf_name = OCP.final_time_name(ocp.times)
        x_name = OCP.name(ocp.state)
        u_name = OCP.name(ocp.control)
        v_name = OCP.name(ocp.variable)
        xi_names = OCP.components(ocp.state)
        ui_names = OCP.components(ocp.control)
        vi_names = OCP.components(ocp.variable)

        # dependencies
        is_variable_dependent = v_dim > 0
        is_time_dependent = !ocp.autonomous
        is_control_free_ocp = u_dim == 0

        # cost
        has_a_lagrange_cost = OCP.has_lagrange_cost(ocp.objective)
        has_a_mayer_cost = OCP.has_mayer_cost(ocp.objective)

        # constraints dimensions: path, boundary, state, control, variable, boundary
        constraints = OCP.build(ocp.constraints)
        dim_path_cons_nl = OCP.dim_path_constraints_nl(constraints)
        dim_boundary_cons_nl = OCP.dim_boundary_constraints_nl(constraints)
        dim_state_cons_box = OCP.dim_state_constraints_box(constraints)
        dim_control_cons_box = OCP.dim_control_constraints_box(constraints)
        dim_variable_cons_box = OCP.dim_variable_constraints_box(constraints)

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
function Base.show_default(io::IO, ocp::OCP.PreModel)
    return print(io, typeof(ocp))
end
