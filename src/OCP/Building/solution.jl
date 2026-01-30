"""
$(TYPEDSIGNATURES)

Build a solution from the optimal control problem, the time grid, the state, control, variable, and dual variables.

# Arguments

- `ocp::Model`: the optimal control problem.
- `T::Vector{Float64}`: the time grid.
- `X::Matrix{Float64}`: the state trajectory.
- `U::Matrix{Float64}`: the control trajectory.
- `v::Vector{Float64}`: the variable trajectory.
- `P::Matrix{Float64}`: the costate trajectory.
- `objective::Float64`: the objective value.
- `iterations::Int`: the number of iterations.
- `constraints_violation::Float64`: the constraints violation.
- `message::String`: the message associated to the status criterion.
- `status::Symbol`: the status criterion.
- `successful::Bool`: the successful status.
- `path_constraints_dual::Matrix{Float64}`: the dual of the path constraints.
- `boundary_constraints_dual::Vector{Float64}`: the dual of the boundary constraints.
- `state_constraints_lb_dual::Matrix{Float64}`: the lower bound dual of the state constraints.
- `state_constraints_ub_dual::Matrix{Float64}`: the upper bound dual of the state constraints.
- `control_constraints_lb_dual::Matrix{Float64}`: the lower bound dual of the control constraints.
- `control_constraints_ub_dual::Matrix{Float64}`: the upper bound dual of the control constraints.
- `variable_constraints_lb_dual::Vector{Float64}`: the lower bound dual of the variable constraints.
- `variable_constraints_ub_dual::Vector{Float64}`: the upper bound dual of the variable constraints.
- `infos::Dict{Symbol,Any}`: additional solver information dictionary.

# Returns

- `sol::Solution`: the optimal control solution.

# Notes

The dimensions of box constraint dual variables (`state_constraints_*_dual`, `control_constraints_*_dual`, 
`variable_constraints_*_dual`) correspond to the **state/control/variable dimension**, not the number of 
constraint declarations. If multiple constraints are declared on the same component (e.g., `x₂(t) ≤ 1.2` 
and `x₂(t) ≤ 2.0`), only the last bound value is retained, and a warning is emitted during model construction.

"""

function build_solution(
    ocp::Model,
    T::Vector{Float64},
    X::TX,
    U::TU,
    v::Vector{Float64},
    P::TP;
    objective::Float64,
    iterations::Int,
    constraints_violation::Float64,
    message::String,
    status::Symbol,
    successful::Bool,
    path_constraints_dual::TPCD=__constraints(),
    boundary_constraints_dual::Union{Vector{Float64},Nothing}=__constraints(),
    state_constraints_lb_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    state_constraints_ub_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    control_constraints_lb_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    control_constraints_ub_dual::Union{Matrix{Float64},Nothing}=__constraints(),
    variable_constraints_lb_dual::Union{Vector{Float64},Nothing}=__constraints(),
    variable_constraints_ub_dual::Union{Vector{Float64},Nothing}=__constraints(),
    infos::Dict{Symbol,Any}=Dict{Symbol,Any}(),
) where {
    TX<:Union{Matrix{Float64},Function},
    TU<:Union{Matrix{Float64},Function},
    TP<:Union{Matrix{Float64},Function},
    TPCD<:Union{Matrix{Float64},Function,Nothing},
}

    # get dimensions
    dim_x = state_dimension(ocp)
    dim_u = control_dimension(ocp)
    dim_v = variable_dimension(ocp)

    # check that time grid is strictly increasing
    # if not proceed with list of indexes as time grid
    if !issorted(T; lt=<)
        println(
            "WARNING: time grid at solution is not increasing, replacing with list of indices...",
        )
        println(T)
        dim_NLP_steps = length(T) - 1
        T = LinRange(0, dim_NLP_steps, dim_NLP_steps + 1)
    end

    # Build interpolated functions for state, control, and costate
    # Using unified API with validation and deepcopy+scalar wrapping
    fx = build_interpolated_function(X, T, dim_x, TX; expected_dim=dim_x)
    fu = build_interpolated_function(U, T, dim_u, TU; expected_dim=dim_u)
    fp = build_interpolated_function(P, T, dim_x, TP; constant_if_two_points=true, expected_dim=dim_x)
    var = (dim_v == 1) ? v[1] : v

    # nonlinear constraints and dual variables (optional, can be nothing)
    # Note: dim is set to dim_path_constraints_nl for proper scalar wrapping
    fpcd = build_interpolated_function(
        path_constraints_dual, T, dim_path_constraints_nl(ocp), TPCD;
        allow_nothing=true
    )

    # box constraints multipliers (optional, can be nothing)
    fscbd = build_interpolated_function(
        state_constraints_lb_dual, T, dim_x, Union{Matrix{Float64},Nothing};
        allow_nothing=true
    )
    fscud = build_interpolated_function(
        state_constraints_ub_dual, T, dim_x, Union{Matrix{Float64},Nothing};
        allow_nothing=true
    )
    fccbd = build_interpolated_function(
        control_constraints_lb_dual, T, dim_u, Union{Matrix{Float64},Nothing};
        allow_nothing=true
    )
    fccud = build_interpolated_function(
        control_constraints_ub_dual, T, dim_u, Union{Matrix{Float64},Nothing};
        allow_nothing=true
    )

    # build Models
    time_grid = TimeGridModel(T)
    state = StateModelSolution(state_name(ocp), state_components(ocp), fx)
    control = ControlModelSolution(control_name(ocp), control_components(ocp), fu)
    variable = VariableModelSolution(variable_name(ocp), variable_components(ocp), var)
    dual = DualModel(
        fpcd,
        boundary_constraints_dual,
        fscbd,
        fscud,
        fccbd,
        fccud,
        variable_constraints_lb_dual,
        variable_constraints_ub_dual,
    )

    solver_infos = SolverInfos(
        iterations, status, message, successful, constraints_violation, infos
    )

    return Solution(
        time_grid,
        times(ocp),
        state,
        control,
        variable,
        ocp,
        fp,
        objective,
        dual,
        solver_infos,
    )
end

# ------------------------------------------------------------------------------ #
# Getters
# ------------------------------------------------------------------------------ #
"""
$(TYPEDSIGNATURES)

Return the dimension of the state.

"""
function state_dimension(sol::Solution)::Dimension
    return dimension(sol.state)
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the state.

"""
function state_components(sol::Solution)::Vector{String}
    return components(sol.state)
end

"""
$(TYPEDSIGNATURES)

Return the name of the state.

"""
function state_name(sol::Solution)::String
    return name(sol.state)
end

"""
$(TYPEDSIGNATURES)

Return the state as a function of time.

```@example
julia> x  = state(sol)
julia> t0 = time_grid(sol)[1]
julia> x0 = x(t0) # state at the initial time
```
"""
function state(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:StateModelSolution{TS},
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::TS where {TS<:Function}
    return value(sol.state)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the control.

"""
function control_dimension(sol::Solution)::Dimension
    return dimension(sol.control)
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the control.

"""
function control_components(sol::Solution)::Vector{String}
    return components(sol.control)
end

"""
$(TYPEDSIGNATURES)

Return the name of the control.

"""
function control_name(sol::Solution)::String
    return name(sol.control)
end

"""
$(TYPEDSIGNATURES)

Return the control as a function of time.

```@example
julia> u  = control(sol)
julia> t0 = time_grid(sol)[1]
julia> u0 = u(t0) # control at the initial time
```
"""
function control(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:ControlModelSolution{TS},
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::TS where {TS<:Function}
    return value(sol.control)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the variable.

"""
function variable_dimension(sol::Solution)::Dimension
    return dimension(sol.variable)
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the variable.

"""
function variable_components(sol::Solution)::Vector{String}
    return components(sol.variable)
end

"""
$(TYPEDSIGNATURES)

Return the name of the variable.

"""
function variable_name(sol::Solution)::String
    return name(sol.variable)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the boundary constraints.

"""
function dim_boundary_constraints_nl(sol::Solution)::Dimension
    bc_dual = boundary_constraints_dual(sol)
    return bc_dual === nothing ? 0 : length(bc_dual)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the path constraints.

"""
function dim_path_constraints_nl(sol::Solution)::Dimension
    pc_dual = path_constraints_dual(sol)
    if pc_dual === nothing
        return 0
    else
        t0 = initial_time(sol)
        return length(pc_dual(t0))
    end
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the variable box constraints.

"""
function dim_variable_constraints_box(sol::Solution)::Dimension
    vc_lb_dual = variable_constraints_lb_dual(sol)
    return vc_lb_dual === nothing ? 0 : length(vc_lb_dual)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on state.

"""
function dim_state_constraints_box(sol::Solution)::Dimension
    sc_lb_dual = state_constraints_lb_dual(sol)
    return sc_lb_dual === nothing ? 0 : state_dimension(sol)
end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on control.

"""
function dim_control_constraints_box(sol::Solution)::Dimension
    cc_lb_dual = control_constraints_lb_dual(sol)
    return cc_lb_dual === nothing ? 0 : control_dimension(sol)
end

"""
$(TYPEDSIGNATURES)

Return the variable or `nothing`.

```@example
julia> v  = variable(sol)
```
"""
function variable(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:VariableModelSolution{TS},
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::TS where {TS<:Union{ctNumber,ctVector}}
    return value(sol.variable)
end

"""
$(TYPEDSIGNATURES)

Return the costate as a function of time.

```@example
julia> p  = costate(sol)
julia> t0 = time_grid(sol)[1]
julia> p0 = p(t0) # costate at the initial time
```
"""
function costate(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        Co,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::Co where {Co<:Function}
    return sol.costate
end

"""
$(TYPEDSIGNATURES)

Return the name of the initial time.

"""
function initial_time_name(sol::Solution)::String
    return name(initial(sol.times))
end

"""
$(TYPEDSIGNATURES)

Return the name of the final time.

"""
function final_time_name(sol::Solution)::String
    return name(final(sol.times))
end

"""
$(TYPEDSIGNATURES)

Return the name of the time component.

"""
function time_name(sol::Solution)::String
    return time_name(sol.times)
end

# Initial time
"""
$(TYPEDSIGNATURES)

Return the initial time of the solution.
"""
function initial_time(sol::Solution)::Real
    return initial_time(sol.times)
end

"""
$(TYPEDSIGNATURES)

Return the final time of the solution.
"""
function final_time(sol::Solution)::Real
    return final_time(sol.times)
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is fixed.
"""
function has_fixed_initial_time(sol::Solution)::Bool
    return has_fixed_initial_time(sol.times)
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is free.
"""
function has_free_initial_time(sol::Solution)::Bool
    return has_free_initial_time(sol.times)
end

"""
$(TYPEDSIGNATURES)

Check if the final time is fixed.
"""
function has_fixed_final_time(sol::Solution)::Bool
    return has_fixed_final_time(sol.times)
end

"""
$(TYPEDSIGNATURES)

Check if the final time is free.
"""
function has_free_final_time(sol::Solution)::Bool
    return has_free_final_time(sol.times)
end

"""
$(TYPEDSIGNATURES)

Return the times model.

"""
function times(
    sol::Solution{
        <:AbstractTimeGridModel,
        TM,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::TM where {TM<:AbstractTimesModel}
    return sol.times
end

"""
$(TYPEDSIGNATURES)

Return the time grid.

"""
function time_grid(
    sol::Solution{
        <:TimeGridModel{T},
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::T where {T<:TimesDisc}
    return sol.time_grid.value
end

"""
$(TYPEDSIGNATURES)

Return the objective value.

"""
function objective(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        O,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::O where {O<:ctNumber}
    return sol.objective
end

"""
$(TYPEDSIGNATURES)

Return the number of iterations (if solved by an iterative method).

"""
function iterations(sol::Solution)::Int
    return sol.solver_infos.iterations
end

"""
$(TYPEDSIGNATURES)

Return the status criterion (a Symbol).

"""
function status(sol::Solution)::Symbol
    return sol.solver_infos.status
end

"""
$(TYPEDSIGNATURES)

Return the message associated to the status criterion.

"""
function message(sol::Solution)::String
    return sol.solver_infos.message
end

"""
$(TYPEDSIGNATURES)

Return the successful status.

"""
function successful(sol::Solution)::Bool
    return sol.solver_infos.successful
end

"""
$(TYPEDSIGNATURES)

Return the constraints violation.

"""
function constraints_violation(sol::Solution)::Float64
    return sol.solver_infos.constraints_violation
end

"""
$(TYPEDSIGNATURES)

Return a dictionary of additional infos depending on the solver or `nothing`.

"""
function infos(sol::Solution)::Dict{Symbol,Any}
    return sol.solver_infos.infos
end

"""
$(TYPEDSIGNATURES)

Return the model of the optimal control problem.
"""
function model(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        M,
        <:Function,
        <:ctNumber,
        <:AbstractDualModel,
        <:AbstractSolverInfos,
    },
)::M where {M<:AbstractModel}
    return sol.model
end

"""
$(TYPEDSIGNATURES)

Return the dual model containing all constraint multipliers.
"""
function dual_model(
    sol::Solution{
        <:AbstractTimeGridModel,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:AbstractModel,
        <:Function,
        <:ctNumber,
        DM,
        <:AbstractSolverInfos,
    },
)::DM where {DM<:AbstractDualModel}
    return sol.dual
end

"""
$(TYPEDSIGNATURES)

Return the dual of the path constraints.

"""
function path_constraints_dual(sol::Solution)
    return path_constraints_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the dual of the boundary constraints.

"""
function boundary_constraints_dual(sol::Solution)
    return boundary_constraints_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the lower bound dual of the state constraints.

"""
function state_constraints_lb_dual(sol::Solution)
    return state_constraints_lb_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the upper bound dual of the state constraints.

"""
function state_constraints_ub_dual(sol::Solution)
    return state_constraints_ub_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the lower bound dual of the control constraints.

"""
function control_constraints_lb_dual(sol::Solution)
    return control_constraints_lb_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the upper bound dual of the control constraints.

"""
function control_constraints_ub_dual(sol::Solution)
    return control_constraints_ub_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the lower bound dual of the variable constraints.

"""
function variable_constraints_lb_dual(sol::Solution)
    return variable_constraints_lb_dual(dual_model(sol))
end

"""
$(TYPEDSIGNATURES)

Return the upper bound dual of the variable constraints.

"""
function variable_constraints_ub_dual(sol::Solution)
    return variable_constraints_ub_dual(dual_model(sol))
end


# --------------------------------------------------------------------------------------------------
# print a solution
"""
$(TYPEDSIGNATURES)

Print the solution.
"""
function Base.show(io::IO, ::MIME"text/plain", sol::Solution)
    # Résumé solveur
    println(io, "• Solver:")
    println(io, "  ✓ Successful  : ", successful(sol))
    println(io, "  │  Status     : ", status(sol))
    println(io, "  │  Message    : ", message(sol))
    println(io, "  │  Iterations : ", iterations(sol))
    println(io, "  │  Objective  : ", objective(sol))
    println(io, "  └─ Constraints violation : ", constraints_violation(sol))

    # Variable (si définie)
    if variable_dimension(sol) > 0
        println(
            io,
            "\n• Variable: ",
            variable_name(sol),
            " = (",
            join(variable_components(sol), ", "),
            ") = ",
            variable(sol),
        )
        if dim_variable_constraints_box(sol) > 0
            println(io, "  │  Var dual (lb) : ", variable_constraints_lb_dual(sol))
            println(io, "  └─ Var dual (ub) : ", variable_constraints_ub_dual(sol))
        end
    end

    # Boundary constraints duals
    if dim_boundary_constraints_nl(sol) > 0
        println(io, "\n• Boundary duals: ", boundary_constraints_dual(sol))
    end
end

# ============================================================================== #
# Serialization utilities
# ============================================================================== #

"""
    _serialize_solution(sol::Solution)::Dict{String, Any}

Sérialise une solution en données discrètes pour export (JLD2, JSON, etc.).
Utilise les getters publics pour accéder aux champs de la solution.

Cette fonction extrait toutes les données d'une solution et les convertit en format
sérialisable (matrices, vecteurs, scalaires). Les fonctions sont discrétisées sur
la grille temporelle.

# Arguments
- `sol::Solution`: Solution à sérialiser

# Returns
- `Dict{String, Any}`: Dictionnaire contenant toutes les données discrètes :
  - `"time_grid"`: Grille temporelle
  - `"state"`, `"control"`, `"costate"`: Matrices discrétisées
  - `"variable"`: Vecteur de variables
  - `"objective"`: Valeur scalaire
  - Fonctions duales discrétisées (peuvent être `nothing`)
  - Duals de boundary et variable (vecteurs)
  - Informations du solveur

# Notes
- Les fonctions sont discrétisées via `_discretize_function`
- Les duals `nothing` sont préservés comme `nothing`
- Compatible avec `build_solution` pour reconstruction

# Example
```julia
sol = solve(ocp)
data = CTModels._serialize_solution(sol)
# Reconstruction
sol_reconstructed = CTModels.build_solution(
    ocp, data["time_grid"], data["state"], data["control"], 
    data["variable"], data["costate"]; 
    objective=data["objective"], ...
)
```
"""
function _serialize_solution(sol::Solution)::Dict{String, Any}
    # Utiliser les getters publics
    T = time_grid(sol)
    dim_x = state_dimension(sol)
    dim_u = control_dimension(sol)
    
    # Discrétiser les fonctions principales
    return Dict(
        "time_grid" => T,
        "state" => _discretize_function(state(sol), T, dim_x),
        "control" => _discretize_function(control(sol), T, dim_u),
        "costate" => _discretize_function(costate(sol), T, dim_x),
        "variable" => variable(sol),
        "objective" => objective(sol),
        
        # Discrétiser les fonctions duales (peuvent être nothing)
        "path_constraints_dual" => _discretize_dual(path_constraints_dual(sol), T),
        "state_constraints_lb_dual" => _discretize_dual(state_constraints_lb_dual(sol), T),
        "state_constraints_ub_dual" => _discretize_dual(state_constraints_ub_dual(sol), T),
        "control_constraints_lb_dual" => _discretize_dual(control_constraints_lb_dual(sol), T),
        "control_constraints_ub_dual" => _discretize_dual(control_constraints_ub_dual(sol), T),
        
        # Duals de boundary et variable (vecteurs, pas fonctions)
        "boundary_constraints_dual" => boundary_constraints_dual(sol),
        "variable_constraints_lb_dual" => variable_constraints_lb_dual(sol),
        "variable_constraints_ub_dual" => variable_constraints_ub_dual(sol),
        
        # Infos solver
        "iterations" => iterations(sol),
        "message" => message(sol),
        "status" => status(sol),
        "successful" => successful(sol),
        "constraints_violation" => constraints_violation(sol),
    )
end
