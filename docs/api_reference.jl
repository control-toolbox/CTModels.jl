# ==============================================================================
# CTModels API Reference Generator
# ==============================================================================
#
# This module provides functions to generate API reference documentation
# for CTModels.jl, following the pattern established in CTBase.jl.
#
# ==============================================================================

"""
    generate_api_reference(src_dir::String, ext_dir::String)

Generate the API reference documentation for CTModels.
Returns the list of pages.
"""
function generate_api_reference(src_dir::String, ext_dir::String)
    # Helper to build absolute paths
    src(files...) = [abspath(joinpath(src_dir, f)) for f in files]
    ext(files...) = [abspath(joinpath(ext_dir, f)) for f in files]

    # Symbols to exclude from documentation
    EXCLUDE_SYMBOLS = Symbol[
        :include,
        :eval,
        Symbol("@pack_PreModel"),
        Symbol("@pack_PreModel!"),
        Symbol("@unpack_PreModel"),
        :is_empty,
        :time_ns,
    ]

    CTModelsPlots = Base.get_extension(CTModels, :CTModelsPlots)
    CTModelsJSON = Base.get_extension(CTModels, :CTModelsJSON)
    CTModelsJLD = Base.get_extension(CTModels, :CTModelsJLD)

    pages = [
        # ───────────────────────────────────────────────────────────────────
        # Components — foundational types and basic accessors
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTModels.Components => src(
                    joinpath("Components", "types.jl"),
                    joinpath("Components", "aliases.jl"),
                    joinpath("Components", "accessors.jl"),
                    joinpath("Components", "times_accessors.jl"),
                    joinpath("Components", "objective_accessors.jl"),
                    joinpath("Components", "constraints_accessors.jl"),
                ),
            ],
            external_modules_to_document=[CTModels],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="Components",
            title_in_menu="Components",
            filename="api_ocp_types",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Models — AbstractModel, Model and its accessors
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTModels.Models => src(
                    joinpath("Models", "constraint_functors.jl"),
                    joinpath("Models", "model.jl"),
                ),
            ],
            external_modules_to_document=[CTModels],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="Models",
            title_in_menu="Models",
            filename="api_ocp_components",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Building — PreModel, mutators, build
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTModels.Building => src(
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
            ],
            external_modules_to_document=[CTModels],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="Building",
            title_in_menu="Building",
            filename="api_ocp_building",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Solutions — Solution types, build_solution, duals
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTModels.Solutions => src(
                    joinpath("Solutions", "solution_types.jl"),
                    joinpath("Solutions", "dual_functors.jl"),
                    joinpath("Solutions", "build_solution.jl"),
                    joinpath("Solutions", "dual_model.jl"),
                    joinpath("Solutions", "interpolation_helpers.jl"),
                    joinpath("Solutions", "discretization_utils.jl"),
                ),
            ],
            external_modules_to_document=[CTModels],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="Solutions",
            title_in_menu="Solutions",
            filename="api_ocp_core",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Display
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTModels.Display => src(
                    joinpath("Display", "Display.jl"),
                    joinpath("Display", "ansi.jl"),
                    joinpath("Display", "definition.jl"),
                    joinpath("Display", "mathematical.jl"),
                    joinpath("Display", "model.jl"),
                    joinpath("Display", "pre_model.jl"),
                    joinpath("Display", "solution.jl"),
                ),
                CTModelsPlots =>
                    ext("CTModelsPlots.jl", "plot.jl", "plot_utils.jl", "plot_default.jl"),
            ],
            external_modules_to_document=[Plots],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="Display, Plots",
            title_in_menu="Display, Plots",
            filename="api_display",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Serialization
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTModels.Serialization => src(
                    joinpath("Serialization", "Serialization.jl"),
                    joinpath("Serialization", "export_import.jl"),
                    joinpath("Serialization", "types.jl"),
                    joinpath("Serialization", "reconstruction_helpers.jl"),
                ),
                CTModelsJSON => ext("CTModelsJSON.jl"),
                CTModelsJLD => ext("CTModelsJLD.jl"),
            ],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="Serialization, JSON & JLD2",
            title_in_menu="Serialization, JSON & JLD2",
            filename="api_serialization",
        ),
        # ───────────────────────────────────────────────────────────────────
        # InitialGuess
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTModels.Init => src(
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
            ],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="InitialGuess",
            title_in_menu="InitialGuess",
            filename="api_initial_guess",
        ),
    ]

    # ───────────────────────────────────────────────────────────────────
    # Extensions (conditional)
    # ───────────────────────────────────────────────────────────────────

    # # CTModelsPlots extension
    # CTModelsPlots = Base.get_extension(CTModels, :CTModelsPlots)
    # if !isnothing(CTModelsPlots)
    #     push!(
    #         pages,
    #         CTBase.automatic_reference_documentation(;
    #             subdirectory=".",
    #             primary_modules=[
    #                 CTModelsPlots => ext("plot.jl", "plot_utils.jl", "plot_default.jl")
    #             ],
    #             external_modules_to_document=[CTModels],
    #             exclude=EXCLUDE_SYMBOLS,
    #             public=true,
    #             private=true,
    #             title="CTModelsPlots",
    #             title_in_menu="Plots Extension",
    #             filename="api_plots_extension",
    #         ),
    #     )
    # end

    # # CTModelsJSON extension
    # CTModelsJSON = Base.get_extension(CTModels, :CTModelsJSON)
    # if !isnothing(CTModelsJSON)
    #     push!(
    #         pages,
    #         CTBase.automatic_reference_documentation(;
    #             subdirectory=".",
    #             primary_modules=[CTModelsJSON => ext("CTModelsJSON.jl")],
    #             external_modules_to_document=[CTModels],
    #             exclude=EXCLUDE_SYMBOLS,
    #             public=true,
    #             private=true,
    #             title="CTModelsJSON",
    #             title_in_menu="JSON Extension",
    #             filename="api_json_extension",
    #         ),
    #     )
    # end

    # # CTModelsJLD extension
    # CTModelsJLD = Base.get_extension(CTModels, :CTModelsJLD)
    # if !isnothing(CTModelsJLD)
    #     push!(
    #         pages,
    #         CTBase.automatic_reference_documentation(;
    #             subdirectory=".",
    #             primary_modules=[CTModelsJLD => ext("CTModelsJLD.jl")],
    #             external_modules_to_document=[CTModels],
    #             exclude=EXCLUDE_SYMBOLS,
    #             public=true,
    #             private=true,
    #             title="CTModelsJLD",
    #             title_in_menu="JLD2 Extension",
    #             filename="api_jld_extension",
    #         ),
    #     )
    # end

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
        # Clean up generated files
        # The pages are Pairs: "Title" => "filename.md" (relative to build? no, relative to src)
        # automatic_reference_documentation returns "filename" which is relative to docs/src if subdirectory="."

        # We need to reconstruct the full path to delete them.
        # Assuming they are in docs/src (which is where makedocs runs from?)
        # Wait, makedocs options say subdirectory=".". 
        # Typically automatic_reference_documentation writes to joinpath(@__DIR__, "src", subdirectory, filename.md) ??
        # I need to check where automatic_reference_documentation writes.
        # Assuming we are running from docs/ (where make.jl is).

        # Let's assume the files are in `docs/src`.
        docs_src = abspath(joinpath(@__DIR__, "src"))

        function cleanup_pages(pages)
            for p in pages
                content = last(p)
                if content isa AbstractString
                    # file path
                    filename = content
                    fname = endswith(filename, ".md") ? filename : filename * ".md"
                    full_path = joinpath(docs_src, fname)
                    if isfile(full_path)
                        rm(full_path)
                        println("Removed temporary API doc: $full_path")
                    end
                elseif content isa Vector
                    # nested pages
                    cleanup_pages(content)
                end
            end
        end

        cleanup_pages(pages)
    end
end
