# ------------------------------------------------------------------------------ #
# Base.show for Model
# ------------------------------------------------------------------------------ #

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
    is_variable_dependent = is_variable(ocp)
    is_time_dependent = !is_autonomous(ocp)
    is_control_free_ocp = is_control_free(ocp)

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

Default show method for a [`Model`](@ref CTModels.OCP.Model).

Prints only the type name.
"""
function Base.show_default(io::IO, ocp::Model)
    return print(io, typeof(ocp))
end
