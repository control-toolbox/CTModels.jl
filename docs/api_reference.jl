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
    ]

    pages = [
        # ───────────────────────────────────────────────────────────────────
        # CTModels (main module)
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[CTModels => src("CTModels.jl")],
            exclude=EXCLUDE_SYMBOLS,
            public=false,
            private=true,
            title="CTModels",
            title_in_menu="CTModels",
            filename="api_ctmodels",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Utils
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTModels.Utils => src(
                    joinpath("Utils", "Utils.jl"),
                    joinpath("Utils", "macros.jl"),
                    joinpath("Utils", "interpolation.jl"),
                    joinpath("Utils", "matrix_utils.jl"),
                    joinpath("Utils", "function_utils.jl"),
                ),
            ],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="Utils",
            title_in_menu="Utils",
            filename="api_utils",
        ),
        # ───────────────────────────────────────────────────────────────────
        # OCP - Types
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTModels.OCP => src(
                    joinpath("OCP", "aliases.jl"),
                    joinpath("OCP", "Types", "components.jl"),
                    joinpath("OCP", "Types", "model.jl"),
                    joinpath("OCP", "Types", "solution.jl"),
                ),
            ],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="OCP - Types",
            title_in_menu="OCP Types",
            filename="api_ocp_types",
        ),
        # ───────────────────────────────────────────────────────────────────
        # OCP - Components
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTModels.OCP => src(
                    joinpath("OCP", "Components", "state.jl"),
                    joinpath("OCP", "Components", "control.jl"),
                    joinpath("OCP", "Components", "variable.jl"),
                    joinpath("OCP", "Components", "times.jl"),
                    joinpath("OCP", "Components", "dynamics.jl"),
                    joinpath("OCP", "Components", "objective.jl"),
                    joinpath("OCP", "Components", "constraints.jl"),
                ),
            ],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="OCP - Components",
            title_in_menu="OCP Components",
            filename="api_ocp_components",
        ),
        # ───────────────────────────────────────────────────────────────────
        # OCP - Building
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTModels.OCP => src(
                    joinpath("OCP", "Building", "model.jl"),
                    joinpath("OCP", "Building", "solution.jl"),
                    joinpath("OCP", "Building", "interpolation_helpers.jl"),
                    joinpath("OCP", "Building", "discretization_utils.jl"),
                    joinpath("OCP", "Building", "dual_model.jl"),
                    joinpath("OCP", "Building", "definition.jl"),
                ),
            ],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="OCP - Building",
            title_in_menu="OCP Building",
            filename="api_ocp_building",
        ),
        # ───────────────────────────────────────────────────────────────────
        # OCP - Core & Validation
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTModels.OCP => src(
                    joinpath("OCP", "Core", "defaults.jl"),
                    joinpath("OCP", "Core", "time_dependence.jl"),
                    joinpath("OCP", "Validation", "name_validation.jl"),
                ),
            ],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="OCP - Core & Validation",
            title_in_menu="OCP Core",
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
                    joinpath("Display", "print.jl"),
                ),
            ],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="Display",
            title_in_menu="Display",
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
                ),
            ],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="Serialization",
            title_in_menu="Serialization",
            filename="api_serialization",
        ),
        # ───────────────────────────────────────────────────────────────────
        # InitialGuess
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTModels.InitialGuess => src(
                    joinpath("InitialGuess", "InitialGuess.jl"),
                    joinpath("InitialGuess", "types.jl"),
                    joinpath("InitialGuess", "api.jl"),
                    joinpath("InitialGuess", "builders.jl"),
                    joinpath("InitialGuess", "state.jl"),
                    joinpath("InitialGuess", "control.jl"),
                    joinpath("InitialGuess", "variable.jl"),
                    joinpath("InitialGuess", "validation.jl"),
                    joinpath("InitialGuess", "utils.jl"),
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
    
    # CTModelsPlots extension
    CTModelsPlots = Base.get_extension(CTModels, :CTModelsPlots)
    if !isnothing(CTModelsPlots)
        push!(
            pages,
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                primary_modules=[
                    CTModelsPlots => ext("plot.jl", "plot_utils.jl", "plot_default.jl")
                ],
                external_modules_to_document=[CTModels],
                exclude=EXCLUDE_SYMBOLS,
                public=true,
                private=true,
                title="CTModelsPlots",
                title_in_menu="Plots Extension",
                filename="api_plots_extension",
            ),
        )
    end

    # CTModelsJSON extension
    CTModelsJSON = Base.get_extension(CTModels, :CTModelsJSON)
    if !isnothing(CTModelsJSON)
        push!(
            pages,
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                primary_modules=[CTModelsJSON => ext("CTModelsJSON.jl")],
                external_modules_to_document=[CTModels],
                exclude=EXCLUDE_SYMBOLS,
                public=true,
                private=true,
                title="CTModelsJSON",
                title_in_menu="JSON Extension",
                filename="api_json_extension",
            ),
        )
    end

    # CTModelsJLD extension
    CTModelsJLD = Base.get_extension(CTModels, :CTModelsJLD)
    if !isnothing(CTModelsJLD)
        push!(
            pages,
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                primary_modules=[CTModelsJLD => ext("CTModelsJLD.jl")],
                external_modules_to_document=[CTModels],
                exclude=EXCLUDE_SYMBOLS,
                public=true,
                private=true,
                title="CTModelsJLD",
                title_in_menu="JLD2 Extension",
                filename="api_jld_extension",
            ),
        )
    end

    return pages
end

"""
    with_api_reference(f, src_dir::String, ext_dir::String)

Execute function `f` with the generated API reference pages.
This is a helper function to be used in make.jl.
"""
function with_api_reference(f, src_dir::String, ext_dir::String)
    api_pages = generate_api_reference(src_dir, ext_dir)
    return f(api_pages)
end
