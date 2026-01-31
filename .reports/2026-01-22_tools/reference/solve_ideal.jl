# ============================================================================
# IDEAL solve.jl - Final Architecture with Options/Strategies/Orchestration
# ============================================================================
#
# This file demonstrates the IDEAL final architecture using the 3-module system:
# - Options: Generic option handling (extraction, validation, aliases)
# - Strategies: Strategy management (registry, construction, contract)
# - Orchestration: Action orchestration (routing, dispatch, 3 modes)
#
# Key improvements over solve_simplified.jl:
# 1. Clear separation of concerns (Options/Strategies/Orchestration)
# 2. Action options extracted BEFORE strategy routing
# 3. Cleaner _solve() signature with kwargs
# 4. Generic action pattern (reusable for other actions)
# 5. Better documentation of contracts vs API
#
# ============================================================================

using CTBase
using CTModels
using CTDirect
using CTSolvers
using CommonSolve

# Import from the 3-module system
using CTModels.Options
using CTModels.Strategies
using CTModels.Orchestration

# ============================================================================
# Registry Creation
# ============================================================================

const OCP_REGISTRY = Strategies.create_registry(
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
# Strategy Families
# ============================================================================

const STRATEGY_FAMILIES = (
    discretizer=CTDirect.AbstractOptimalControlDiscretizer,
    modeler=CTModels.AbstractOptimizationModeler,
    solver=CTSolvers.AbstractOptimizationSolver,
)

# ============================================================================
# Available Methods
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
# Action Options Schema
# ============================================================================
# These are the options specific to the solve ACTION (not strategies)

const SOLVE_ACTION_OPTIONS = [
    Options.OptionSchema(
        :initial_guess,
        Any,
        nothing,
        (:init, :i),  # Aliases
        nothing  # No validator
    ),
    Options.OptionSchema(
        :display,
        Bool,
        true,
        (),  # No aliases
        nothing
    ),
]

# ============================================================================
# Core Solve Function (Standard Mode)
# ============================================================================
# This is the "standard" mode: action(object, strategies...; action_options...)

function _solve(
    ocp::CTModels.AbstractOptimalControlProblem,
    discretizer::CTDirect.AbstractOptimalControlDiscretizer,
    modeler::CTModels.AbstractOptimizationModeler,
    solver::CTSolvers.AbstractOptimizationSolver;
    initial_guess=nothing,
    display::Bool=true,
)::CTModels.AbstractOptimalControlSolution

    # Validate initial guess
    normalized_init = CTModels.build_initial_guess(ocp, initial_guess)
    CTModels.validate_initial_guess(ocp, normalized_init)

    # Display method info
    if display
        method = (
            Strategies.symbol(discretizer),
            Strategies.symbol(modeler),
            Strategies.symbol(solver)
        )
        _display_ocp_method(stdout, method, discretizer, modeler, solver)
    end

    # Discretize and solve
    discrete_problem = CTDirect.discretize(ocp, discretizer)
    return CommonSolve.solve(
        discrete_problem, normalized_init, modeler, solver; display=display
    )
end

# ============================================================================
# Display Helper
# ============================================================================

function _display_ocp_method(
    io::IO,
    method::Tuple,
    discretizer::CTDirect.AbstractOptimalControlDiscretizer,
    modeler::CTModels.AbstractOptimizationModeler,
    solver::CTSolvers.AbstractOptimizationSolver,
)
    version_str = string(Base.pkgversion(@__MODULE__))

    print(io, "▫ This is OptimalControl version v", version_str, " running with: ")
    for (i, m) in enumerate(method)
        sep = i == length(method) ? ".\n\n" : ", "
        printstyled(io, string(m) * sep; color=:cyan, bold=true)
    end

    # Use strategy contract for package names
    model_pkg = Strategies.package_name(modeler)
    solver_pkg = Strategies.package_name(solver)

    if model_pkg !== missing && solver_pkg !== missing
        println(io, "   ┌─ The NLP is modelled with ", model_pkg, " and solved with ", solver_pkg, ".")
        println(io, "   │")
    end

    # Display options using strategy contract
    disc_opts = Strategies.options(discretizer)
    mod_opts = Strategies.options(modeler)
    sol_opts = Strategies.options(solver)

    has_opts = !isempty(disc_opts) || !isempty(mod_opts) || !isempty(sol_opts)

    if has_opts
        println(io, "   Options:")

        if !isempty(disc_opts)
            println(io, "   ├─ Discretizer:")
            for (name, opt_value) in pairs(disc_opts)
                println(io, "   │    ", name, " = ", opt_value.value, "  (", opt_value.source, ")")
            end
        end

        if !isempty(mod_opts)
            println(io, "   ├─ Modeler:")
            for (name, opt_value) in pairs(mod_opts)
                println(io, "   │    ", name, " = ", opt_value.value, "  (", opt_value.source, ")")
            end
        end

        if !isempty(sol_opts)
            println(io, "   └─ Solver:")
            for (name, opt_value) in pairs(sol_opts)
                println(io, "        ", name, " = ", opt_value.value, "  (", opt_value.source, ")")
            end
        end
    end

    println(io)
    return nothing
end

# ============================================================================
# Description Mode
# ============================================================================

function _solve_description_mode(
    ocp::CTModels.AbstractOptimalControlProblem,
    description::Tuple{Vararg{Symbol}},
    kwargs::NamedTuple,
)::CTModels.AbstractOptimalControlSolution

    # Complete method description
    method = CTBase.complete(description...; descriptions=available_methods())

    # Route ALL options (action + strategies) using Orchestration module
    # Supports disambiguation: backend = (:sparse, :adnlp)
    # Supports multi-strategy: backend = ((:sparse, :adnlp), (:cpu, :ipopt))
    routed = Orchestration.route_all_options(
        method,
        STRATEGY_FAMILIES,
        SOLVE_ACTION_OPTIONS,
        kwargs,
        OCP_REGISTRY;
        source_mode=:description  # User-facing mode with helpful errors
    )

    # Build strategies
    discretizer = Strategies.build_strategy_from_method(
        method,
        STRATEGY_FAMILIES.discretizer,
        OCP_REGISTRY;
        routed.strategies.discretizer...
    )

    modeler = Strategies.build_strategy_from_method(
        method,
        STRATEGY_FAMILIES.modeler,
        OCP_REGISTRY;
        routed.strategies.modeler...
    )

    solver = Strategies.build_strategy_from_method(
        method,
        STRATEGY_FAMILIES.solver,
        OCP_REGISTRY;
        routed.strategies.solver...
    )

    # Call core solve with action options
    return _solve(
        ocp,
        discretizer,
        modeler,
        solver;
        initial_guess=routed.action[:initial_guess].value,
        display=routed.action[:display].value,
    )
end

# ============================================================================
# Explicit Mode
# ============================================================================

function _solve_explicit_mode(
    ocp::CTModels.AbstractOptimalControlProblem,
    kwargs::NamedTuple,
)::CTModels.AbstractOptimalControlSolution

    # Extract strategies from kwargs
    discretizer_opt, kwargs1 = Options.extract_option(
        kwargs,
        Options.OptionSchema(:discretizer, Any, nothing, (:d,), nothing)
    )
    modeler_opt, kwargs2 = Options.extract_option(
        kwargs1,
        Options.OptionSchema(:modeler, Any, nothing, (:modeller, :m), nothing)
    )
    solver_opt, remaining = Options.extract_option(
        kwargs2,
        Options.OptionSchema(:solver, Any, nothing, (:s,), nothing)
    )

    discretizer = discretizer_opt.value
    modeler = modeler_opt.value
    solver = solver_opt.value

    # Extract action options
    action_options, extra = Options.extract_options(remaining, SOLVE_ACTION_OPTIONS)

    # Validate no extra options
    if !isempty(extra)
        error("Unknown options in explicit mode: $(keys(extra))")
    end

    # If all strategies provided, solve directly
    if discretizer !== nothing && modeler !== nothing && solver !== nothing
        return _solve(
            ocp,
            discretizer,
            modeler,
            solver;
            initial_guess=action_options[:initial_guess].value,
            display=action_options[:display].value,
        )
    end

    # Otherwise, complete with defaults
    partial_desc = Tuple(
        Strategies.id(typeof(s)) for s in (discretizer, modeler, solver) if s !== nothing
    )
    method = CTBase.complete(partial_desc...; descriptions=available_methods())

    discretizer = discretizer !== nothing ? discretizer :
                  Strategies.build_strategy_from_method(method, STRATEGY_FAMILIES.discretizer, OCP_REGISTRY)

    modeler = modeler !== nothing ? modeler :
              Strategies.build_strategy_from_method(method, STRATEGY_FAMILIES.modeler, OCP_REGISTRY)

    solver = solver !== nothing ? solver :
             Strategies.build_strategy_from_method(method, STRATEGY_FAMILIES.solver, OCP_REGISTRY)

    return _solve(
        ocp,
        discretizer,
        modeler,
        solver;
        initial_guess=action_options[:initial_guess].value,
        display=action_options[:display].value,
    )
end

# ============================================================================
# Top-Level Entry Point (CommonSolve.solve)
# ============================================================================

function CommonSolve.solve(
    ocp::CTModels.AbstractOptimalControlProblem,
    description::Symbol...;
    kwargs...
)::CTModels.AbstractOptimalControlSolution

    # Detect mode
    has_strategy_kwargs = any(k in keys(kwargs) for k in (:discretizer, :d, :modeler, :modeller, :m, :solver, :s))

    if has_strategy_kwargs && !isempty(description)
        error("Cannot mix explicit strategies (discretizer/modeler/solver) with description.")
    end

    if has_strategy_kwargs
        # Explicit mode
        return _solve_explicit_mode(ocp, (; kwargs...))
    else
        # Description mode (includes default solve(ocp) case)
        return _solve_description_mode(ocp, description, (; kwargs...))
    end
end

# ============================================================================
# Summary of Architecture
# ============================================================================
#
# MODULES:
# --------
# Options:     Generic option handling (extraction, validation, aliases)
#              - No dependencies
#              - Provides: extract_option(), extract_options(), OptionSchema
#
# Strategies:  Strategy management (registry, construction, contract)
#              - Depends on: Options
#              - Provides: create_registry(), build_strategy(), option_names_from_method()
#
# Orchestration:     Action orchestration (routing, dispatch, modes)
#              - Depends on: Options, Strategies
#              - Provides: route_all_options(), dispatch_action()
#
# MODES:
# ------
# 1. Standard:     solve(ocp, discretizer, modeler, solver; initial_guess, display)
# 2. Description:  solve(ocp, :collocation, :adnlp; grid_size=100, initial_guess=ig)
# 3. Explicit:     solve(ocp; discretizer=..., modeler=..., initial_guess=ig)
#
# ROUTING:
# --------
# 1. Extract action options FIRST (using Options.extract_options)
# 2. Route remaining to strategies (using Orchestration.route_to_strategies)
# 3. Build strategies with routed options
# 4. Call core action with action options
#
# CONTRACTS:
# ----------
# User Contract (Public):
#   - AbstractStrategy interface (symbol, options, metadata)
#   - solve() with 3 modes
#
# Developer API (Internal):
#   - Options.extract_option/extract_options
#   - Strategies.create_registry/build_strategy
#   - Orchestration.route_all_options
#
# ============================================================================
