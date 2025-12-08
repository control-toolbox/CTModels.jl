#  Copyright 2023, Oscar Dowson and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
#  Modified November 2025 for CTBenchmarks.jl:
#  - Separated public and private API documentation into distinct pages
#  - Added robust handling for missing docstrings (warnings instead of errors)
#  - Included non-exported symbols in API reference
#  - Filtered internal compiler-generated symbols (starting with '#')

module DocumenterReference

using CTBase: CTBase
using Documenter: Documenter
using Markdown: Markdown
using MarkdownAST: MarkdownAST

"""
    DocType

Enumeration of documentation element types recognized by the API reference generator.

# Values

- `DOCTYPE_ABSTRACT_TYPE`: An abstract type declaration
- `DOCTYPE_CONSTANT`: A constant binding (including non-function, non-type values)
- `DOCTYPE_FUNCTION`: A function or callable
- `DOCTYPE_MACRO`: A macro (name starts with `@`)
- `DOCTYPE_MODULE`: A submodule
- `DOCTYPE_STRUCT`: A concrete struct type
"""
@enum(
    DocType,
    DOCTYPE_ABSTRACT_TYPE,
    DOCTYPE_CONSTANT,
    DOCTYPE_FUNCTION,
    DOCTYPE_MACRO,
    DOCTYPE_MODULE,
    DOCTYPE_STRUCT,
)

"""
    _Config

Internal configuration for API reference generation.

# Fields

- `current_module::Module`: The module being documented.
- `subdirectory::String`: Output directory for generated API pages.
- `modules::Dict{Module,<:Vector}`: Mapping of modules to extras (reserved for future use).
- `sort_by::Function`: Custom sort function for symbols.
- `exclude::Set{Symbol}`: Symbol names to exclude from documentation.
- `public::Bool`: Flag to generate public API page.
- `private::Bool`: Flag to generate private API page.
- `title::String`: Title displayed at the top of the generated page.
- `title_in_menu::String`: Title displayed in the navigation menu.
- `source_files::Vector{String}`: Absolute source file paths used to filter documented symbols (empty means no filtering).
- `filename::String`: Base filename (without extension) for the markdown file.
- `include_without_source::Bool`: If `true`, include symbols whose source file cannot be determined.
- `external_modules_to_document::Vector{Module}`: Additional modules to search for docstrings (e.g., `Base`).
"""
struct _Config
    current_module::Module
    subdirectory::String
    modules::Dict{Module,<:Vector}
    sort_by::Function
    exclude::Set{Symbol}
    public::Bool
    private::Bool
    title::String
    title_in_menu::String
    source_files::Vector{String}
    filename::String
    include_without_source::Bool  # Include symbols whose source file cannot be determined
    external_modules_to_document::Vector{Module}   # Additional modules to search for docstrings (e.g., Base)
end

"""
    CONFIG::Vector{_Config}

Global configuration storage for API reference generation.

Each call to [`automatic_reference_documentation`](@ref) appends a new `_Config`
entry to this vector. Use [`reset_config!`](@ref) to clear it between builds.
"""
const CONFIG = _Config[]

"""
    reset_config!()

Clear the global `CONFIG` vector. Useful between documentation builds or for testing.
"""
function reset_config!()
    empty!(CONFIG)
    return nothing
end

"""
    APIBuilder <: Documenter.Builder.DocumentPipeline

Custom Documenter pipeline stage for automatic API reference generation.

This builder is inserted into the Documenter pipeline at order `0.0` (before
most other stages) to generate API reference pages from the configurations
stored in [`CONFIG`](@ref).
"""
abstract type APIBuilder <: Documenter.Builder.DocumentPipeline end

"""
    Documenter.Selectors.order(::Type{APIBuilder}) -> Float64

Return the pipeline order for [`APIBuilder`](@ref).

# Returns

- `Float64`: Always `0.0`, placing this stage early in the Documenter pipeline.
"""
Documenter.Selectors.order(::Type{APIBuilder}) = 0.0

"""
    _default_basename(filename::String, public::Bool, private::Bool) -> String

Compute the default base filename for the generated markdown file.

# Logic
- If `filename` is non-empty, use it.
- If only `public` is true, use `"public"`.
- If only `private` is true, use `"private"`.
- If both are true, use `"api"`.

# Arguments
- `filename::String`: User-provided filename (may be empty)
- `public::Bool`: Whether public API is requested
- `private::Bool`: Whether private API is requested

# Returns
- `String`: The base filename to use (without extension)
"""
function _default_basename(filename::String, public::Bool, private::Bool)
    if filename != ""
        return filename
    elseif public && private
        return "api"
    elseif public
        return "public"
    else
        return "private"
    end
end

"""
    _build_page_path(subdirectory::String, filename::String) -> String

Build the page path by joining subdirectory and filename.

Handles special cases where `subdirectory` is `"."` or empty, returning just
the filename in those cases.

# Arguments

- `subdirectory::String`: Directory path (may be `"."` or empty).
- `filename::String`: The filename to append.

# Returns

- `String`: The combined path, or just `filename` if subdirectory is `"."` or empty.
"""
function _build_page_path(subdirectory::String, filename::String)
    if subdirectory == "." || subdirectory == ""
        return filename
    else
        return "$subdirectory/$filename"
    end
end

"""
    automatic_reference_documentation(;
        subdirectory::String,
        primary_modules,
        sort_by::Function = identity,
        exclude::Vector{Symbol} = Symbol[],
        public::Bool = true,
        private::Bool = true,
        title::String = "API Reference",
        filename::String = "",
        source_files::Vector{String} = String[],
        include_without_source::Bool = false,
        external_modules_to_document::Vector{Module} = Module[],
    )

Automatically creates the API reference documentation for one or more modules and
returns a `Vector` which can be used in the `pages` argument of
`Documenter.makedocs`.

## Arguments

 * `subdirectory`: the directory relative to the documentation root in which to
   write the API files.
 * `primary_modules`: a vector of modules or `module => extras` pairs to document.
   Extras are currently unused but reserved for future extensions.
 * `sort_by`: a custom sort function applied to symbol lists.
 * `exclude`: vector of symbol names to skip from the generated API (applied to
   both public and private symbols).
 * `public`: flag to generate public API page (default: `true`).
 * `private`: flag to generate private API page (default: `true`).
 * `title`: title displayed at the top of the generated page (default: "API Reference").
 * `title_in_menu`: title displayed in the navigation menu (default: same as `title`).
 * `filename`: base filename (without extension) used for the underlying markdown
   file. Defaults: `"public"` if only public, `"private"` if only private,
   `"api"` if both.
 * `source_files`: source file paths to filter documented symbols. Only symbols
   defined in these files will be included. Paths are normalized to absolute.
 * `include_without_source`: if `true`, include symbols whose source file cannot
   be determined (e.g., abstract types, some constants). Default: `false`.
 * `external_modules_to_document`: additional modules to search for docstrings
   (e.g., `[Base]` to include `Base.showerror` documentation). Methods from these
   modules that are defined in `source_files` will be documented. Default: empty.

## Multiple instances

Each time you call this function, a new object is added to the global variable
`DocumenterReference.CONFIG`. Use `reset_config!()` to clear it between builds.
"""
#function CTBase.automatic_reference_documentation(
function automatic_reference_documentation(
#    ::CTBase.DocumenterReferenceTag
    ;
    subdirectory::String,
    primary_modules::Vector,
    sort_by::Function=identity,
    exclude::Vector{Symbol}=Symbol[],
    public::Bool=true,
    private::Bool=true,
    title::String="API Reference",
    title_in_menu::String="",
    filename::String="",
    source_files::Vector{String}=String[],
    include_without_source::Bool=false,
    external_modules_to_document::Vector{Module}=Module[],
)
    # Convert primary_modules to a dict, handling both plain modules and Module => files pairs
    function _to_extras(m::Module)
        return m => String[]  # Plain module: no specific files
    end
    function _to_extras(m::Pair)
        mod = first(m)
        files = last(m)
        # Handle both Vector{String} and single String
        if files isa Vector
            normalized_files = [abspath(f) for f in files]
        else
            normalized_files = [abspath(files)]
        end
        return mod => normalized_files
    end
    _modules = Dict(_to_extras(m) for m in primary_modules)
    
    exclude_set = Set(exclude)
    
    # Normalize global source_files (used as fallback if no module-specific files)
    normalized_source_files =
        isempty(source_files) ? String[] : [abspath(path) for path in source_files]

    if !public && !private
        error(
            "automatic_reference_documentation: both `public` and `private` cannot be false.",
        )
    end

    # Effective title_in_menu defaults to title if not provided
    effective_title_in_menu = title_in_menu == "" ? title : title_in_menu

    # For single-module case, return structure directly based on public/private flags
    if length(primary_modules) == 1
        current_module = first(_to_extras(primary_modules[1]))
        # Compute effective filename using defaults
        effective_filename = _default_basename(filename, public, private)
        push!(
            CONFIG,
            _Config(
                current_module,
                subdirectory,
                _modules,
                sort_by,
                exclude_set,
                public,
                private,
                title,
                effective_title_in_menu,
                normalized_source_files,
                effective_filename,
                include_without_source,
                external_modules_to_document,
            ),
        )
        if public && private
            # Both pages: use subdirectory with public.md and private.md
            return effective_title_in_menu => [
                "Public" => _build_page_path(subdirectory, "public.md"),
                "Private" => _build_page_path(subdirectory, "private.md"),
            ]
        elseif public
            return effective_title_in_menu =>
                _build_page_path(subdirectory, "$effective_filename.md")
        else
            return effective_title_in_menu =>
                _build_page_path(subdirectory, "$effective_filename.md")
        end
    end

    # For multi-module case:
    # If filename is provided, generate a single combined page for all modules.
    # Otherwise, create a per-module subdirectory (original behavior).
    effective_filename = _default_basename(filename, public, private)
    
    if filename != ""
        # Combined page for all modules
        for m in primary_modules
            current_module = first(_to_extras(m))
            push!(
                CONFIG,
                _Config(
                    current_module,
                    subdirectory,
                    _modules,
                    sort_by,
                    exclude_set,
                    public,
                    private,
                    title,
                    effective_title_in_menu,
                    normalized_source_files,
                    effective_filename,
                    include_without_source,
                    external_modules_to_document,
                ),
            )
        end
        if public && private
            return effective_title_in_menu => [
                "Public" => _build_page_path(subdirectory, "public.md"),
                "Private" => _build_page_path(subdirectory, "private.md"),
            ]
        elseif public
            return effective_title_in_menu =>
                _build_page_path(subdirectory, "$effective_filename.md")
        else
            return effective_title_in_menu =>
                _build_page_path(subdirectory, "$effective_filename.md")
        end
    else
        # Per-module subdirectory (original behavior)
        list_of_pages = Any[]
        for m in primary_modules
            current_module = first(_to_extras(m))
            module_subdir = joinpath(subdirectory, string(current_module))
            pages = _automatic_reference_documentation(
                current_module;
                subdirectory=module_subdir,
                modules=_modules,
                sort_by,
                exclude=exclude_set,
                public,
                private,
                source_files=normalized_source_files,
                include_without_source,
                external_modules_to_document,
            )
            push!(list_of_pages, "$current_module" => pages)
        end
        return effective_title_in_menu => list_of_pages
    end
end

"""
    _automatic_reference_documentation(current_module; subdirectory, modules, sort_by, exclude)

Internal helper for single-module API reference generation.

Registers the module configuration and returns the output path for the generated documentation.

# Arguments
- `current_module::Module`: Module to document
- `subdirectory::String`: Output directory for API pages
- `modules::Dict{Module,<:Vector}`: Module mapping
- `sort_by::Function`: Custom sort function
- `exclude::Set{Symbol}`: Symbols to exclude
- `public::Bool`: Flag to generate public API page
- `private::Bool`: Flag to generate private API page
- `source_files::Vector{String}`: Absolute source file paths used to filter documented symbols (empty means no filtering)

# Returns
- `String`: Path to the generated API documentation file
"""
function _automatic_reference_documentation(
    current_module::Module;
    subdirectory::String,
    modules::Dict{Module,<:Vector},
    sort_by::Function,
    exclude::Set{Symbol},
    public::Bool,
    private::Bool,
    source_files::Vector{String},
    include_without_source::Bool=false,
    external_modules_to_document::Vector{Module}=Module[],
)
    effective_filename = _default_basename("", public, private)
    # For multi-module case, use default titles
    default_title = if public && !private
        "Public API"
    else
        (!public && private ? "Private API" : "API Reference")
    end
    push!(
        CONFIG,
        _Config(
            current_module,
            subdirectory,
            modules,
            sort_by,
            exclude,
            public,
            private,
            default_title,
            default_title,
            source_files,
            effective_filename,
            include_without_source,
            external_modules_to_document,
        ),
    )
    if public && private
        return [
            "Public" => _build_page_path(subdirectory, "public.md"),
            "Private" => _build_page_path(subdirectory, "private.md"),
        ]
    elseif public
        return _build_page_path(subdirectory, "$effective_filename.md")
    else
        return _build_page_path(subdirectory, "$effective_filename.md")
    end
end

"""
    _classify_symbol(obj, name_str::String) -> DocType

Classify a symbol by its type (function, macro, struct, constant, module, abstract type).

# Arguments
- `obj`: The object bound to the symbol
- `name_str::String`: String representation of the symbol name

# Returns
- `DocType`: The classification of the symbol
"""
function _classify_symbol(obj, name_str::String)
    # Check for macro (name starts with @)
    if startswith(name_str, "@")
        return DOCTYPE_MACRO
    end
    # Check for module
    if obj isa Module
        return DOCTYPE_MODULE
    end
    # Check for abstract type
    if obj isa Type && isabstracttype(obj)
        return DOCTYPE_ABSTRACT_TYPE
    end
    # Check for concrete type / struct
    if obj isa Type
        return DOCTYPE_STRUCT
    end
    # Check for function
    if obj isa Function
        return DOCTYPE_FUNCTION
    end
    # Everything else is a constant
    return DOCTYPE_CONSTANT
end

"""
    _get_source_file(mod::Module, key::Symbol, type::DocType) -> Union{String, Nothing}

Determine the source file path where a symbol is defined.

Supports functions, types (via constructors), macros, and constants.
Returns `nothing` if the source file cannot be determined.

# Arguments
- `mod::Module`: The module containing the symbol
- `key::Symbol`: The symbol name
- `type::DocType`: The type classification of the symbol

# Returns
- `Union{String, Nothing}`: Absolute path to the source file, or `nothing`
"""
function _get_source_file(mod::Module, key::Symbol, type::DocType)
    try
        # Strategy 1 (most reliable): Try docstring metadata
        # This works for all documented symbols (constants, types, functions, etc.)
        binding = Base.Docs.Binding(mod, key)
        meta = Base.Docs.meta(mod)
        if haskey(meta, binding)
            docs = meta[binding]
            if isa(docs, Base.Docs.MultiDoc) && !isempty(docs.docs)
                for (sig, docstr) in docs.docs
                    if isa(docstr, Base.Docs.DocStr) && haskey(docstr.data, :path)
                        path = docstr.data[:path]
                        if path !== nothing && path != ""
                            return abspath(String(path))
                        end
                    end
                end
            end
        end

        obj = getfield(mod, key)

        # Strategy 2: For functions and macros, use methods()
        if obj isa Function
            m_list = methods(obj)
            for m in m_list
                file = String(m.file)
                if file != "<built-in>" && file != "none" && !startswith(file, ".")
                    return abspath(file)
                end
            end
        end

        # Strategy 3: For concrete types, try constructor methods
        if obj isa Type && !isabstracttype(obj)
            m_list = methods(obj)
            for m in m_list
                file = String(m.file)
                if file != "<built-in>" && file != "none" && !startswith(file, ".")
                    return abspath(file)
                end
            end
        end

        # Strategy 4: For modules
        if obj isa Module
            # Modules are tricky - we cannot reliably determine their source file
            return nothing
        end

        return nothing
    catch e
        @debug "Could not determine source file for $key in $mod: $e"
        return nothing
    end
end

"""
    _exported_symbols(mod)

Classify all symbols in a module into exported and private categories.

Inspects the module's public API and internal symbols, filtering out compiler-generated
names and imported symbols. Classifies each symbol by type (function, struct, macro, etc.).

# Arguments
- `mod::Module`: Module to analyze

# Returns
- `NamedTuple`: With fields `exported` and `private`, each containing sorted lists of `(Symbol, DocType)` pairs
"""
function _exported_symbols(mod)
    exported = Pair{Symbol,DocType}[]
    private = Pair{Symbol,DocType}[]
    exported_names = Set(names(mod; all=false))  # Only exported symbols

    # Use all=true, imported=false to include non-exported (private) symbols
    # defined in this module, but skip names imported from other modules.
    for n in names(mod; all=true, imported=false)
        name_str = String(n)
        # Skip internal compiler-generated symbols like #save_json##... which
        # do not have meaningful bindings for documentation.
        if startswith(name_str, "#")
            continue
        end
        # Skip the module itself
        if n == nameof(mod)
            continue
        end

        local f
        try
            f = getfield(mod, n)
        catch
            continue
        end

        doc_type = _classify_symbol(f, name_str)

        # Separate exported from private
        if n in exported_names
            push!(exported, n => doc_type)
        else
            push!(private, n => doc_type)
        end
    end

    order = Dict(
        DOCTYPE_MODULE => 0,
        DOCTYPE_MACRO => 1,
        DOCTYPE_FUNCTION => 2,
        DOCTYPE_ABSTRACT_TYPE => 3,
        DOCTYPE_STRUCT => 4,
        DOCTYPE_CONSTANT => 5,
    )
    sort_fn = x -> (order[x[2]], "$(x[1])")
    return (exported=sort(exported; by=sort_fn), private=sort(private; by=sort_fn))
end

"""
    _iterate_over_symbols(f, config, symbol_list)

Iterate over symbols, applying a function to each documented symbol.

Filters symbols based on:
1. Exclusion list (`config.exclude`)
2. Presence of documentation (warns and skips undocumented symbols)
3. Source file filtering (`config.source_files`)

# Arguments

- `f::Function`: Callback function `f(key::Symbol, type::DocType)` applied to each valid symbol.
- `config::_Config`: Configuration containing exclusion rules, module info, and source file filters.
- `symbol_list::Vector{Pair{Symbol,DocType}}`: List of symbol-type pairs to process.

# Returns

- `nothing`
"""
function _iterate_over_symbols(f, config, symbol_list)
    current_module = config.current_module
    
    # Determine source files for filtering:
    # Priority: module-specific files (from primary_modules => files) > global source_files
    module_specific_files = get(config.modules, current_module, String[])
    effective_source_files = if !isempty(module_specific_files)
        module_specific_files
    else
        config.source_files
    end
    
    for (key, type) in sort!(symbol_list; by=config.sort_by)
        if key isa Symbol
            if key in config.exclude
                continue
            end
            binding = Base.Docs.Binding(current_module, key)
            missing_doc = false
            if isdefined(Base.Docs, :hasdoc)
                missing_doc = !Base.Docs.hasdoc(binding)
            else
                doc = Base.Docs.doc(binding)
                missing_doc =
                    doc === nothing || occursin("No documentation found.", string(doc))
            end
            if missing_doc
                if type == DOCTYPE_MODULE
                    mod = getfield(current_module, key)
                    if mod == current_module || !haskey(config.modules, mod)
                        @warn "No documentation found for module $key in $(current_module). Skipping from API reference."
                        continue
                    end
                else
                    @warn "No documentation found for $key in $(current_module). Skipping from API reference."
                    continue
                end
            end
            if !isempty(effective_source_files)
                source_path = _get_source_file(current_module, key, type)
                if source_path === nothing
                    # If we can't determine source, include only if include_without_source is true
                    if !config.include_without_source
                        @debug "Cannot determine source file for $key ($(type)), skipping."
                        continue
                    end
                else
                    # Check if source_path matches any allowed file
                    keep = any(allowed -> source_path == allowed, effective_source_files)
                    if !keep
                        continue
                    end
                end
            end
        end
        f(key, type)
    end
    return nothing
end

"""
    _to_string(x::DocType)

Convert a DocType enumeration value to its string representation.

# Arguments
- `x::DocType`: Documentation type to convert

# Returns
- `String`: Human-readable name (e.g., "function", "struct", "macro")
"""
function _to_string(x::DocType)
    if x == DOCTYPE_ABSTRACT_TYPE
        return "abstract type"
    elseif x == DOCTYPE_CONSTANT
        return "constant"
    elseif x == DOCTYPE_FUNCTION
        return "function"
    elseif x == DOCTYPE_MACRO
        return "macro"
    elseif x == DOCTYPE_MODULE
        return "module"
    elseif x == DOCTYPE_STRUCT
        return "struct"
    end
end

"""
    _method_signature_string(m::Method, mod::Module, key::Symbol) -> String

Generate a Documenter-compatible signature string for a method.

Returns a string like `Module.func(::Type1, ::Type2)` that can be used in `@docs` blocks
to reference a specific method signature.

# Arguments
- `m::Method`: The method to generate a signature for.
- `mod::Module`: The module where the function is defined.
- `key::Symbol`: The function name.

# Returns
- `String`: A signature string suitable for Documenter's `@docs` block.
"""
function _method_signature_string(m::Method, mod::Module, key::Symbol)
    # m.sig is typically a UnionAll wrapping a Tuple type like
    #   Tuple{typeof(f), Arg1, Arg2, ...}
    # We unwrap all UnionAlls to get to the underlying Tuple, then format
    # the argument types. Type parameters are stripped by _format_type_for_docs
    # to avoid UndefVarError when Documenter evaluates the signature.

    sig = m.sig
    while sig isa UnionAll
        sig = sig.body
    end

    # Now sig should be the underlying Tuple type
    if !(sig <: Tuple)
        # Fallback: no clear Tuple structure; just return the bare function name
        return "$(mod).$(key)"
    end

    params = sig.parameters
    # Skip the first parameter (typeof(function)) if present
    arg_types = length(params) > 1 ? params[2:end] : Any[]

    if isempty(arg_types)
        return "$(mod).$(key)()"
    else
        # Format each argument type - ALWAYS fully qualify to avoid UndefVarError
        # Type parameters with TypeVars are automatically stripped by _format_type_for_docs
        type_strs = String[]
        for T in arg_types
            push!(type_strs, _format_type_for_docs(T))
        end
        return "$(mod).$(key)($(join(type_strs, ", ")))"
    end
end

"""
    _format_type_for_docs(T) -> String

Convert a type for use in Documenter's `@docs` block.
Format a type for use in Documenter's `@docs` block.
Always fully qualifies types to avoid UndefVarError when Documenter evaluates in Main.
"""
function _format_type_for_docs(T)
    # Vararg arguments appear as Core.TypeofVararg in method signatures
    if T isa Core.TypeofVararg
        # T.T is the inner type, T.N the length (often Core.Compiler.Const or Int)
        inner = _format_type_for_docs(T.T)
        inner_clean = startswith(inner, "::") ? inner[3:end] : inner
        # We ignore N for the purpose of the signature string; Documenter
        # accepts Vararg{T} just fine.
        return "::Vararg{$(inner_clean)}"
    elseif T isa TypeVar
        # Type variables like T in Vector{T} - just use the name
        return "::$(T.name)"
    elseif T isa UnionAll
        # Parametric type like Vector{T} - unwrap and format
        base = Base.unwrap_unionall(T)
        return _format_type_for_docs(base)
    elseif T isa DataType
        type_mod = parentmodule(T)
        type_name = T.name.name

        # SPECIAL CASE: Strip type parameters from certain types to avoid UndefVarError
        # when Documenter evaluates the signature in Main.
        # This is necessary for types with many type parameters that are not exported.
        if !isempty(T.parameters)
            # Check if any parameter is a TypeVar (not a concrete type)
            has_typevar_params = any(p -> p isa TypeVar, T.parameters)
            
            if has_typevar_params
                # Strip all type parameters for types with TypeVar parameters
                # e.g., Solution{TimeGridModelType, ...} -> Solution
                if type_mod === Core || type_mod === Base
                    return "::$(type_name)"
                else
                    return "::$(type_mod).$(type_name)"
                end
            else
                # Keep concrete type parameters
                params = [_format_type_param(p) for p in T.parameters]
                params_str = join(params, ", ")
                if type_mod === Core || type_mod === Base
                    return "::$(type_name){$(params_str)}"
                else
                    return "::$(type_mod).$(type_name){$(params_str)}"
                end
            end
        end

        # Simple type
        if type_mod === Core || type_mod === Base
            return "::$(type_name)"
        else
            return "::$(type_mod).$(type_name)"
        end
    elseif T isa Union
        # Format Union types
        union_types = Base.uniontypes(T)
        formatted = [_format_type_for_docs(ut) for ut in union_types]
        # Remove leading :: for union members
        cleaned = [startswith(s, "::") ? s[3:end] : s for s in formatted]
        return "::Union{$(join(cleaned, ", "))}"
    else
        return "::$(T)"
    end
end

"""
    _format_type_param(p) -> String

Format a type parameter (can be a type or a value like an integer).
"""
function _format_type_param(p)
    if p isa Type
        s = _format_type_for_docs(p)
        # Remove leading :: for type parameters
        return startswith(s, "::") ? s[3:end] : s
    elseif p isa TypeVar
        return string(p.name)
    else
        # Value parameter (e.g., N in NTuple{N, T})
        return string(p)
    end
end

"""
    _build_api_page(document::Documenter.Document, config::_Config)

Generate public and/or private API reference pages for a module.

Creates markdown pages listing symbols with their docstrings. When both
`config.public` and `config.private` are `true`, two separate pages are
generated (`public.md` and `private.md`). Otherwise, a single page is created
using `config.filename`.

# Arguments

- `document::Documenter.Document`: The Documenter document object to add pages to.
- `config::_Config`: Configuration specifying the module, output paths, and filtering options.

# Returns

- `nothing`
"""
# Global accumulator for multi-module combined pages
const PAGE_CONTENT_ACCUMULATOR = Dict{String, Vector{Tuple{Module, Vector{String}, Vector{String}}}}()

function _build_api_page(document::Documenter.Document, config::_Config)
    subdir = config.subdirectory
    current_module = config.current_module
    symbols = _exported_symbols(current_module)

    # Determine the page title: use config.title for single-page cases,
    # otherwise use default "Public API" / "Private API" for dual-page cases.
    page_title = config.title

    # Choose output filename
    public_basename = config.public && config.private ? "public" : config.filename
    private_basename = config.public && config.private ? "private" : config.filename
    public_filename = _build_page_path(subdir, "$public_basename.md")
    private_filename = _build_page_path(subdir, "$private_basename.md")

    # Collect public docstrings for this module
    public_docstrings = String[]
    if config.public
        _iterate_over_symbols(config, symbols.exported) do key, type
            if type == DOCTYPE_MODULE
                return nothing
            end
            push!(
                public_docstrings, "## `$key`\n\n```@docs\n$(current_module).$key\n```\n\n"
            )
            return nothing
        end
    end

    # Collect private docstrings for this module
    private_docstrings = String[]
    if config.private
        _iterate_over_symbols(config, symbols.private) do key, type
            if type == DOCTYPE_MODULE
                return nothing
            end
            push!(
                private_docstrings, "## `$key`\n\n```@docs\n$(current_module).$key\n```\n\n"
            )
            return nothing
        end
        # Add docstrings from additional modules (e.g., CTModels.export_ocp_solution)
        # For each doc_module, find functions that have methods defined in source_files
        # and generate @docs blocks with EXPLICIT SIGNATURES to avoid pulling all methods
        # Track signatures already added to avoid duplicates
        added_signatures = Set{String}()
        
        # Determine source files for the current module
        # Priority: module-specific files (from primary_modules => files) > global source_files > no filtering
        module_specific_files = get(config.modules, current_module, String[])
        
        if !isempty(module_specific_files)
            # Use module-specific source files (already normalized to absolute paths)
            filtered_source_files = module_specific_files
        elseif !isempty(config.source_files)
            # Fallback: use global source_files
            filtered_source_files = config.source_files
        else
            # No filtering: document all methods from external_modules_to_document
            filtered_source_files = String[]
        end
        
        for extra_mod in config.external_modules_to_document
            # Collect all methods from filtered_source_files, grouped by function name
            methods_by_func = Dict{Symbol, Vector{Method}}()
            for key in names(extra_mod; all=true)
                try
                    obj = getfield(extra_mod, key)
                    if obj isa Function
                        for m in methods(obj)
                            file = String(m.file)
                            if file != "<built-in>" && file != "none"
                                abs_file = abspath(file)
                                # Include method if:
                                # - filtered_source_files is empty (no filtering), OR
                                # - method is defined in one of the filtered_source_files
                                should_include = isempty(filtered_source_files) || (abs_file in filtered_source_files)
                                if should_include
                                    if !haskey(methods_by_func, key)
                                        methods_by_func[key] = Method[]
                                    end
                                    push!(methods_by_func[key], m)
                                end
                            end
                        end
                    end
                catch
                    continue
                end
            end
            
            # Generate @docs blocks with explicit signatures for each method
            for (key, method_list) in sort(collect(methods_by_func); by=first)
                for m in method_list
                    sig_str = _method_signature_string(m, extra_mod, key)
                    # Skip if we've already added this signature
                    if sig_str in added_signatures
                        continue
                    end
                    
                    push!(added_signatures, sig_str)
                    push!(
                        private_docstrings,
                        "## `$(extra_mod).$key`\n\n```@docs\n$(sig_str)\n```\n\n",
                    )
                end
            end
        end
    end

    # Accumulate content for combined pages
    key = private_filename  # Use private filename as key (same for public in single-page mode)
    if !haskey(PAGE_CONTENT_ACCUMULATOR, key)
        PAGE_CONTENT_ACCUMULATOR[key] = Tuple{Module, Vector{String}, Vector{String}}[]
    end
    push!(PAGE_CONTENT_ACCUMULATOR[key], (current_module, public_docstrings, private_docstrings))

    return nothing
end

"""
    _finalize_api_pages(document::Documenter.Document)

Finalize all accumulated API pages by combining content from multiple modules.
"""
function _finalize_api_pages(document::Documenter.Document)
    for (filename, module_contents) in PAGE_CONTENT_ACCUMULATOR
        # Determine if this is a public or private page based on filename
        is_private = occursin("private", filename) || !occursin("public", filename)
        
        # Build combined overview and docstrings
        all_modules = [mc[1] for mc in module_contents]
        modules_str = join([string(m) for m in all_modules], "`, `")
        
        if is_private
            overview = """
            ```@meta
            EditURL = nothing
            ```

            # Private API

            This page lists **non-exported** (internal) symbols of `$(modules_str)`.

            """
            all_docstrings = String[]
            for (mod, _, private_docs) in module_contents
                if !isempty(private_docs)
                    push!(all_docstrings, "\n---\n\n### From `$(mod)`\n\n")
                    append!(all_docstrings, private_docs)
                end
            end
        else
            overview = """
            # Public API

            This page lists **exported** symbols of `$(modules_str)`.

            """
            all_docstrings = String[]
            for (mod, public_docs, _) in module_contents
                if !isempty(public_docs)
                    push!(all_docstrings, "\n---\n\n### From `$(mod)`\n\n")
                    append!(all_docstrings, public_docs)
                end
            end
        end
        
        combined_md = Markdown.parse(overview * join(all_docstrings, "\n"))
        
        # Extract subdir from filename
        subdir = dirname(filename)
        if subdir == ""
            subdir = "."
        end
        
        document.blueprint.pages[filename] = Documenter.Page(
            joinpath(document.user.source, filename),
            joinpath(document.user.build, filename),
            document.user.build,
            combined_md.content,
            Documenter.Globals(),
            convert(MarkdownAST.Node, combined_md),
        )
    end
    
    # Clear accumulator for next build
    empty!(PAGE_CONTENT_ACCUMULATOR)
    
    return nothing
end

"""
    Documenter.Selectors.runner(::Type{APIBuilder}, document)

Documenter pipeline runner for API reference generation.

Processes all registered module configurations and generates their API reference pages.
This function is called automatically by Documenter during the documentation build.

# Arguments
- `document::Documenter.Document`: Documenter document object
"""
function Documenter.Selectors.runner(::Type{APIBuilder}, document::Documenter.Document)
    @info "APIBuilder: creating API reference"
    for config in CONFIG
        _build_api_page(document, config)
    end
    # Finalize all accumulated pages (combines multi-module content)
    _finalize_api_pages(document)
    return nothing
end

end  # module