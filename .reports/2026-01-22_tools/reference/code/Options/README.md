# Options Module - Code Annexes

This directory contains the reference implementation for the **Options** module.

---

## Structure

### `contract/` - What Users Must Implement

Types and structures that define the contract for option handling:

- **[option_value.jl](contract/option_value.jl)** - `OptionValue` type (value + source)
- **[option_schema.jl](contract/option_schema.jl)** - `OptionSchema` type (name, type, default, aliases, validator)

### `api/` - What the System Provides

Functions provided by the Options module:

- **[extraction.jl](api/extraction.jl)** - `extract_option()`, `extract_options()` functions

---

## Contract vs API

**CONTRACT** (in `contract/`):
- Data structures users interact with
- Types that define how options are represented

**API** (in `api/`):
- Functions the system provides
- Tools for extracting and validating options

---

## See Also

- [../README.md](../README.md) - Overall code annexes documentation
- [../../13_module_dependencies_architecture.md](../../13_module_dependencies_architecture.md) - Module architecture
