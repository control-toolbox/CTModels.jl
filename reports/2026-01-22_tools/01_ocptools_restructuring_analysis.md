# Strategies Restructuring Analysis

**Date**: 2026-01-22  
**Author**: Analysis for CTModels refactoring  
**Status**: Draft - Ideas and Planning

---

## Executive Summary

This report analyzes the current `AbstractStrategy` system in CTModels and proposes a restructuring into a dedicated sub-module. The goal is to clarify the concept, simplify the interface, and improve developer experience while maintaining the flexibility needed by OptimalControl.jl's solve infrastructure.

---

## 1. Current State Analysis

### 1.1 What is an OCPTool?

An `AbstractStrategy` is a **configurable component** in the optimal control solving pipeline. Currently, three categories exist:

1. **Discretizers** (in CTDirect.jl): `CollocationDiscretizer`, etc.
2. **Modelers** (in CTModels.jl): `ADNLPModeler`, `ExaModeler`
3. **Solvers** (in CTSolvers.jl): `IpoptSolver`, `MadNLPSolver`, `KnitroSolver`, `MadNCLSolver`

Each tool:
- Has **configurable options** (e.g., `grid_size`, `backend`, `max_iter`)
- Stores **option values** and their **provenance** (user-supplied vs. default)
- Can be **introspected** (list options, get descriptions, validate types)
- Has a **symbolic identifier** (`:adnlp`, `:ipopt`, etc.)

### 1.2 Current Implementation

**Location**: All in [`src/nlp/options_schema.jl`](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/nlp/options_schema.jl) (581 lines)

**Core types**:
- `AbstractStrategy` - abstract base type
- `OptionSpec` - metadata for a single option (type, default, description)

**Interface contract** (what tools must implement):

**Type-level contract** (static metadata):
```julia
# REQUIRED: Symbolic identifier
symbol(::Type{<:MyTool}) = :mytool

# REQUIRED: Option specifications (can be empty)
metadata(::Type{<:MyTool}) = (
    option1 = OptionSpec(type=Int, default=42, description="..."),
)

# OPTIONAL: Package name for display
package_name(::Type{<:MyTool}) = "MyPackage"
```

**Instance-level contract** (configured state):
```julia
struct MyTool <: AbstractStrategy
    options::StrategyOptions  # Contains values + sources
end

# REQUIRED: Access to configured options
options(tool::MyTool) = tool.options

# Constructor pattern:
MyTool(; kwargs...) = MyTool(build_strategy_options(MyTool; kwargs...))
```

**API provided**:
- **Type-level introspection**: `symbol()`, `metadata()`, `package_name()`
- **Option metadata**: `options_keys()`, `option_type()`, `option_description()`, `option_default()`, `default_options()`
- **Instance access**: `options()`, `get_option_value()`, `get_option_source()`, `get_option_default()`
- **Display**: `show_options()`
- **Construction**: `build_strategy_options()` - validates and merges defaults with user input (returns `StrategyOptions`)
- **Utilities**: Levenshtein distance for typo suggestions, option filtering
- **Validation**: `validate_tool_contract()` - for debugging and testing

**Registration system**:
```julia
# In nlp_backends.jl
const REGISTERED_MODELERS = (ADNLPModeler, ExaModeler)
modeler_symbols() = Tuple(symbol(T) for T in REGISTERED_MODELERS)
build_modeler_from_symbol(:adnlp; kwargs...) -> ADNLPModeler(; kwargs...)
```

Similar patterns exist in CTDirect (discretizers) and CTSolvers (solvers).

### 1.3 Usage in OptimalControl.jl

**Key insight**: The registration system is **essential** for the description-based solve API.

From [`solve.jl`](https://github.com/control-toolbox/OptimalControl.jl/blob/breaking/ctmodels-0.7/src/solve.jl):

```julia
# User writes:
sol = solve(ocp, :collocation, :adnlp, :ipopt; grid_size=100, max_iter=1000)

# OptimalControl.jl:
# 1. Completes partial description to (:collocation, :adnlp, :ipopt)
# 2. Extracts symbols for each tool category
discretizer_sym = :collocation  # from CTDirect.discretizer_symbols()
modeler_sym = :adnlp           # from CTModels.modeler_symbols()
solver_sym = :ipopt            # from CTSolvers.solver_symbols()

# 3. Routes options to correct tools
disc_keys = _discretizer_options_keys(method)  # Uses options_keys(disc_type)
model_keys = _modeler_options_keys(method)     # Uses options_keys(model_type)
solver_keys = _solver_options_keys(method)     # Uses options_keys(solver_type)

# 4. Builds tools from symbols
discretizer = CTDirect.build_discretizer_from_symbol(:collocation; grid_size=100)
modeler = CTModels.build_modeler_from_symbol(:adnlp)
solver = CTSolvers.build_solver_from_symbol(:ipopt; max_iter=1000)

# 5. Displays configuration using tool_package_name() and _options_values()
```

**Option routing** handles ambiguity:
- If `grid_size` only belongs to discretizer → automatic routing
- If `backend` belongs to both modeler and solver → user must disambiguate:
  ```julia
  solve(ocp, :collocation, :exa, :ipopt; backend=(:cpu, :modeler))
  ```

**Display output** shows all options with provenance:
```
▫ This is CTSolvers version v0.x running with: collocation, adnlp, ipopt.

   ┌─ The NLP is modelled with ADNLPModels and solved with NLPModelsIpopt.
   │
   Options:
   ├─ Discretizer:
   │    grid_size = 100  (:user)
   │    scheme = :trapeze  (:ct_default)
   ├─ Modeler:
   │    backend = :optimized  (:ct_default)
   └─ Solver:
        max_iter = 1000  (:user)
        tol = 1e-8  (:ct_default)
```

---

## 2. Problems with Current Design

### 2.1 Monolithic File Structure

All 581 lines in one file makes it hard to:
- Navigate and understand different concerns
- Maintain and extend functionality
- Separate public API from internal utilities

### 2.2 Registration Boilerplate

Each package (CTModels, CTDirect, CTSolvers) must:
1. Define `REGISTERED_TOOLS` constant
2. Implement `tool_symbols()` function
3. Implement `_tool_type_from_symbol()` with error handling
4. Implement `build_tool_from_symbol()`

This is repetitive and error-prone.

### 2.3 Unclear Benefits (Before Analysis)

**Before understanding OptimalControl.jl usage**, the registration system seemed unnecessary. **Now it's clear**: it enables the elegant description-based API that users love.

However, the **implementation could be cleaner**:
- Could use a macro to generate registration boilerplate
- Could provide base implementations in Strategies module
- Could auto-generate symbol lists from type hierarchy

### 2.4 Scattered Documentation

The interface contract is documented in:
- Type docstring in [`core/types/nlp.jl`](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/core/types/nlp.jl)
- Function docstrings in `options_schema.jl`
- Comments in implementation files

A **single source of truth** would help developers implement new tools correctly.

---

## 3. Proposed Architecture

### 3.1 Module Structure

Create `CTModels.Strategies` sub-module with clear separation of concerns:

```
src/ocptools/
├── Strategies.jl              # Module definition, exports
├── types.jl                 # AbstractStrategy, OptionSpec, StrategyOptions
├── interface.jl             # Core interface: symbol, metadata, package_name, options
├── options_api.jl           # Public API: options_keys, get_option_value, show_options
├── options_builder.jl       # build_strategy_options, validation, merging
├── options_utils.jl         # Utilities: filtering, Levenshtein distance, suggestions
├── registration.jl          # Registration system: macros and base implementations
├── validation.jl            # validate_tool_contract for debugging/testing
└── README.md                # Developer guide: how to implement a new tool
```

**Estimated line counts**:
- `types.jl`: ~70 lines (AbstractStrategy, OptionSpec, StrategyOptions + constructors)
- `interface.jl`: ~80 lines (type/instance contract methods with CTBase.NotImplemented defaults)
- `options_api.jl`: ~150 lines (public introspection API)
- `options_builder.jl`: ~120 lines (construction and validation)
- `options_utils.jl`: ~80 lines (utilities)
- `registration.jl`: ~100 lines (macros and helpers)
- `validation.jl`: ~60 lines (contract validation)
- `README.md`: comprehensive guide

**Total**: ~660 lines of code + documentation

### 3.2 Simplified Registration

**Idea 1: Registration Macro**

Instead of manual boilerplate, provide a macro:

```julia
# In CTModels/src/nlp/nlp_backends.jl
@register_tools :modeler begin
    ADNLPModeler => :adnlp
    ExaModeler => :exa
end

# Expands to:
const REGISTERED_MODELERS = (ADNLPModeler, ExaModeler)
modeler_symbols() = (:adnlp, :exa)
_modeler_type_from_symbol(sym) = ... # with error handling
build_modeler_from_symbol(sym; kwargs...) = ...
```

**Idea 2: Automatic Discovery**

Use Julia's type system to auto-discover tools:

```julia
# Tools register themselves via trait
Strategies.tool_category(::Type{<:ADNLPModeler}) = :modeler
Strategies.tool_category(::Type{<:IpoptSolver}) = :solver

# Auto-generate lists
all_modelers() = filter(T -> tool_category(T) == :modeler, subtypes(AbstractStrategy))
```

**Recommendation**: Start with **Idea 1 (macro)** for explicit control, consider Idea 2 for future enhancement.

### 3.3 Interface Clarification

**Create a clear contract** in `README.md`:

```markdown
# Implementing a New OCPTool

## Step 1: Define the Type

struct MyTool{Vals,Srcs} <: CTModels.Strategies.AbstractStrategy
    options_values::Vals
    options_sources::Srcs
end

## Step 2: Implement Required Methods

# Symbolic identifier (required)
CTModels.Strategies.symbol(::Type{<:MyTool}) = :mytool

# Option specifications (optional, but recommended)
function CTModels.Strategies._option_specs(::Type{<:MyTool})
    return (
        my_option = OptionSpec(
            type = Int,
            default = 42,
            description = "An example option"
        ),
    )
end

# Package name (optional, for display)
CTModels.Strategies.tool_package_name(::Type{<:MyTool}) = "MyPackage"

## Step 3: Define Constructor

function MyTool(; kwargs...)
    values, sources = CTModels.Strategies._build_ocp_tool_options(
        MyTool; kwargs..., strict_keys=true
    )
    return MyTool{typeof(values), typeof(sources)}(values, sources)
end

## Step 4: Register (if part of a tool family)

@register_tools :mytool_category begin
    MyTool => :mytool
end
```

### 3.4 Enhanced Features (Ideas for Future)

**Option validation enhancements**:
- Custom validators: `OptionSpec(type=Int, validator=x -> x > 0)`
- Dependent options: `OptionSpec(requires=[:other_option])`
- Mutually exclusive options

**Serialization**:
- Save/load tool configurations to TOML/JSON
- Useful for reproducible research

**Option presets**:
```julia
modeler = ADNLPModeler(preset=:fast)  # Loads predefined option set
```

**Better error messages**:
- Show option documentation in error messages
- Suggest similar option names across all tools (not just current tool)

---

## 4. Migration Strategy

### 4.1 Breaking Changes Allowed

Since we can break compatibility:
1. Move `AbstractStrategy` from `core/types/nlp.jl` to `ocptools/types.jl`
2. Change import paths: `CTModels.AbstractStrategy` → `CTModels.Strategies.AbstractStrategy`
3. Rename internal functions for clarity (e.g., `_option_specs` → `option_specs` if we want it public)

### 4.2 Phased Approach

**Phase 1**: Create new module structure
- Implement `Strategies` sub-module
- Keep old code in `options_schema.jl` temporarily
- Re-export from old locations for compatibility

**Phase 2**: Migrate CTModels tools
- Update `ADNLPModeler` and `ExaModeler`
- Update tests
- Remove old code

**Phase 3**: Update dependent packages
- CTDirect.jl (discretizers)
- CTSolvers.jl (solvers)
- OptimalControl.jl (usage)

**Phase 4**: Cleanup
- Remove compatibility shims
- Update all documentation
- Announce breaking changes

### 4.3 Testing Strategy

**Unit tests** for each file:
- `test/ocptools/test_types.jl`
- `test/ocptools/test_interface.jl`
- `test/ocptools/test_options_api.jl`
- `test/ocptools/test_options_builder.jl`
- `test/ocptools/test_registration.jl`

**Integration tests**:
- Test with actual tools (ADNLPModeler, ExaModeler)
- Test registration macros
- Test option routing in OptimalControl.jl scenarios

**Regression tests**:
- Ensure all existing functionality still works
- Compare outputs with old implementation

---

## 5. Open Questions & Decisions Needed

### 5.1 Naming

- **Module name**: `Strategies` vs `Tools` vs `ToolsAPI`?
- **Function names**: Keep `_option_specs` private or make `option_specs` public?
- **Registration**: `@register_tools` vs `@register_ocp_tools`?

### 5.2 Scope

- Should `AbstractStrategy` support **non-option state**? (e.g., cached computations)
- Should we support **tool composition**? (e.g., a tool that wraps another tool)
- Should we provide **abstract base types** for each category? (`AbstractModeler`, `AbstractSolver`)

### 5.3 Registration System

- **Keep current approach** (explicit registration) or **auto-discovery**?
- Should registration be **mandatory** or **optional**?
- Should we support **runtime registration** (plugins)?

### 5.4 Documentation

- Where should the main developer guide live?
  - In `src/ocptools/README.md`?
  - In `docs/src/developer/ocptools.md`?
  - Both (with one as source of truth)?

---

## 6. Next Steps

1. **Review this report** and discuss design decisions
2. **Create implementation plan** with detailed file-by-file breakdown
3. **Prototype registration macro** to validate approach
4. **Implement Phase 1** (new module structure)
5. **Migrate one tool** (e.g., ADNLPModeler) as proof of concept
6. **Iterate** based on feedback

---

## 7. References

- Current implementation: [`src/nlp/options_schema.jl`](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/nlp/options_schema.jl)
- Type definitions: [`src/core/types/nlp.jl`](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/core/types/nlp.jl)
- Modeler registration: [`src/nlp/nlp_backends.jl`](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/nlp/nlp_backends.jl)
- OptimalControl.jl usage: [solve.jl](https://github.com/control-toolbox/OptimalControl.jl/blob/breaking/ctmodels-0.7/src/solve.jl)
- CTSolvers registration: [backends_types.jl](https://github.com/control-toolbox/CTSolvers.jl/blob/51a17602434e5151aa65013b22fee05eea18b432/src/ctsolvers/backends_types.jl)

---

## Appendix: Code Size Comparison

**Current** (monolithic):
- `options_schema.jl`: 581 lines

**Proposed** (modular):
- `types.jl`: ~50 lines
- `interface.jl`: ~40 lines
- `options_api.jl`: ~150 lines
- `options_builder.jl`: ~120 lines
- `options_utils.jl`: ~80 lines
- `registration.jl`: ~100 lines
- **Total code**: ~540 lines
- **Documentation**: `README.md` (~200 lines)

**Benefits**:
- Similar code size, but **better organized**
- **Easier to navigate** and understand
- **Clearer separation** of concerns
- **Better documentation** for developers
