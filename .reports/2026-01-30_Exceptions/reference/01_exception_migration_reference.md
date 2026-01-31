# Guide de Référence pour la Migration des Exceptions CTModels

**Version**: 1.0  
**Date**: 2026-01-31  
**Statut**: 📘 Document de Référence Actif  
**Auteur**: Équipe de Développement CTModels

---

## Table des Matières

1. [Vue d'ensemble du Projet](#vue-densemble-du-projet)
2. [État Actuel des Exceptions](#état-actuel-des-exceptions)
3. [Architecture du Système d'Exceptions](#architecture-du-système-dexceptions)
4. [Types d'Exceptions Enrichies](#types-dexceptions-enrichies)
5. [Standards de Migration](#standards-de-migration)
6. [Templates par Type d'Exception](#templates-par-type-dexception)
7. [Processus de Migration](#processus-de-migration)
8. [Validation et Tests](#validation-et-tests)
9. [Bonnes Pratiques](#bonnes-pratiques)
10. [Références et Outils](#références-et-outils)

---

## Vue d'ensemble du Projet

### Objectif Principal

Migrer 100% des exceptions `CTBase.*` vers le système enrichi `Exceptions.*` de CTModels pour améliorer l'expérience utilisateur avec des messages d'erreur plus clairs, des suggestions explicites et un contexte pertinent.

### Chiffres Clés

- **Total d'exceptions à migrer**: 140
- **IncorrectArgument**: 45 occurrences
- **UnauthorizedCall**: 64 occurrences  
- **NotImplemented**: 25 occurrences
- **error() génériques**: 6 occurrences

### Impact Attendu

1. **Expérience Utilisateur**: Messages d'erreur plus clairs et actionnables
2. **Débogage**: Contexte enrichi et suggestions de résolution
3. **Maintenance**: Codebase uniforme et extensible
4. **Documentation**: Messages auto-documentants

---

## État Actuel des Exceptions

### Système Legacy (CTBase)

```julia
# Anciens messages peu informatifs
throw(CTBase.IncorrectArgument("Invalid source: $source"))
throw(CTBase.UnauthorizedCall("the state must be set."))
throw(CTBase.NotImplemented("Method not implemented"))
```

**Limites**:
- Messages cryptiques
- Pas de suggestions
- Pas de contexte structuré
- Difficile à déboguer

### Système Enrichi (CTModels.Exceptions)

```julia
# Nouveaux messages riches et informatifs
throw(Exceptions.IncorrectArgument(
    "Invalid option source",
    got="$source",
    expected=":default, :user, or :computed",
    suggestion="Use one of the valid source types",
    context="option validation"
))
```

**Avantages**:
- Messages structurés
- Suggestions explicites
- Contexte précis
- Affichage utilisateur-friendly

---

## Architecture du Système d'Exceptions

### Structure des Modules

```
src/Exceptions/
├── Exceptions.jl      # Module principal et exports
├── config.jl          # Configuration (SHOW_FULL_STACKTRACE)
├── types.jl           # Définitions des types d'exceptions
├── display.jl         # Fonctions d'affichage utilisateur-friendly
└── conversion.jl      # Compatibilité avec CTBase
```

### Flux de Traitement des Exceptions

1. **Lancement**: `throw(Exceptions.Type(...))`
2. **Capture**: Par le gestionnaire d'exceptions Julia
3. **Affichage**: Via `Base.showerror` surchargé
4. **Formatage**: `format_user_friendly_error()` si `SHOW_FULL_STACKTRACE[] == false`
5. **Conversion**: Optionnel vers CTBase via `to_ctbase()`

### Configuration Globale

```julia
# Contrôle de l'affichage (défaut: false)
CTModels.set_show_full_stacktrace!(true)   # Mode développement
CTModels.set_show_full_stacktrace!(false)  # Mode utilisateur (défaut)
```

---

## Types d'Exceptions Enrichies

### 1. IncorrectArgument

**Usage**: Validation d'arguments individuels

**Champs**:
- `msg::String`: Message d'erreur principal
- `got::Union{String,Nothing}`: Valeur reçue
- `expected::Union{String,Nothing}`: Valeur attendue
- `suggestion::Union{String,Nothing}`: Comment corriger
- `context::Union{String,Nothing}`: Où l'erreur s'est produite

**Exemple Complet**:
```julia
throw(IncorrectArgument(
    "Invalid criterion type",
    got=":invalid_criterion",
    expected=":min or :max",
    suggestion="Use objective!(ocp, :min, ...) or objective!(ocp, :max, ...)",
    context="objective! function call"
))
```

### 2. UnauthorizedCall

**Usage**: Appels de fonctions non autorisés dans l'état actuel

**Champs**:
- `msg::String`: Message d'erreur principal
- `reason::Union{String,Nothing}`: Pourquoi l'appel est interdit
- `suggestion::Union{String,Nothing}`: Comment résoudre
- `context::Union{String,Nothing}`: Contexte de l'appel

**Exemple Complet**:
```julia
throw(UnauthorizedCall(
    "Cannot add constraint",
    reason="state has not been defined yet",
    suggestion="Call state!(ocp, n) before adding constraints",
    context="constraint! function validation"
))
```

### 3. NotImplemented

**Usage**: Méthodes d'interface non implémentées

**Champs Actuels** (à enrichir):
- `msg::String`: Description
- `type_info::Union{String,Nothing}`: Information de type

**Champs Manquants** (à ajouter):
- `suggestion::Union{String,Nothing}`: Suggestion de résolution
- `context::Union{String,Nothing}`: Contexte d'utilisation

**Exemple Cible**:
```julia
throw(NotImplemented(
    "Method solve! not implemented",
    type_info="MyStrategy",
    context="solve call",
    suggestion="Import the relevant package (e.g. CTDirect) or implement solve!(::MyStrategy, ...)"
))
```

### 4. ParsingError

**Usage**: Erreurs de parsing dans DSLs

**Champs Actuels** (à enrichir):
- `msg::String`: Description de l'erreur
- `location::Union{String,Nothing}`: Position dans l'input

**Champs Manquants** (à ajouter):
- `suggestion::Union{String,Nothing}`: Suggestion de correction

**Exemple Cible**:
```julia
throw(ParsingError(
    "Unexpected token 'end'",
    location="line 42, column 15",
    suggestion="Check syntax balance or remove extra 'end'"
))
```

---

## Standards de Migration

### Principes Directeurs

1. **Préservation de Sémantique**: Le message d'erreur principal doit rester identique
2. **Enrichissement Progressif**: Ajouter contexte et suggestions sans casser l'existant
3. **Uniformité**: Utiliser les mêmes patterns pour des erreurs similaires
4. **Actionnabilité**: Les suggestions doivent être directement applicables

### Règles de Formatage

#### Messages Principaux
- **Clair et concis**: "Cannot add constraint" (pas "It is not possible to add a constraint")
- **Voix active**: "State must be set before" (pas "It is required that state be set before")
- **Terminologie consistante**: Utiliser les mêmes termes que dans l'API

#### Suggestions
- **Impératives**: "Call state!(ocp, n) first" (pas "You should call state!(ocp, n)")
- **Spécifiques**: Inclure les noms de fonctions et paramètres exacts
- **Testables**: La suggestion doit résoudre le problème si suivie

#### Contexte
- **Précis**: Nom de la fonction et type de validation
- **Concise**: "constraint! validation" (pas "validation during constraint addition")
- **Consistant**: Même format pour tout le codebase

### Patterns de Migration

#### Pattern 1: Validation Simple
```julia
# Avant
throw(CTBase.IncorrectArgument("Invalid source: $source"))

# Après
throw(Exceptions.IncorrectArgument(
    "Invalid option source",
    got="$source",
    expected=":default, :user, or :computed",
    suggestion="Use one of the valid source types",
    context="option source validation"
))
```

#### Pattern 2: Vérification d'État
```julia
# Avant
@ensure(__is_state_set(ocp), CTBase.UnauthorizedCall("the state must be set."))

# Après
@ensure(__is_state_set(ocp), Exceptions.UnauthorizedCall(
    "State must be set before this operation",
    reason="state has not been defined yet",
    suggestion="Call state!(ocp, dimension) first",
    context="pre-operation validation"
))
```

#### Pattern 3: Interface Non Implémentée
```julia
# Avant
throw(CTBase.NotImplemented("id(::Type{<:$T}) must be implemented"))

# Après
throw(Exceptions.NotImplemented(
    "Strategy identifier method not implemented",
    type_info=string(T),
    context="strategy interface requirement",
    suggestion="Implement id(::Type{<:$T})::Symbol for your strategy type"
))
```

---

## Templates par Type d'Exception

### Template IncorrectArgument

```julia
throw(Exceptions.IncorrectArgument(
    "[Message principal clair et concis]",
    got="[valeur reçue exacte]",
    expected="[valeur attendue avec format]",
    suggestion="[action spécique pour corriger]",
    context="[nom de fonction et type de validation]"
))
```

**Cas d'usage**:
- Validation de types
- Vérification de valeurs
- Contrôle de formats
- Validation d'options

### Template UnauthorizedCall

```julia
throw(Exceptions.UnauthorizedCall(
    "[Message principal sur l'opération bloquée]",
    reason="[explication de pourquoi c'est interdit]",
    suggestion="[séquence correcte d'appels]",
    context="[étape de validation qui échoue]"
))
```

**Cas d'usage**:
- Ordre d'appels OCP
- Vérifications d'état
- Permissions d'accès
- Contraintes de séquence

### Template NotImplemented (Enrichi)

```julia
throw(Exceptions.NotImplemented(
    "[Message sur la fonctionnalité manquante]",
    type_info="[information sur le type concerné]",
    context="[contexte d'utilisation de l'interface]",
    suggestion="[comment résoudre - import ou implémentation]"
))
```

**Cas d'usage**:
- Méthodes abstraites
- Stratégies non supportées
- Backend non disponible
- Fonctionnalités optionnelles

### Template ParsingError (Enrichi)

```julia
throw(Exceptions.ParsingError(
    "[Description de l'erreur de syntaxe]",
    location="[position précise dans l'input]",
    suggestion="[correction syntaxique spécifique]"
))
```

**Cas d'usage**:
- DSL parsing
- Configuration files
- Expression parsing
- Format validation

---

## Processus de Migration

### Phase 0: Préparation (Enrichissement des Types)

#### 0.1 Enrichir NotImplemented
- Ajouter les champs `suggestion` et `context`
- Mettre à jour le constructeur
- Modifier `display.jl` pour afficher les nouveaux champs

#### 0.2 Enrichir ParsingError  
- Ajouter le champ `suggestion`
- Mettre à jour le constructeur et l'affichage

### Phase 1: Composants Critiques (Priorité Haute)

#### Fichiers Cibles
- `src/OCP/Components/constraints.jl` (17 erreurs)
- `src/OCP/Components/dynamics.jl` (11 erreurs)
- `src/OCP/Components/objective.jl` (~8 erreurs)
- Autres composants OCP

#### Stratégie
1. Identifier les patterns récurrents
2. Créer des templates spécifiques OCP
3. Migrer fichier par fichier
4. Tester après chaque migration

### Phase 2: Stratégies et Orchestration (Priorité Moyenne)

#### Fichiers Cibles
- `src/Strategies/api/validation.jl` (~14 erreurs)
- `src/Strategies/api/registry.jl` (7 erreurs)
- `src/Orchestration/routing.jl` (5 erreurs)
- `src/Orchestration/disambiguation.jl` (3 erreurs)

#### Stratégie
1. Standardiser les messages de validation
2. Enrichir les erreurs de registry
3. Améliorer les messages de routing

### Phase 3: Nettoyage Final (Priorité Basse)

#### Fichiers Cibles
- `src/Options/` (validation d'options)
- `src/Serialization/` (erreurs d'import/export)
- `src/Utils/macros.jl` (macros de validation)

#### Stratégie
1. Migration des cas isolés
2. Validation finale avec grep
3. Documentation des patterns restants

---

## Validation et Tests

### Tests Unitaires

#### Tests de Migration
```julia
@testset "Exception Migration" begin
    # Test que les exceptions enrichies ont les bons champs
    e = Exceptions.IncorrectArgument("test", got="a", expected="b")
    @test e.msg == "test"
    @test e.got == "a"
    @test e.expected == "b"
    
    # Test que l'affichage fonctionne
    io = IOBuffer()
    showerror(io, e)
    @test occursin("Problem:", String(take!(io)))
end
```

#### Tests de Compatibilité
```julia
@testset "CTBase Compatibility" begin
    e = Exceptions.IncorrectArgument("test")
    ctbase_e = to_ctbase(e)
    @test ctbase_e isa CTBase.IncorrectArgument
    @test occursin("test", string(ctbase_e))
end
```

### Tests d'Intégration

#### Tests de Workflow OCP
```julia
@testset "OCP Error Messages" begin
    ocp = OCP()
    
    # Test UnauthorizedCall avec état non défini
    @test_throws Exceptions.UnauthorizedCall constraint!(ocp, :test)
    
    # Vérifier que le message est enrichi
    try
        constraint!(ocp, :test)
    catch e
        @test e isa Exceptions.UnauthorizedCall
        @test !isnothing(e.suggestion)
        @test !isnothing(e.reason)
    end
end
```

### Validation Automatisée

#### Script de Vérification
```bash
#!/bin/bash
# Vérifier qu'il ne reste plus de CTBase.* direct
echo "🔍 Vérification finale de migration..."
remaining=$(grep -r "CTBase\.\(IncorrectArgument\|UnauthorizedCall\|NotImplemented\)" src/ | wc -l)
echo "📊 Exceptions restantes: $remaining"
if [ $remaining -eq 0 ]; then
    echo "✅ Migration complète!"
else
    echo "❌ Migration incomplète"
    exit 1
fi
```

---

## Bonnes Pratiques

### During Development

1. **Iterative Migration**: Migrate one file at a time and test
2. **Pattern Consistency**: Use the same templates for similar errors
3. **User Testing**: Verify that suggestions are actually helpful
4. **Documentation**: Update docstrings when changing error messages

### Code Review Guidelines

1. **Message Quality**: Check that error messages are clear and actionable
2. **Suggestion Accuracy**: Verify that suggestions actually solve the problem
3. **Context Relevance**: Ensure context helps locate the issue
4. **Backward Compatibility**: Ensure no breaking changes in error types

### Maintenance

1. **Regular Audits**: Run the audit script monthly to catch regressions
2. **Pattern Library**: Maintain a library of common error patterns
3. **User Feedback**: Collect and incorporate user feedback on error messages
4. **Documentation Updates**: Keep this reference document updated

---

## Références et Outils

### Scripts et Outils

#### Audit Script
- **Location**: `reports/2026-01-30_Exceptions/analysis/find_unmigrated_errors.sh`
- **Usage**: `./find_unmigrated_errors.sh`
- **Output**: Count and location of unmigrated exceptions

#### Validation Script
- **Location**: À créer dans `scripts/validate_exception_migration.sh`
- **Usage**: `./validate_exception_migration.sh`
- **Output**: Migration status and any remaining issues

### Documents de Référence

1. **Development Standards**: `00_development_standards_reference.md`
2. **Action Plan**: `../analysis/02_action_plan.md`
3. **Audit Results**: `../analysis/01_audit_result.md`

### Workflows Connexes

- **/test-julia**: Génération de tests unitaires Julia
- **/doc-julia**: Amélioration des docstrings Julia
- **/planning**: Planification de fonctionnalités

### Ressources Externes

1. **Julia Exception Handling**: https://docs.julialang.org/en/v1/manual/control-flow/#Exception-Handling
2. **Error Design Patterns**: https://github.com/JuliaLang/julia/blob/master/stdlib/ExceptionStack/src/ExceptionStack.jl
3. **User-Friendly Error Messages**: Best practices from Python, Rust, and Julia ecosystems

---

## Checklist de Migration

### Pour Chaque Exception Migrée

- [ ] Message principal préservé ou amélioré
- [ ] Champs optionnels ajoutés si pertinents
- [ ] Suggestion actionnable et spécifique
- [ ] Contexte précis et utile
- [ ] Format conforme aux standards
- [ ] Tests mis à jour si nécessaire
- [ ] Documentation mise à jour si pertinente

### Pour Chaque Fichier Migré

- [ ] Toutes les exceptions du fichier migrées
- [ ] Import de `Exceptions` ajouté si nécessaire
- [ ] Tests passent sans régression
- [ ] Messages cohérents dans le fichier
- [ ] Patterns réutilisés quand approprié

### Validation Finale de Projet

- [ ] Plus aucun `CTBase.*` direct dans le code
- [ ] Tous les tests passent
- [ ] Documentation mise à jour
- [ ] Script d'audit retourne 0
- [ ] Revue de code complète
- [ ] Tests d'intégration validés

---

**Note**: Ce document est vivant et doit être mis à jour au fur et à mesure de l'avancement de la migration. Contribuez à l'améliorer avec vos retours d'expérience!
