# ------------------------------------------------------------------------------ #
# Base.show for Model
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Print the optimal control problem.
"""
function Base.show(io::IO, ::MIME"text/plain", ocp::Models.Model)

    # ------------------------------------------------------------------------------ #
    # print the abstract (symbolic) definition, if any
    some_printing = _print_abstract_definition(io, Models.definition(ocp))

    # ------------------------------------------------------------------------------ #
    # print in mathematical form

    # dimensions
    x_dim = Models.state_dimension(ocp)
    u_dim = Models.control_dimension(ocp)
    v_dim = Models.variable_dimension(ocp)

    # names
    t_name = Components.time_name(ocp)
    t0_name = Components.initial_time_name(ocp)
    tf_name = Components.final_time_name(ocp)
    x_name = Models.state_name(ocp)
    u_name = Models.control_name(ocp)
    v_name = Models.variable_name(ocp)
    xi_names = Models.state_components(ocp)
    ui_names = Models.control_components(ocp)
    vi_names = Models.variable_components(ocp)

    # dependencies
    is_variable_dependent = Models.is_variable(ocp)
    is_time_dependent = !Models.is_autonomous(ocp)
    is_control_free_ocp = Models.is_control_free(ocp)

    # cost
    has_a_lagrange_cost = Components.has_lagrange_cost(ocp)
    has_a_mayer_cost = Components.has_mayer_cost(ocp)

    # constraints dimensions: path, boundary, state, control, variable, boundary
    dim_path_cons_nl = Components.dim_path_constraints_nl(ocp)
    dim_boundary_cons_nl = Components.dim_boundary_constraints_nl(ocp)
    dim_state_cons_box = Components.dim_state_constraints_box(ocp)
    dim_control_cons_box = Components.dim_control_constraints_box(ocp)
    dim_variable_cons_box = Components.dim_variable_constraints_box(ocp)

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

    #
    return nothing
end

"""
$(TYPEDSIGNATURES)

Default show method for a [`Model`](@ref CTModels.Models.Model).

Prints only the type name.
"""
function Base.show_default(io::IO, ocp::Models.Model)
    return print(io, typeof(ocp))
end
