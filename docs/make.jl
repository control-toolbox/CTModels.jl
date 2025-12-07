using Documenter
using CTModels
using CTBase  # For automatic_reference_documentation
using Plots
using JSON3
using JLD2
using Markdown
using MarkdownAST: MarkdownAST

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════
draft = false  # Draft mode: if true, @example blocks in markdown are not executed

# ═══════════════════════════════════════════════════════════════════════════════
# Load extensions
# ═══════════════════════════════════════════════════════════════════════════════
const CTModelsPlots = Base.get_extension(CTModels, :CTModelsPlots)
const CTModelsJSON = Base.get_extension(CTModels, :CTModelsJSON)
const CTModelsJLD = Base.get_extension(CTModels, :CTModelsJLD)
const DocumenterReference = Base.get_extension(CTBase, :DocumenterReference)

# to add docstrings from external packages
Modules = [Plots, CTModelsPlots, CTModelsJSON, CTModelsJLD]
for Module in Modules
    isnothing(DocMeta.getdocmeta(Module, :DocTestSetup)) &&
        DocMeta.setdocmeta!(Module, :DocTestSetup, :(using $Module); recursive=true)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Paths
# ═══════════════════════════════════════════════════════════════════════════════
repo_url = "github.com/control-toolbox/CTModels.jl"
src_dir = abspath(joinpath(@__DIR__, "..", "src"))
ext_dir = abspath(joinpath(@__DIR__, "..", "ext"))

# Helper to build absolute paths
src(files...) = [abspath(joinpath(src_dir, f)) for f in files]
ext(files...) = [abspath(joinpath(ext_dir, f)) for f in files]

# ═══════════════════════════════════════════════════════════════════════════════
# API_PAGES for index.md @contents block
# ═══════════════════════════════════════════════════════════════════════════════
const API_PAGES = [
    "ctmodels.md",
    "types.md",
    "default_utils.md",
    "model.md",
    "times.md",
    "state_control_variable.md",
    "dynamics_objective.md",
    "constraints.md",
    "solution_dual.md",
    "print.md",
    "initial_guess.md",
    "nlp.md",
    "plot.md",
    "json.md",
    "jld.md",
]

# ═══════════════════════════════════════════════════════════════════════════════
# Build documentation
# ═══════════════════════════════════════════════════════════════════════════════
makedocs(;
    draft=draft,
    remotes=nothing,  # Disable remote links. Needed for DocumenterReference
    warnonly=true,
    sitename="CTModels.jl",
    format=Documenter.HTML(;
        repolink="https://" * repo_url,
        prettyurls=false,
        size_threshold_ignore=["api.md", "dev.md"],
        assets=[
            asset("https://control-toolbox.org/assets/css/documentation.css"),
            asset("https://control-toolbox.org/assets/js/documentation.js"),
        ],
    ),
    pages=[
        "Introduction" => "index.md",
        "API Reference" => [
            # ───────────────────────────────────────────────────────────────────
            # Main module
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="CTModels",
                title_in_menu="CTModels",
                filename="ctmodels",
                source_files=src("CTModels.jl"),
            ),
            # ───────────────────────────────────────────────────────────────────
            # Core: Types
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="Types",
                title_in_menu="Types",
                filename="types",
                source_files=src(
                    "core/types.jl",
                    "core/types/ocp_model.jl",
                    "core/types/ocp_components.jl",
                    "core/types/ocp_solution.jl",
                    "core/types/initial_guess.jl",
                    "core/types/nlp.jl",
                ),
            ),
            # ───────────────────────────────────────────────────────────────────
            # Core: Default & Utils
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="Default & Utils",
                title_in_menu="Default & Utils",
                filename="default_utils",
                source_files=src("core/default.jl", "core/utils.jl"),
            ),
            # ───────────────────────────────────────────────────────────────────
            # OCP: Model (model, definition, time_dependence)
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="Model",
                title_in_menu="Model",
                filename="model",
                source_files=src(
                    "ocp/model.jl",
                    "ocp/definition.jl",
                    "ocp/time_dependence.jl",
                ),
            ),
            # ───────────────────────────────────────────────────────────────────
            # OCP: Times
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="Times",
                title_in_menu="Times",
                filename="times",
                source_files=src("ocp/times.jl"),
            ),
            # ───────────────────────────────────────────────────────────────────
            # OCP: State, Control, Variable
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="State, Control & Variable",
                title_in_menu="State, Control & Variable",
                filename="state_control_variable",
                source_files=src("ocp/state.jl", "ocp/control.jl", "ocp/variable.jl"),
            ),
            # ───────────────────────────────────────────────────────────────────
            # OCP: Dynamics & Objective
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="Dynamics & Objective",
                title_in_menu="Dynamics & Objective",
                filename="dynamics_objective",
                source_files=src("ocp/dynamics.jl", "ocp/objective.jl"),
            ),
            # ───────────────────────────────────────────────────────────────────
            # OCP: Constraints
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="Constraints",
                title_in_menu="Constraints",
                filename="constraints",
                source_files=src("ocp/constraints.jl"),
            ),
            # ───────────────────────────────────────────────────────────────────
            # OCP: Solution & Dual
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="Solution & Dual",
                title_in_menu="Solution & Dual",
                filename="solution_dual",
                source_files=src("ocp/solution.jl", "ocp/dual_model.jl"),
            ),
            # ───────────────────────────────────────────────────────────────────
            # OCP: Print
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="Print",
                title_in_menu="Print",
                filename="print",
                source_files=src("ocp/print.jl"),
            ),
            # ───────────────────────────────────────────────────────────────────
            # Initial Guess
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="Initial Guess",
                title_in_menu="Initial Guess",
                filename="initial_guess",
                source_files=src("init/initial_guess.jl"),
            ),
            # ───────────────────────────────────────────────────────────────────
            # NLP Backends
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="NLP Backends",
                title_in_menu="NLP Backends",
                filename="nlp",
                source_files=src(
                    "nlp/nlp_backends.jl",
                    "nlp/options_schema.jl",
                    "nlp/problem_core.jl",
                    "nlp/discretized_ocp.jl",
                    "nlp/model_api.jl",
                ),
            ),
            # ───────────────────────────────────────────────────────────────────
            # Extension: Plot
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModelsPlots],
                doc_modules=[Plots, CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="Plot Extension",
                title_in_menu="Plot",
                filename="plot",
                source_files=ext(
                    "CTModelsPlots.jl",
                    "plot.jl",
                    "plot_default.jl",
                    "plot_utils.jl",
                ),
            ),
            # ───────────────────────────────────────────────────────────────────
            # Extension: JSON
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModelsJSON],
                doc_modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="JSON Extension",
                title_in_menu="JSON",
                filename="json",
                source_files=ext("CTModelsJSON.jl"),
            ),
            # ───────────────────────────────────────────────────────────────────
            # Extension: JLD
            # ───────────────────────────────────────────────────────────────────
            CTBase.automatic_reference_documentation(;
                subdirectory=".",
                modules=[CTModelsJLD],
                doc_modules=[CTModels],
                exclude=Symbol[:include, :eval],
                public=false,
                private=true,
                title="JLD Extension",
                title_in_menu="JLD",
                filename="jld",
                source_files=ext("CTModelsJLD.jl"),
            ),
        ],
    ],
    checkdocs=:none,
)

# ═══════════════════════════════════════════════════════════════════════════════
deploydocs(; repo=repo_url * ".git", devbranch="main")
