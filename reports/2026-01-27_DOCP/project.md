L'idée c'est de revoir la partie Optimization et DOCP.

Optimization fournit un cadre pour les modeleurs (cf. module Modelers) et [solveurs](https://github.com/control-toolbox/CTSolvers.jl/blob/release/v0.2.0-beta/src/ctsolvers/common_solve_api.jl)

DOCP est une implémentation et on peut voir un exemple à l'adresse : 

https://github.com/control-toolbox/CTDirect.jl/blob/breaking/ctmodels-0.7/src/collocation.jl

Il y a eu des choix fait. Comme par exemple passer par des builders

```julia
    return CTModels.DiscretizedOptimalControlProblem(
        ocp,
        CTModels.ADNLPModelBuilder(build_adnlp_model),
        CTModels.ExaModelBuilder(build_exa_model),
        CTModels.ADNLPSolutionBuilder(build_adnlp_solution),
        CTModels.ExaSolutionBuilder(build_exa_solution),
    )
```

pour pouvoir figer la signature (en encapsulant) des fonctions. Par exemple, on a :

```julia
function (builder::ADNLPModelBuilder)(initial_guess; kwargs...)
    return builder.f(initial_guess; kwargs...)
end
function (builder::ExaModelBuilder)(
    ::Type{BaseType}, initial_guess; kwargs...
) where {BaseType<:AbstractFloat}
    return builder.f(BaseType, initial_guess; kwargs...)
end
function (builder::ADNLPSolutionBuilder)(nlp_solution)
    return builder.f(nlp_solution)
end
function (builder::ExaSolutionBuilder)(nlp_solution)
    return builder.f(nlp_solution)
end
```

On a aussi fait le choix du coup de fixer le fait de fournir des builders pour ExaModels et ADNLPModels, et il est difficile de généraliser.

Dans https://github.com/control-toolbox/CTDirect.jl/blob/breaking/ctmodels-0.7/src/collocation.jl, le discrétiseur construir le DOCP. Le fait de faire le choix que le DOCP contienne toutes les fonctions utiles rend ce discrétiseur complexe à l'appel sur un ocp.

Pour le DOCP, on a ces fonctions 

```julia
get_adnlp_model_builder, get_exa_model_builder
get_adnlp_solution_builder, get_exa_solution_builder
```

ce qui permet au modeleur quand il est appelé pour récupérer le problème sous la forme d'un modèle spécifique de faire les bons choix : 

```julia
function (modeler::ADNLPModeler)(
    prob::AbstractOptimizationProblem,
    initial_guess
)::ADNLPModels.ADNLPModel
    opts = Strategies.options(modeler)
    
    # Get the appropriate builder for this problem type
    builder = get_adnlp_model_builder(prob)
    
    # Extract raw values from OptionValue wrappers and filter out nothing values
    raw_opts = Options.extract_raw_options(opts.options)
    
    # Build the ADNLP model passing all options generically
    return builder(initial_guess; raw_opts...)
end
```

Il est à noter que l'on utilise le pattern "action sur objet via une liste de stratégies" comme par exemple :

```julia
function build_model(prob, initial_guess, modeler)
    return modeler(prob, initial_guess)
end
```

où l'action est `build_model`, l'objet est le `prob x initial_guess` et la stratégie est le `modeler`.  Quand une stratégie est "atomique" cela revient à appeler la stratégie sur l'objet. Parfois, c'est plus complexe :

```julia
# complexe
function CommonSolve.solve(
    problem::AbstractOptimizationProblem,
    initial_guess,
    modeler::AbstractOptimizationModeler,
    solver::AbstractOptimizationSolver;
    display::Bool=__display(),
)
    nlp = build_model(problem, initial_guess, modeler)
    nlp_solution = CommonSolve.solve(nlp, solver; display=display)
    solution = build_solution(problem, nlp_solution, modeler)
    return solution
end

# atomique
function CommonSolve.solve(
    nlp::NLPModels.AbstractNLPModel,
    solver::AbstractOptimizationSolver;
    display::Bool=__display(),
)::SolverCore.AbstractExecutionStats
    return solver(nlp; display=display)
end
```

Je pense que conceptuellement on a bien la flèche OCP -> DOCP par une discrétisation :

```julia
function discretize(
    ocp::AbstractOptimalControlProblem, discretizer::AbstractOptimalControlDiscretizer
)
    return discretizer(ocp)
end
```

qui renvoie un DOCP.

Puis sur un DOCP, on peut récupérer un modèle NLP à résoudre en divers format : exa, adnlp, etc. C'est le rôle des modeleurs.

On pourrait imaginer ne pas avoir de phase de discrétisation au sens stricte et donc avoir :

```julia
function build_model(prob, initial_guess, modeler, discretize)
    ...
end
```

mais on perd la notion d'action atomique.

On pourrait imaginer que dans le DOCP, on ait pas construit des choses qui dépendent du modèle mais que des choses indépendants. Le choix le plus simple serait d'avoir (je ne fais un type paramétrique pour insister sur ce qui est important) :

```julia
struct DiscretizedOptimalControlProblem<: AbstractOptimizationProblem
    optimal_control_problem::AbstractOptimalControlProblem
    discretize::AbstractOptimalControlDiscretizer
end
```

qui du coup ne fait presque rien à la construction du DOCP. Puis à l'appel du modeleur :

```julia
function (modeler::ADNLPModeler)(
    prob::AbstractOptimizationProblem,
    initial_guess
)::ADNLPModels.ADNLPModel
    opts = Strategies.options(modeler)
    
    # Extract raw values from OptionValue wrappers and filter out nothing values
    raw_opts = Options.extract_raw_options(opts.options)
    
    # Build the ADNLP model passing all options generically
    return build_adnlp_model(prob, initial_guess; raw_opts...)
end
```

et dans le prob, vu que l'on a l'ocp et le discrétiseur, on peut tout faire.

Remarque : on doit pouvoir rendre `build_adnlp_model` ici type stable plus facilement qu'avant.

L'avantage dans le premier cas où l'on construit les builders quand on discrétise, c'est que l'on peut pré-calculer des choses et faire des fermetures, ici, on doit tout recalculer si on appel 2 fois le modeler, pour deux conditions initiales par exemple. 

L'avantage dans le second cas est que c'est plus clair pour CTDirect, d'implémenter ces fonctions que d'en créer pour ensuite utiliser des getters.

On pourrait imaginer une approche hybride où le DOCP aurait des champs supplémentaires pour stocker soit des calculs durant la phase de création du DOCP pour ne pas tout refaire à chaque fois, soit quand on appelle `build_adnlp_model(prob, initial_guess; raw_opts...)` alors on stocke des choses spécifiques que l'on utilisera à nouveau.

Dans ce projet, j'aimerais que l'on fasse un véritable point sur le flux actuel (le pipeline de bout en bout), j'aimerais que l'on évalue cette architecture selon des règles, voir le fichier [text](reference/00_development_standards_reference.md) par exemple. J'aimerais que l'on trouve des variantes, des propositions alternatives et qu'on les évalue elles aussi.
