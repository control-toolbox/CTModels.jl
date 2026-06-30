# ==============================================================================
# CTModels API Reference Manager
#
# One CTBase.automatic_reference_documentation call per documented page.
# Keep the file lists in sync with src/<Submodule>/ and ext/ when files
# are added, removed, or renamed.
# ==============================================================================

"""
    generate_api_reference(src_dir::String, ext_dir::String)

Generate the API reference documentation for CTModels.
Returns the list of pages.
"""
function generate_api_reference(src_dir::String, ext_dir::String)
    src(files...) = [abspath(joinpath(src_dir, f)) for f in files]
    ext(files...) = [abspath(joinpath(ext_dir, f)) for f in files]

    EXCLUDE_SYMBOLS = Symbol[
        :include,
        :eval,
        Symbol("@pack_PreModel"),
        Symbol("@pack_PreModel!"),
        Symbol("@unpack_PreModel"),
        :is_empty,
        :time_ns,
    ]
    EXCLUDE_INTERNALS = vcat(
        EXCLUDE_SYMBOLS,
        Symbol[:DOCTYPE_ABSTRACT_TYPE, :DOCTYPE_CONSTANT, :DOCTYPE_FUNCTION,
               :DOCTYPE_MACRO, :DOCTYPE_MODULE, :DOCTYPE_STRUCT],
    )

    # ── Shared config: one entry per submodule ────────────────────────────────
    modules_config = [
        (
            mod=CTModels.Components,
            title="Components",
            filename="components",
            files=src(
                joinpath("Components", "Components.jl"),
                joinpath("Components", "functors.jl"),
                joinpath("Components", "types.jl"),
                joinpath("Components", "aliases.jl"),
                joinpath("Components", "accessors_api.jl"),
                joinpath("Components", "accessors.jl"),
                joinpath("Components", "times_accessors.jl"),
                joinpath("Components", "objective_accessors.jl"),
                joinpath("Components", "constraints_accessors.jl"),
            ),
        ),
        (
            mod=CTModels.Models,
            title="Models",
            filename="models",
            files=src(
                joinpath("Models", "Models.jl"),
                joinpath("Models", "constraint_functors.jl"),
                joinpath("Models", "model.jl"),
            ),
        ),
        (
            mod=CTModels.Building,
            title="Building",
            filename="building",
            files=src(
                joinpath("Building", "Building.jl"),
                joinpath("Building", "constraint_composers.jl"),
                joinpath("Building", "pre_model.jl"),
                joinpath("Building", "state.jl"),
                joinpath("Building", "control.jl"),
                joinpath("Building", "variable.jl"),
                joinpath("Building", "times.jl"),
                joinpath("Building", "dynamics.jl"),
                joinpath("Building", "objective.jl"),
                joinpath("Building", "constraints.jl"),
                joinpath("Building", "definition.jl"),
                joinpath("Building", "time_dependence.jl"),
                joinpath("Building", "build.jl"),
                joinpath("Building", "defaults.jl"),
                joinpath("Building", "name_validation.jl"),
            ),
        ),
        (
            mod=CTModels.Solutions,
            title="Solutions",
            filename="solutions",
            files=src(
                joinpath("Solutions", "Solutions.jl"),
                joinpath("Solutions", "solution_types.jl"),
                joinpath("Solutions", "dual_functors.jl"),
                joinpath("Solutions", "build_solution.jl"),
                joinpath("Solutions", "dual_model.jl"),
                joinpath("Solutions", "interpolation_helpers.jl"),
                joinpath("Solutions", "discretization_utils.jl"),
            ),
        ),
        (
            mod=CTModels.Display,
            title="Display",
            filename="display",
            files=src(
                joinpath("Display", "Display.jl"),
                joinpath("Display", "ansi.jl"),
                joinpath("Display", "definition.jl"),
                joinpath("Display", "mathematical.jl"),
                joinpath("Display", "model.jl"),
                joinpath("Display", "pre_model.jl"),
                joinpath("Display", "solution.jl"),
            ),
        ),
        (
            mod=CTModels.Serialization,
            title="Serialization",
            filename="serialization",
            files=src(
                joinpath("Serialization", "Serialization.jl"),
                joinpath("Serialization", "export_import.jl"),
                joinpath("Serialization", "types.jl"),
                joinpath("Serialization", "reconstruction_helpers.jl"),
            ),
        ),
        (
            mod=CTModels.Init,
            title="Init",
            filename="init",
            files=src(
                joinpath("Init", "Init.jl"),
                joinpath("Init", "types.jl"),
                joinpath("Init", "api.jl"),
                joinpath("Init", "init_functors.jl"),
                joinpath("Init", "builders.jl"),
                joinpath("Init", "state.jl"),
                joinpath("Init", "control.jl"),
                joinpath("Init", "variable.jl"),
                joinpath("Init", "validation.jl"),
                joinpath("Init", "utils.jl"),
            ),
        ),
    ]

    # ── Public pages: one flat page per submodule ─────────────────────────────
    pages = [
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[cfg.mod => cfg.files],
            external_modules_to_document=[CTModels],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=false,
            title=cfg.title,
            title_in_menu=cfg.title,
            filename=cfg.filename,
        ) for cfg in modules_config
    ]

    # ── Internals: all private symbols in one page, sections by module ────────
    internals_modules = Any[cfg.mod => cfg.files for cfg in modules_config]

    # Conditional extensions
    for (sym, files) in [
        (:CTModelsPlots, ext("CTModelsPlots.jl", "plot.jl", "plot_utils.jl", "plot_default.jl")),
        (:CTModelsJSON, ext("CTModelsJSON.jl")),
        (:CTModelsJLD, ext("CTModelsJLD.jl")),
    ]
        extmod = Base.get_extension(CTModels, sym)
        isnothing(extmod) || push!(internals_modules, extmod => files)
    end

    push!(
        pages,
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=internals_modules,
            external_modules_to_document=[CTModels],
            exclude=EXCLUDE_INTERNALS,
            public=false,
            private=true,
            title="Internals",
            title_in_menu="Internals",
            filename="internals",
        ),
    )

    return pages
end

"""
    with_api_reference(f::Function, src_dir::String, ext_dir::String)

Generates the API reference, executes `f(pages)`, and cleans up generated files.
"""
function with_api_reference(f::Function, src_dir::String, ext_dir::String)
    pages = generate_api_reference(src_dir, ext_dir)
    try
        f(pages)
    finally
        docs_src = abspath(joinpath(@__DIR__, "src"))
        function cleanup(pages)
            for p in pages
                content = last(p)
                if content isa AbstractString
                    fname = endswith(content, ".md") ? content : content * ".md"
                    full_path = joinpath(docs_src, fname)
                    isfile(full_path) && rm(full_path)
                elseif content isa Vector
                    cleanup(content)
                end
            end
        end
        cleanup(pages)
    end
end
