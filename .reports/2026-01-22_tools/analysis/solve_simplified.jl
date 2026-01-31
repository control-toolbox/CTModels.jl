# ============================================================================
# Simplified solve.jl using new Strategies architecture
# ============================================================================
#
# This file demonstrates how OptimalControl.jl's solve.jl will be simplified
# using the new Strategies module with:
# - Centralized registration
# - Generic routing functions
# - Strategy-based disambiguation
#
# Comparison:
# - Old: ~670 lines
# - New: ~250 lines (62% reduction)
#
# ============================================================================

using CTBase
using CTModels
using CTDirect
using CTSolvers
using CommonSolve

# Import generic functions from Strategies module
using CTModels.Strategies: route_options, build_strategy_from_method, extract_id_from_method

# ============================================================================
# Default options
# ============================================================================

__display() = true
__initial_guess() = nothing

# ============================================================================
# Registry Creation: Create explicit registry (not global)
# ============================================================================
# This happens ONCE when OptimalControl.jl is loaded
# Registry is then passed explicitly to functions that need it

using CTModels.Strategies: create_registry

const OCP_REGISTRY = create_registry(
    CTDirect.AbstractOptimalControlDiscretizer => (CTDirect.CollocationDiscretizer,),
    CTModels.AbstractOptimizationModeler => (CTModels.ADNLPModeler, CTModels.ExaModeler),
    CTSolvers.AbstractOptimizationSolver => (
        CTSolvers.IpoptSolver,
        CTSolvers.MadNLPSolver,
        CTSolvers.KnitroSolver,
        CTSolvers.MadNCLSolver
    ),
)

# ============================================================================
# Strategy family definitions (local to OptimalControl)
# ============================================================================
# This is just a convenient mapping for this specific use case (OCP solving)

const STRATEGY_FAMILIES = (
    discretizer=CTDirect.AbstractOptimalControlDiscretizer,
    modeler=CTModels.AbstractOptimizationModeler,
    solver=CTSolvers.AbstractOptimizationSolver,
)

# ============================================================================
# Available methods registry
# ============================================================================

const AVAILABLE_METHODS = (
    (:collocation, :adnlp, :ipopt),
    (:collocation, :adnlp, :madnlp),
    (:collocation, :adnlp, :knitro),
    (:collocation, :exa, :ipopt),
    (:collocation, :exa, :madnlp),
    (:collocation, :exa, :knitro),
)

available_methods() = AVAILABLE_METHODS

# ============================================================================
# Main solve function (unchanged)
# ============================================================================

function _solve(
    ocp::CTModels.AbstractOptimalControlProblem,
    initial_guess,
    discretizer::CTDirect.AbstractOptimalControlDiscretizer,
    modeler::CTModels.AbstractOptimizationModeler,
    solver::CTSolvers.AbstractOptimizationSolver;
    display::Bool=__display(),
)::CTModels.AbstractOptimalControlSolution

    # Validate initial guess
    normalized_init = CTModels.build_initial_guess(ocp, initial_guess)
    CTModels.validate_initial_guess(ocp, normalized_init)

    # Discretize and solve
    discrete_problem = CTDirect.discretize(ocp, discretizer)
    return CommonSolve.solve(
        discrete_problem, normalized_init, modeler, solver; display=display
    )
end

# ============================================================================
# Display helper (simplified - uses strategy contract)
# ============================================================================

function _display_ocp_method(
    io::IO,
    method::Tuple,
    discretizer::CTDirect.AbstractOptimalControlDiscretizer,
    modeler::CTModels.AbstractOptimizationModeler,
    solver::CTSolvers.AbstractOptimizationSolver;
    display::Bool,
)
    display || return nothing

    version_str = string(Base.pkgversion(@__MODULE__))

    print(io, "▫ This is OptimalControl version v", version_str, " running with: ")
    for (i, m) in enumerate(method)
        sep = i == length(method) ? ".\n\n" : ", "
        printstyled(io, string(m) * sep; color=:cyan, bold=true)
    end

    # Use strategy contract for package names
    model_pkg = CTModels.Strategies.package_name(modeler)
    solver_pkg = CTModels.Strategies.package_name(solver)

    if model_pkg !== missing && solver_pkg !== missing
        println(io, "   ┌─ The NLP is modelled with ", model_pkg, " and solved with ", solver_pkg, ".")
        println(io, "   │")
    end

    # Display options using strategy contract
    disc_opts = CTModels.Strategies.options(discretizer)
    mod_opts = CTModels.Strategies.options(modeler)
    sol_opts = CTModels.Strategies.options(solver)

    has_disc = !isempty(keys(disc_opts.values))
    has_mod = !isempty(keys(mod_opts.values))
    has_sol = !isempty(keys(sol_opts.values))

    if has_disc || has_mod || has_sol
        println(io, "   Options:")

        if has_disc
            println(io, "   ├─ Discretizer:")
            for (name, value) in pairs(disc_opts.values)
                src = disc_opts.sources[name]
                println(io, "   │    ", name, " = ", value, "  (", src, ")")
            end
        end

        if has_mod
            println(io, "   ├─ Modeler:")
            for (name, value) in pairs(mod_opts.values)
                src = mod_opts.sources[name]
                println(io, "   │    ", name, " = ", value, "  (", src, ")")
            end
        end

        if has_sol
            println(io, "   └─ Solver:")
            for (name, value) in pairs(sol_opts.values)
                src = sol_opts.sources[name]
                println(io, "        ", name, " = ", value, "  (", src, ")")
            end
        end
    end

    println(io)
    return nothing
end

_display_ocp_method(method, discretizer, modeler, solver; display) =
    _display_ocp_method(stdout, method, discretizer, modeler, solver; display=display)

# ============================================================================
# Keyword argument parsing
# ============================================================================

# Aliases for solve-level options
const _SOLVE_INITIAL_GUESS_ALIASES = (:initial_guess, :init, :i)
const _SOLVE_DISCRETIZER_ALIASES = (:discretizer, :d)
const _SOLVE_MODELER_ALIASES = (:modeler, :modeller, :m)
const _SOLVE_SOLVER_ALIASES = (:solver, :s)
const _SOLVE_DISPLAY_ALIASES = (:display,)

struct _ParsedKwargs
    initial_guess
    display
    discretizer  # Explicit component or nothing
    modeler      # Explicit component or nothing
    solver       # Explicit component or nothing
    other_kwargs::NamedTuple  # Options to route
end

function _take_kwarg(kwargs::NamedTuple, names::Tuple{Vararg{Symbol}}, default)
    present = [n for n in names if haskey(kwargs, n)]

    if isempty(present)
        return default, kwargs
    elseif length(present) == 1
        name = present[1]
        value = kwargs[name]
        remaining = NamedTuple(k => v for (k, v) in pairs(kwargs) if k != name)
        return value, remaining
    else
        error("Conflicting aliases $present for argument $(names[1]). Use only one of $names.")
    end
end

function _parse_kwargs(kwargs::NamedTuple)
    initial_guess, kwargs1 = _take_kwarg(kwargs, _SOLVE_INITIAL_GUESS_ALIASES, __initial_guess())
    display, kwargs2 = _take_kwarg(kwargs1, _SOLVE_DISPLAY_ALIASES, __display())
    discretizer, kwargs3 = _take_kwarg(kwargs2, _SOLVE_DISCRETIZER_ALIASES, nothing)
    modeler, kwargs4 = _take_kwarg(kwargs3, _SOLVE_MODELER_ALIASES, nothing)
    solver, other_kwargs = _take_kwarg(kwargs4, _SOLVE_SOLVER_ALIASES, nothing)

    return _ParsedKwargs(initial_guess, display, discretizer, modeler, solver, other_kwargs)
end

_has_explicit_components(parsed::_ParsedKwargs) =
    (parsed.discretizer !== nothing) || (parsed.modeler !== nothing) || (parsed.solver !== nothing)

# ============================================================================
# Description mode: Build strategies from method + options
# ============================================================================

function _solve_from_description(
    ocp::CTModels.AbstractOptimalControlProblem,
    method::Tuple{Vararg{Symbol}},
    parsed::_ParsedKwargs,
)::CTModels.AbstractOptimalControlSolution

    # Route options using generic function from Strategies (pass registry explicitly)
    routed = route_options(
        method,
        STRATEGY_FAMILIES,
        parsed.other_kwargs,
        OCP_REGISTRY;  # ← Explicit registry
        source_mode=:description
    )

    # Build strategies using generic function from Strategies (pass registry explicitly)
    discretizer = build_strategy_from_method(
        method,
        STRATEGY_FAMILIES.discretizer,
        OCP_REGISTRY;  # ← Explicit registry
        routed.discretizer...
    )

    modeler = build_strategy_from_method(
        method,
        STRATEGY_FAMILIES.modeler,
        OCP_REGISTRY;  # ← Explicit registry
        routed.modeler...
    )

    solver = build_strategy_from_method(
        method,
        STRATEGY_FAMILIES.solver,
        OCP_REGISTRY;  # ← Explicit registry
        routed.solver...
    )

    # Display and solve
    _display_ocp_method(method, discretizer, modeler, solver; display=parsed.display)

    return _solve(ocp, parsed.initial_guess, discretizer, modeler, solver; display=parsed.display)
end

# ============================================================================
# Explicit mode: User provides components directly
# ============================================================================

function _build_description_from_components(discretizer, modeler, solver)
    syms = Symbol[]
    if discretizer !== nothing
        push!(syms, CTModels.Strategies.symbol(discretizer))
    end
    if modeler !== nothing
        push!(syms, CTModels.Strategies.symbol(modeler))
    end
    if solver !== nothing
        push!(syms, CTModels.Strategies.symbol(solver))
    end
    return Tuple(syms)
end

function _solve_explicit_mode(
    ocp::CTModels.AbstractOptimalControlProblem,
    parsed::_ParsedKwargs,
)::CTModels.AbstractOptimalControlSolution

    # Validate no unknown options
    if !isempty(parsed.other_kwargs)
        error("Unknown options in explicit mode: $(keys(parsed.other_kwargs))")
    end

    has_discretizer = parsed.discretizer !== nothing
    has_modeler = parsed.modeler !== nothing
    has_solver = parsed.solver !== nothing

    # If all components provided, solve directly
    if has_discretizer && has_modeler && has_solver
        return _solve(
            ocp,
            parsed.initial_guess,
            parsed.discretizer,
            parsed.modeler,
            parsed.solver;
            display=parsed.display,
        )
    end

    # Otherwise, build partial description and complete it
    partial_desc = _build_description_from_components(
        parsed.discretizer, parsed.modeler, parsed.solver
    )
    method = CTBase.complete(partial_desc...; descriptions=available_methods())

    # Build missing components with default options (pass registry explicitly)
    discretizer = parsed.discretizer !== nothing ? parsed.discretizer :
                  build_strategy_from_method(method, STRATEGY_FAMILIES.discretizer, OCP_REGISTRY)

    modeler = parsed.modeler !== nothing ? parsed.modeler :
              build_strategy_from_method(method, STRATEGY_FAMILIES.modeler, OCP_REGISTRY)

    solver = parsed.solver !== nothing ? parsed.solver :
             build_strategy_from_method(method, STRATEGY_FAMILIES.solver, OCP_REGISTRY)

    _display_ocp_method(method, discretizer, modeler, solver; display=parsed.display)

    return _solve(ocp, parsed.initial_guess, discretizer, modeler, solver; display=parsed.display)
end

# ============================================================================
# Top-level solve entry point
# ============================================================================

function CommonSolve.solve(
    ocp::CTModels.AbstractOptimalControlProblem,
    description::Symbol...;
    kwargs...
)::CTModels.AbstractOptimalControlSolution

    parsed = _parse_kwargs((; kwargs...))

    # Cannot mix explicit components with description
    if _has_explicit_components(parsed) && !isempty(description)
        error("Cannot mix explicit components (discretizer/modeler/solver) with a description.")
    end

    if _has_explicit_components(parsed)
        # Explicit mode: components provided directly
        return _solve_explicit_mode(ocp, parsed)
    else
        # Description mode: build from method
        method = CTBase.complete(description...; descriptions=available_methods())
        return _solve_from_description(ocp, method, parsed)
    end
end

# ============================================================================
# Summary of simplifications
# ============================================================================
#
# ARCHITECTURE DECISION: Explicit Registry
# - Registry created with create_registry() instead of register_family!()
# - Registry passed explicitly to all functions that need it
# - No global mutable state
#
# REMOVED (~420 lines):
# - _get_unique_symbol() - replaced by extract_id_from_method(method, family, registry)
# - _get_discretizer_symbol() - replaced by extract_id_from_method()
# - _get_modeler_symbol() - replaced by extract_id_from_method()
# - _get_solver_symbol() - replaced by extract_id_from_method()
# - _discretizer_options_keys() - replaced by route_options()
# - _modeler_options_keys() - replaced by route_options()
# - _solver_options_keys() - replaced by route_options()
# - _build_discretizer_from_method() - replaced by build_strategy_from_method(method, family, registry; kwargs...)
# - _build_modeler_from_method() - replaced by build_strategy_from_method()
# - _build_solver_from_method() - replaced by build_strategy_from_method()
# - _extract_option_tool() - replaced by extract_strategy_ids() in Strategies
# - _route_option_for_description() - replaced by route_options(method, families, kwargs, registry)
# - _split_kwargs_for_description() - replaced by route_options()
# - _ensure_no_ambiguous_description_kwargs() - handled by route_options()
# - _normalize_modeler_options() - no longer needed
# - _parse_top_level_kwargs_description() - simplified to _parse_kwargs()
# - _solve_from_components_and_description() - merged into _solve_explicit_mode()
# - _solve_descriptif_mode() - simplified to _solve_from_description()
# - _solve_from_complete_description() - simplified to _solve_from_description()
#
# KEPT (~250 lines):
# - Main _solve() function (unchanged)
# - _display_ocp_method() (simplified using strategy contract)
# - Keyword parsing (simplified)
# - Explicit mode handling
# - Description mode handling
# - Top-level solve() entry point
#
# KEY IMPROVEMENTS:
# 1. Explicit registry - no global mutable state
# 2. All routing logic delegated to route_options(method, families, kwargs, registry)
# 3. All strategy building delegated to build_strategy_from_method(method, family, registry; kwargs...)
# 4. Strategy-based disambiguation: backend = (:sparse, :adnlp)
# 5. Better error messages (from route_options())
# 6. Cleaner separation of concerns
# 7. Testable (can create different registries)
#
# REGISTRY USAGE (7 locations):
# 1. route_options() - 1 call in _solve_from_description()
# 2. build_strategy_from_method() - 6 calls:
#    - 3 in _solve_from_description() (discretizer, modeler, solver)
#    - 3 in _solve_explicit_mode() (discretizer, modeler, solver)
#
# ============================================================================
