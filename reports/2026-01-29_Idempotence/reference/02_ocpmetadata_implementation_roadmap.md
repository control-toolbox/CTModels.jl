# Roadmap d'implémentation de `OCPMetadata`

**Version**: 1.0  
**Date**: 2026-01-30  
**Statut**: 📋 Plan détaillé prêt pour implémentation  
**Objectif**: Remplacer le champ `model` par `metadata` dans `Solution`

---

## Vue d'ensemble

Ce document fournit un plan d'implémentation détaillé, étape par étape, pour introduire `OCPMetadata` dans CTModels.jl et éliminer les warnings JLD2 lors de l'export de solutions.

---

## Phase 1 : Création de `OCPMetadata` ✅ DESIGN FINALISÉ

### Étape 1.1 : Créer le fichier `src/OCP/Types/metadata.jl`

**Fichier** : `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Types/metadata.jl`

**Contenu** :

```julia
# ------------------------------------------------------------------------------ #
# OCP Metadata - Minimal serializable metadata for OCP models
# ------------------------------------------------------------------------------ #

"""
$(TYPEDEF)

Minimal serializable metadata extracted from an optimal control problem model.

This structure stores only the structural dimensions and constraint information
needed for displaying, plotting, and reconstructing solutions, without storing
any functions (dynamics, constraints, objective).

# Fields

- `dim_state::Int`: State dimension
- `dim_control::Int`: Control dimension
- `dim_variable::Int`: Optimization variable dimension
- `dim_path_constraints::Int`: Nonlinear path constraints dimension
- `dim_boundary_constraints::Int`: Nonlinear boundary constraints dimension
- `dim_variable_constraints_box::Int`: Box constraints on variables dimension

# Example

```julia
metadata = OCPMetadata(
    dim_state = 2,
    dim_control = 1,
    dim_variable = 0,
    dim_path_constraints = 0,
    dim_boundary_constraints = 2,
    dim_variable_constraints_box = 0
)
```

# Notes

- This structure is **fully serializable** (no functions, only integers)
- It contains **only** the information needed to:
  - Display a solution (`show(io, sol)`)
  - Plot a solution (`plot(sol)`)
  - Reconstruct a solution from discrete data
- It **does not** allow re-solving the problem (no dynamics, constraints, etc.)
- Constraint bounds are not stored (optional for plotting, can be passed separately)

See also: [`Solution`](@ref), [`Model`](@ref)
"""
struct OCPMetadata
    dim_state::Int
    dim_control::Int
    dim_variable::Int
    dim_path_constraints::Int
    dim_boundary_constraints::Int
    dim_variable_constraints_box::Int
end

"""
$(TYPEDSIGNATURES)

Extract minimal metadata from a complete OCP model.

# Arguments
- `ocp::Model`: Complete OCP model

# Returns
- `OCPMetadata`: Serializable metadata structure

# Example

```julia
ocp = Model(...)
metadata = OCPMetadata(ocp)
```
"""
function OCPMetadata(ocp::Model)::OCPMetadata
    return OCPMetadata(
        state_dimension(ocp),
        control_dimension(ocp),
        variable_dimension(ocp),
        dim_path_constraints_nl(ocp),
        dim_boundary_constraints_nl(ocp),
        dim_variable_constraints_box(ocp)
    )
end

# ------------------------------------------------------------------------------ #
# Accessor functions for compatibility with existing code
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the state dimension from OCP metadata.
"""
state_dimension(meta::OCPMetadata)::Int = meta.dim_state

"""
$(TYPEDSIGNATURES)

Return the control dimension from OCP metadata.
"""
control_dimension(meta::OCPMetadata)::Int = meta.dim_control

"""
$(TYPEDSIGNATURES)

Return the variable dimension from OCP metadata.
"""
variable_dimension(meta::OCPMetadata)::Int = meta.dim_variable

"""
$(TYPEDSIGNATURES)

Return the nonlinear path constraints dimension from OCP metadata.
"""
dim_path_constraints_nl(meta::OCPMetadata)::Int = meta.dim_path_constraints

"""
$(TYPEDSIGNATURES)

Return the nonlinear boundary constraints dimension from OCP metadata.
"""
dim_boundary_constraints_nl(meta::OCPMetadata)::Int = meta.dim_boundary_constraints

"""
$(TYPEDSIGNATURES)

Return the box constraints on variables dimension from OCP metadata.
"""
dim_variable_constraints_box(meta::OCPMetadata)::Int = meta.dim_variable_constraints_box
```

### Étape 1.2 : Ajouter l'include dans `src/OCP/OCP.jl`

**Fichier** : `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/OCP.jl`

**Modification** : Ajouter après les autres includes de Types :

```julia
include("Types/metadata.jl")
```

### Étape 1.3 : Exporter `OCPMetadata`

**Fichier** : `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/CTModels.jl`

**Modification** : Ajouter dans la section des exports :

```julia
export OCPMetadata
```

---

## Phase 2 : Modification de `Solution` 🔧 IMPLÉMENTATION

### Étape 2.1 : Modifier la structure `Solution`

**Fichier** : `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Types/solution.jl`

**Ligne** : ~210-232

**Modification** :

```julia
struct Solution{
    TimeGridModelType<:AbstractTimeGridModel,
    TimesModelType<:AbstractTimesModel,
    StateModelType<:AbstractStateModel,
    ControlModelType<:AbstractControlModel,
    VariableModelType<:AbstractVariableModel,
    CostateModelType<:Function,
    ObjectiveValueType<:ctNumber,
    DualModelType<:AbstractDualModel,
    SolverInfosType<:AbstractSolverInfos,
    ModelType<:Union{AbstractModel,Nothing},  # ← Devient optionnel
    MetadataType<:OCPMetadata,                # ← Nouveau champ
} <: AbstractSolution
    time_grid::TimeGridModelType
    times::TimesModelType
    state::StateModelType
    control::ControlModelType
    variable::VariableModelType
    costate::CostateModelType
    objective::ObjectiveValueType
    dual::DualModelType
    solver_infos::SolverInfosType
    model::ModelType      # ← Peut être nothing
    metadata::MetadataType  # ← Toujours présent
end
```

**Mise à jour de la docstring** :

```julia
"""
$(TYPEDEF)

Complete solution of an optimal control problem.

Stores the optimal state, control, and costate trajectories, the optimisation
variable value, objective value, dual variables, solver information, and
metadata about the original model.

# Fields

- `time_grid::TimeGridModelType`: Discretised time points.
- `times::TimesModelType`: Initial and final time specification.
- `state::StateModelType`: State trajectory `t -> x(t)` with metadata.
- `control::ControlModelType`: Control trajectory `t -> u(t)` with metadata.
- `variable::VariableModelType`: Optimisation variable value with metadata.
- `costate::CostateModelType`: Costate (adjoint) trajectory `t -> p(t)`.
- `objective::ObjectiveValueType`: Optimal objective value.
- `dual::DualModelType`: Dual variables for all constraints.
- `solver_infos::SolverInfosType`: Solver statistics and status.
- `model::Union{ModelType,Nothing}`: Reference to the original OCP (optional, may be `nothing` after import).
- `metadata::OCPMetadata`: Minimal serializable metadata from the original OCP.

# Notes

- The `metadata` field is always present and contains dimensions and constraint information.
- The `model` field may be `nothing` after importing a solution from disk.
- Use `metadata(sol)` to access metadata (recommended) or `model(sol)` (deprecated).

# Example

```julia-repl
julia> using CTModels

julia> # Solutions are typically returned by solvers
julia> sol = solve(ocp, ...)  # Returns a Solution
julia> CTModels.objective(sol)
julia> meta = CTModels.metadata(sol)  # Access metadata
```
"""
```

### Étape 2.2 : Ajouter l'accesseur `metadata`

**Fichier** : `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Building/solution.jl`

**Ajouter après les autres accesseurs** :

```julia
"""
$(TYPEDSIGNATURES)

Return the OCP metadata from the solution.

This is the recommended way to access model dimensions and constraint information
from a solution, especially after import from disk.

# Example

```julia
meta = metadata(sol)
n = state_dimension(meta)
m = control_dimension(meta)
```

See also: [`OCPMetadata`](@ref), [`model`](@ref)
"""
function metadata(sol::Solution)::OCPMetadata
    return sol.metadata
end
```

### Étape 2.3 : Modifier l'accesseur `model` (dépréciation progressive)

**Fichier** : `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Building/solution.jl`

**Remplacer l'accesseur actuel** :

```julia
"""
$(TYPEDSIGNATURES)

Return the OCP model from the solution.

# Deprecation Warning

This function is deprecated. After importing a solution from disk, the `model`
field may be `nothing`. Use `metadata(sol)` instead to access dimensions and
constraint information.

If you need the full model for plotting bounds or other purposes, pass it
explicitly: `plot(sol; model=ocp)`.

# Example

```julia
# Deprecated (may fail after import)
ocp = model(sol)

# Recommended
meta = metadata(sol)
n = state_dimension(meta)
```

See also: [`metadata`](@ref), [`OCPMetadata`](@ref)
"""
function model(sol::Solution)
    if !isnothing(sol.model)
        return sol.model
    else
        @warn "model(sol) returned nothing. The model is not stored after import. Use metadata(sol) instead." maxlog=1
        return nothing
    end
end
```

### Étape 2.4 : Ajouter des accesseurs de dimension sur `Solution`

**Fichier** : `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Building/solution.jl`

**Ajouter** :

```julia
"""
$(TYPEDSIGNATURES)

Return the state dimension from the solution metadata.
"""
state_dimension(sol::Solution)::Int = state_dimension(sol.metadata)

"""
$(TYPEDSIGNATURES)

Return the control dimension from the solution metadata.
"""
control_dimension(sol::Solution)::Int = control_dimension(sol.metadata)

"""
$(TYPEDSIGNATURES)

Return the variable dimension from the solution metadata.
"""
variable_dimension(sol::Solution)::Int = variable_dimension(sol.metadata)

"""
$(TYPEDSIGNATURES)

Return the nonlinear path constraints dimension from the solution metadata.
"""
dim_path_constraints_nl(sol::Solution)::Int = dim_path_constraints_nl(sol.metadata)

"""
$(TYPEDSIGNATURES)

Return the nonlinear boundary constraints dimension from the solution metadata.
"""
dim_boundary_constraints_nl(sol::Solution)::Int = dim_boundary_constraints_nl(sol.metadata)

"""
$(TYPEDSIGNATURES)

Return the box constraints on variables dimension from the solution metadata.
"""
dim_variable_constraints_box(sol::Solution)::Int = dim_variable_constraints_box(sol.metadata)
```

---

## Phase 3 : Adaptation de `build_solution` 🔧 IMPLÉMENTATION

### Étape 3.1 : Modifier `build_solution`

**Fichier** : `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Building/solution.jl`

**Ligne** : ~43-262

**Modifications** :

1. Créer `metadata` depuis `ocp` au début :

```julia
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

    # Extract metadata from OCP
    metadata = OCPMetadata(ocp)
    
    # get dimensions from metadata
    dim_x = state_dimension(metadata)
    dim_u = control_dimension(metadata)
    dim_v = variable_dimension(metadata)
    
    # ... reste du code inchangé ...
```

2. Modifier le retour final :

```julia
    return Solution(
        time_grid,
        times(ocp),
        state,
        control,
        variable,
        fp,
        objective,
        dual,
        solver_infos,
        ocp,       # ← model (présent lors de la construction)
        metadata,  # ← metadata (toujours présent)
    )
end
```

### Étape 3.2 : Modifier `_serialize_solution`

**Fichier** : `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Building/solution.jl`

**Ligne** : ~807-847

**Modifications** :

1. Changer la signature pour utiliser `metadata` :

```julia
function _serialize_solution(sol::Solution)::Dict{String, Any}
    # Use metadata from solution
    T = time_grid(sol)
    meta = metadata(sol)
    dim_x = state_dimension(meta)
    dim_u = control_dimension(meta)
    
    # ... reste du code inchangé ...
end
```

2. Mettre à jour la docstring :

```julia
"""
    _serialize_solution(sol::Solution)::Dict{String, Any}

Serialize a solution to discrete data for export (JLD2, JSON, etc.).
Uses public getters to access solution fields and metadata for dimensions.

This function extracts all data from a solution and converts it to a
serializable format (matrices, vectors, scalars). Functions are discretized
on the time grid.

# Arguments
- `sol::Solution`: Solution to serialize

# Returns
- `Dict{String, Any}`: Dictionary containing all discrete data:
  - `"time_grid"`: Time grid
  - `"state"`, `"control"`, `"costate"`: Discretized matrices
  - `"variable"`: Variable vector
  - `"objective"`: Scalar value
  - Discretized dual functions (may be `nothing`)
  - Boundary and variable duals (vectors)
  - Solver information

# Notes
- Functions are discretized via `_discretize_function`
- `nothing` duals are preserved as `nothing`
- Compatible with `build_solution` for reconstruction
- Uses `metadata(sol)` for dimensions (no need for full model)

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
```

---

## Phase 4 : Adaptation de la sérialisation JLD2 🔧 IMPLÉMENTATION

### Étape 4.1 : Modifier `export_ocp_solution` (JLD2)

**Fichier** : `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/CTModelsJLD.jl`

**Ligne** : ~35-48

**Modifications** :

```julia
function CTModels.export_ocp_solution(
    ::CTModels.JLD2Tag, sol::CTModels.Solution; filename::String
)
    # Serialize solution to discrete data (uses metadata internally)
    data = CTModels.OCP._serialize_solution(sol)
    
    # Extract metadata from solution
    metadata = CTModels.metadata(sol)
    
    # Save both the serialized data and the metadata (NOT the full model)
    jldsave(filename * ".jld2"; solution_data=data, metadata=metadata)
    
    return nothing
end
```

**Mise à jour de la docstring** :

```julia
"""
$(TYPEDSIGNATURES)

Export an optimal control solution to a `.jld2` file using the JLD2 format.

This function serializes and saves a `CTModels.Solution` object to disk,
allowing it to be reloaded later. The solution is discretized to avoid
serialization warnings for function objects. Only minimal metadata is saved,
not the full OCP model.

# Arguments
- `::CTModels.JLD2Tag`: A tag used to dispatch the export method for JLD2.
- `sol::CTModels.Solution`: The optimal control solution to be saved.

# Keyword Arguments
- `filename::String = "solution"`: Base name of the file. The `.jld2` extension is automatically appended.

# Example
```julia-repl
julia> using JLD2
julia> export_ocp_solution(JLD2Tag(), sol; filename="mysolution")
# → creates "mysolution.jld2"
```

# Notes
- Functions are discretized on the time grid to avoid JLD2 serialization warnings
- Only `OCPMetadata` is saved, not the full `Model` (eliminates warnings)
- The solution can be perfectly reconstructed via `import_ocp_solution`
- Uses the same discretization logic as JSON export for consistency
"""
```

### Étape 4.2 : Modifier `import_ocp_solution` (JLD2)

**Fichier** : `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/CTModelsJLD.jl`

**Ligne** : ~79-119

**Modifications** :

```julia
function CTModels.import_ocp_solution(
    ::CTModels.JLD2Tag, ocp::CTModels.Model; filename::String
)
    # Load the saved data
    file_data = load(filename * ".jld2")
    data = file_data["solution_data"]
    saved_metadata = file_data["metadata"]  # ← metadata, not full model
    
    # Extract time grid - handle both TimeGridModel and raw Vector
    T = if data["time_grid"] isa CTModels.TimeGridModel
        data["time_grid"].value
    else
        data["time_grid"]
    end
    
    # Reconstruct solution using build_solution
    # Note: build_solution will create metadata from ocp, but we could also
    # use saved_metadata if we want to preserve exactly what was saved
    sol = CTModels.build_solution(
        ocp,  # ← Use provided ocp (user has it)
        T,
        data["state"],
        data["control"],
        data["variable"],
        data["costate"];
        objective = data["objective"],
        iterations = data["iterations"],
        constraints_violation = data["constraints_violation"],
        message = data["message"],
        status = data["status"],
        successful = data["successful"],
        path_constraints_dual = data["path_constraints_dual"],
        boundary_constraints_dual = data["boundary_constraints_dual"],
        state_constraints_lb_dual = data["state_constraints_lb_dual"],
        state_constraints_ub_dual = data["state_constraints_ub_dual"],
        control_constraints_lb_dual = data["control_constraints_lb_dual"],
        control_constraints_ub_dual = data["control_constraints_ub_dual"],
        variable_constraints_lb_dual = data["variable_constraints_lb_dual"],
        variable_constraints_ub_dual = data["variable_constraints_ub_dual"]
    )
    
    return sol
end
```

**Mise à jour de la docstring** :

```julia
"""
$(TYPEDSIGNATURES)

Import an optimal control solution from a `.jld2` file.

This function loads a previously saved `CTModels.Solution` from disk and
reconstructs it using `build_solution` from the discretized data.

# Arguments
- `::CTModels.JLD2Tag`: A tag used to dispatch the import method for JLD2.
- `ocp::CTModels.Model`: The associated optimal control problem model.

# Keyword Arguments
- `filename::String = "solution"`: Base name of the file. The `.jld2` extension is automatically appended.

# Returns
- `CTModels.Solution`: The reconstructed solution object.

# Example
```julia-repl
julia> using JLD2
julia> sol = import_ocp_solution(JLD2Tag(), model; filename="mysolution")
```

# Notes
- The solution is reconstructed from discretized data via `build_solution`
- This ensures perfect round-trip consistency with the export
- The provided `ocp` model is used to populate the `model` field
- Metadata is extracted from the provided `ocp` (or could use saved metadata)
- No warnings during import (only serializable data was saved)
"""
```

---

## Phase 5 : Adaptation du code de plotting 🔧 IMPLÉMENTATION

### Étape 5.1 : Vérifier les appels à `model(sol)`

**Fichiers à vérifier** :
- `ext/plot.jl`
- `ext/plot_utils.jl`
- `ext/plot_default.jl`

**Action** : Remplacer les appels à `model(sol)` par `metadata(sol)` ou gérer `nothing`

**Exemple dans `ext/plot_default.jl:151`** :

```julia
# Avant
nc = model === nothing ? 0 : CTModels.dim_path_constraints_nl(model)

# Après (si model peut être nothing)
nc = model === nothing ? 0 : CTModels.dim_path_constraints_nl(model)
# OU utiliser metadata si disponible
nc = CTModels.dim_path_constraints_nl(CTModels.metadata(sol))
```

**Note** : Le plotting accepte déjà `model === nothing`, donc peu de changements nécessaires.

### Étape 5.2 : Gérer les bornes de contraintes

**Dans `ext/plot.jl`** :

Les bornes nécessitent le modèle complet. Garder le comportement actuel :

```julia
if do_decorate_state_bounds && model !== nothing
    cs = CTModels.state_constraints_box(model)
    # ... tracer les bornes ...
end
```

**Pas de changement nécessaire** : Si `model === nothing`, les bornes ne sont pas tracées (comportement actuel).

---

## Phase 6 : Adaptation de l'affichage 🔧 IMPLÉMENTATION

### Étape 6.1 : Modifier `show(io, sol)`

**Fichier** : `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Building/solution.jl`

**Ligne** : ~755-765

**Modifications** :

```julia
# Avant
if dim_variable_constraints_box(model(sol)) > 0
    println(io, "  │  Var dual (lb) : ", variable_constraints_lb_dual(sol))
    println(io, "  └─ Var dual (ub) : ", variable_constraints_ub_dual(sol))
end

# Après
if dim_variable_constraints_box(sol) > 0  # ← Utilise l'accesseur sur sol
    println(io, "  │  Var dual (lb) : ", variable_constraints_lb_dual(sol))
    println(io, "  └─ Var dual (ub) : ", variable_constraints_ub_dual(sol))
end
```

```julia
# Avant
if dim_boundary_constraints_nl(model(sol)) > 0
    println(io, "\n• Boundary duals: ", boundary_constraints_dual(sol))
end

# Après
if dim_boundary_constraints_nl(sol) > 0  # ← Utilise l'accesseur sur sol
    println(io, "\n• Boundary duals: ", boundary_constraints_dual(sol))
end
```

---

## Phase 7 : Tests 🧪 VALIDATION

### Étape 7.1 : Tests unitaires pour `OCPMetadata`

**Fichier** : `test/suite/ocp/test_metadata.jl` (nouveau)

**Contenu** :

```julia
using Test
using CTModels

@testset "OCPMetadata" begin
    # Create a simple OCP
    ocp = Model(Variable)
    state!(ocp, 2)
    control!(ocp, 1)
    time!(ocp, [0, 1])
    
    # Extract metadata
    meta = OCPMetadata(ocp)
    
    # Test dimensions
    @test state_dimension(meta) == 2
    @test control_dimension(meta) == 1
    @test variable_dimension(meta) == 0
    @test dim_path_constraints_nl(meta) == 0
    @test dim_boundary_constraints_nl(meta) == 0
    @test dim_variable_constraints_box(meta) == 0
    
    # Test that metadata is serializable (no functions)
    @test isbitstype(typeof(meta))
end
```

### Étape 7.2 : Tests d'export/import JLD2

**Fichier** : `test/suite/serialization/test_export_import.jl`

**Ajouter** :

```julia
@testset "JLD2 export/import with metadata (no warnings)" begin
    # Create and solve a problem
    ocp, sol = ... # Use existing test problem
    
    # Export (should not generate warnings)
    filename = tempname()
    export_ocp_solution(JLD2Tag(), sol; filename=filename)
    
    # Import
    sol_imported = import_ocp_solution(JLD2Tag(), ocp; filename=filename)
    
    # Verify metadata is present
    meta = metadata(sol_imported)
    @test state_dimension(meta) == state_dimension(ocp)
    @test control_dimension(meta) == control_dimension(ocp)
    
    # Verify solutions match
    @test compare_solutions(sol, sol_imported)
    
    # Clean up
    rm(filename * ".jld2")
end
```

### Étape 7.3 : Tests de plotting

**Fichier** : `test/suite/plotting/test_plot.jl` (si existe)

**Ajouter** :

```julia
@testset "Plotting with metadata only" begin
    # Create and solve a problem
    ocp, sol = ... # Use existing test problem
    
    # Export/import to get a solution without full model
    filename = tempname()
    export_ocp_solution(JLD2Tag(), sol; filename=filename)
    sol_imported = import_ocp_solution(JLD2Tag(), ocp; filename=filename)
    
    # Plot should work (without bounds)
    @test_nowarn plot(sol_imported)
    
    # Plot with model should work (with bounds)
    @test_nowarn plot(sol_imported; model=ocp)
    
    # Clean up
    rm(filename * ".jld2")
end
```

### Étape 7.4 : Vérifier tous les tests existants

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

**Vérifier** :
- Tous les tests passent
- Pas de warnings JLD2 lors des tests de sérialisation
- Pas de régressions

---

## Phase 8 : Documentation 📚 DOCUMENTATION

### Étape 8.1 : Documenter `OCPMetadata` dans la doc utilisateur

**Fichier** : `docs/src/api_reference.jl` ou équivalent

**Ajouter** :

```julia
# OCP Metadata
OCPMetadata
metadata
```

### Étape 8.2 : Ajouter un exemple d'utilisation

**Fichier** : `docs/src/examples/serialization.md` (nouveau ou existant)

**Contenu** :

```markdown
# Serialization and Metadata

## Exporting and Importing Solutions

Solutions can be exported to JLD2 or JSON format for persistence:

```julia
using CTModels, JLD2

# Solve a problem
ocp = Model(...)
sol = solve(ocp)

# Export to JLD2 (no warnings!)
export_ocp_solution(JLD2Tag(), sol; filename="mysolution")

# Import later
sol_imported = import_ocp_solution(JLD2Tag(), ocp; filename="mysolution")
```

## Working with Metadata

After import, solutions contain minimal metadata instead of the full model:

```julia
# Access metadata
meta = metadata(sol_imported)

# Get dimensions
n = state_dimension(meta)
m = control_dimension(meta)

# Plot works without full model
plot(sol_imported)

# Plot with bounds requires full model
plot(sol_imported; model=ocp)
```

## Benefits

- **No serialization warnings**: Only data is saved, no functions
- **Smaller files**: Metadata is ~48 bytes vs full model
- **Faster I/O**: Less data to write/read
```

### Étape 8.3 : Mettre à jour CHANGELOG.md

**Fichier** : `CHANGELOG.md`

**Ajouter** :

```markdown
## [Unreleased]

### Added
- `OCPMetadata` structure for minimal serializable OCP information
- `metadata(sol)` accessor to get metadata from solutions
- Dimension accessors on `Solution` (forward to metadata)

### Changed
- `Solution` now stores both `model` (optional) and `metadata` (required)
- JLD2 export now saves only `metadata`, not full `model` (eliminates warnings)
- `model(sol)` may return `nothing` after import (use `metadata(sol)` instead)

### Deprecated
- `model(sol)` is deprecated in favor of `metadata(sol)` for accessing dimensions

### Fixed
- JLD2 serialization warnings when exporting solutions
- Reduced file size for exported solutions
```

---

## Checklist de validation finale ✅

Avant de considérer l'implémentation complète, vérifier :

- [ ] `OCPMetadata` défini dans `src/OCP/Types/metadata.jl`
- [ ] `metadata` exporté dans `src/CTModels.jl`
- [ ] `Solution` modifié avec champs `model` et `metadata`
- [ ] `build_solution` crée `metadata` depuis `ocp`
- [ ] `_serialize_solution` utilise `metadata` au lieu de `ocp`
- [ ] Export JLD2 sauve `metadata` au lieu de `model`
- [ ] Import JLD2 reconstruit solution avec `ocp` fourni
- [ ] Accesseurs de dimension sur `Solution` fonctionnent
- [ ] Affichage (`show`) utilise accesseurs sur `sol`
- [ ] Plotting fonctionne avec et sans `model`
- [ ] Tests unitaires pour `OCPMetadata` passent
- [ ] Tests d'export/import sans warnings passent
- [ ] Tests de plotting passent
- [ ] Tous les tests existants passent
- [ ] Documentation mise à jour
- [ ] CHANGELOG.md mis à jour
- [ ] Pas de breaking changes (Option C respectée)

---

## Timeline estimée

- **Phase 1** : 30 min (création fichier, exports)
- **Phase 2** : 1h (modification Solution, accesseurs)
- **Phase 3** : 30 min (adaptation build_solution, _serialize_solution)
- **Phase 4** : 30 min (adaptation JLD2)
- **Phase 5** : 30 min (vérification plotting)
- **Phase 6** : 15 min (adaptation affichage)
- **Phase 7** : 1h30 (tests)
- **Phase 8** : 30 min (documentation)

**Total** : ~5 heures

---

## Support et références

### Documents d'analyse

- `03_ocp_field_analysis.md` - Analyse complète du problème
- `04_plotting_metadata_investigation.md` - Métadonnées pour plotting
- `05_bounds_metadata_analysis.md` - Décision sur les bornes

### Fichiers sources clés

- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Types/solution.jl`
- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Building/solution.jl`
- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/CTModelsJLD.jl`

---

**Auteur** : CTModels Development Team  
**Date** : 2026-01-30  
**Statut** : 📋 Prêt pour implémentation
