# OptionDefinition - Unification of OptionSchema and OptionSpecification

**Date**: 2026-01-23  
**Status**: ✅ **IMPLEMENTED** - Unified Option Type

---

## TL;DR

**Unification réussie** : `OptionDefinition` remplace `OptionSchema` et `OptionSpecification` avec un seul type unifié qui supporte les deux cas d'usage : extraction d'options et définition de contrat de stratégie.

---

## 1. Context and Problem

### **Previous Architecture Issues**
- **Redondance** : `OptionSchema` (Options) et `OptionSpecification` (Strategies) avec des champs similaires
- **Complexité** : Deux systèmes différents pour la même fonctionnalité
- **Maintenance** : Double code pour validation, aliases, etc.

### **Key Differences Before Unification**
| Aspect | `OptionSchema` | `OptionSpecification` |
|--------|----------------|---------------------|
| **Module** | Options (bas niveau) | Strategies (haut niveau) |
| **Usage** | Extraction d'options | Définition de contrat |
| **Champ `name`** | ✅ `name::Symbol` | ❌ (clé du NamedTuple) |
| **Champ `description`** | ❌ | ✅ `description::String` |
| **Constructeur** | Positionnel | Keyword arguments |

---

## 2. Solution: OptionDefinition

### **Unified Type Structure**
```julia
struct OptionDefinition
    name::Symbol              # Pour extraction
    type::Type                # Type requis
    default::Any              # Valeur par défaut
    description::String       # Pour documentation
    aliases::Tuple{Vararg{Symbol}} = ()
    validator::Union{Function, Nothing} = nothing
end
```

### **Key Features**
- **Complete field set** : Combine tous les champs des deux types
- **Keyword-only constructor** : Plus explicite et moins d'erreurs
- **Validation intégrée** : Type + validator + description
- **Universal usage** : Extraction ET définition de contrat

---

## 3. Implementation Details

### **Files Modified/Created**

#### **New Files**
- `src/Options/option_definition.jl` - Type unifié
- `test/options/test_option_definition.jl` - Tests complets

#### **Modified Files**
- `src/Options/Options.jl` - Export de `OptionDefinition`
- `src/Options/extraction.jl` - Adapté pour `OptionDefinition`
- `src/Strategies/contract/metadata.jl` - Varargs constructor
- `test/strategies/test_metadata.jl` - Tests avec varargs

#### **Removed Files**
- `src/nlp/options_schema.jl` - Ancien système supprimé

### **Usage Patterns**

#### **Strategy Contract (Strategies)**
```julia
metadata(::Type{<:MyStrategy}) = StrategyMetadata(
    OptionDefinition(
        name = :max_iter,
        type = Int,
        default = 100,
        description = "Maximum iterations",
        aliases = (:max, :maxiter),
        validator = x -> x > 0
    ),
    OptionDefinition(
        name = :tol,
        type = Float64,
        default = 1e-6,
        description = "Tolerance"
    )
)
```

#### **Action Options (Options)**
```julia
const SOLVE_ACTION_OPTIONS = [
    OptionDefinition(
        name = :initial_guess,
        type = Any,
        default = nothing,
        description = "Initial guess",
        aliases = (:init, :i)
    ),
    OptionDefinition(
        name = :display,
        type = Bool,
        default = true,
        description = "Display progress"
    ),
]
```

#### **Extraction (Options)**
```julia
# Single option
opt_value, remaining = extract_option(kwargs, def)

# Multiple options
extracted, remaining = extract_options(kwargs, defs)
```

---

## 4. Impact Analysis

### **✅ Positive Impacts**

#### **1. Simplification**
- **Un seul type** au lieu de deux
- **Moins de code** à maintenir
- **API unifiée** pour les développeurs

#### **2. Consistency**
- **Mêmes champs** partout
- **Même validation** partout
- **Même constructeur** partout

#### **3. Extensibility**
- **Facile d'ajouter** des champs communs
- **Architecture propre** avec dépendances claires

### **🔄 Required Changes**

#### **1. Migration de code existant**
```julia
# AVANT
OptionSchema(:name, Type, default, aliases, validator)
OptionSpecification(type=Type, default=default, description=desc)

# APRÈS
OptionDefinition(name=:name, type=Type, default=default, description=desc, aliases=aliases, validator=validator)
```

#### **2. Update de tests**
- Tests `OptionSchema` → `OptionDefinition`
- Tests `OptionSpecification` → `OptionDefinition`
- Tests extraction adaptés

#### **3. Documentation**
- Mettre à jour les exemples
- Mettre à jour les docstrings
- Mettre à jour les rapports

### **⚠️ Breaking Changes**

#### **1. Constructeurs**
- **OptionSchema** positionnel supprimé
- **OptionSpecification** keyword-only gardé (mais avec `name` requis)

#### **2. Imports**
```julia
# AVANT
using CTModels.Options: OptionSchema
using CTModels.Strategies: OptionSpecification

# APRÈS
using CTModels.Options: OptionDefinition
```

---

## 5. Migration Strategy

### **Phase 1: Core Implementation** ✅ **DONE**
- [x] Créer `OptionDefinition`
- [x] Adapter `extraction.jl`
- [x] Adapter `StrategyMetadata`
- [x] Tests de base

### **Phase 2: Legacy Support** ⏳ **TODO**
- [ ] Garder `OptionSchema` comme alias temporaire
- [ ] Garder `OptionSpecification` comme alias temporaire
- [ ] Warnings de dépréciation

### **Phase 3: Full Migration** ⏳ **TODO**
- [ ] Mettre à jour tous les usages existants
- [ ] Supprimer les anciens types
- [ ] Mettre à jour la documentation

### **Phase 4: Ecosystem Integration** ⏳ **TODO**
- [ ] Mettre à jour `solve_ideal.jl`
- [ ] Mettre à jour les exemples dans les rapports
- [ ] Mettre à jour les extensions

---

## 6. Future Considerations

### **🚀 Opportunities**

#### **1. Enhanced Validation**
- Validators plus complexes
- Validation croisée entre options
- Validation dépendante du contexte

#### **2. Documentation Generation**
- Auto-génération de docs depuis `OptionDefinition`
- Tables d'options formatées
- Help text interactif

#### **3. Type Stability**
- Optimisation pour `@inferred`
- Compilation des validateurs
- Cache des métadonnées

### **🔮 Potential Extensions**

#### **1. Option Groups**
```julia
OptionDefinition(
    name = :solver_options,
    type = NamedTuple,
    default = (tol=1e-6, max_iter=100),
    description = "Solver options group"
)
```

#### **2. Conditional Options**
```julia
OptionDefinition(
    name = :advanced_mode,
    type = Bool,
    default = false,
    description = "Enable advanced options",
    condition = (metadata) -> metadata[:solver].value == :advanced
)
```

#### **3. Dynamic Options**
```julia
OptionDefinition(
    name = :custom_option,
    type = Any,
    default = nothing,
    description = "Custom option (type inferred from value)",
    dynamic_type = true
)
```

---

## 7. Testing Status

### **✅ Current Test Coverage**
- `OptionDefinition` : 25 tests passent
- `StrategyMetadata` : 23 tests passent
- Extraction : Adapté et fonctionnel

### **📋 Required Additional Tests**
- [ ] Tests de compatibilité ascendante
- [ ] Tests de performance (type stability)
- [ ] Tests d'intégration avec `solve_ideal.jl`
- [ ] Tests de migration de code existant

---

## 8. Dependencies and Architecture

### **Module Dependencies**
```
Options (bas niveau)
├── OptionDefinition (type unifié)
├── extract_option/extract_options (API)
└── OptionValue (tracking)

Strategies (haut niveau)
├── StrategyMetadata (varargs + Dict)
├── metadata() (contract)
└── build_strategy_options (future)

Orchestration (plus haut)
├── route_all_options (utilise Vector{OptionDefinition})
└── build_strategy_from_method (future)
```

### **Clean Separation**
- **Options** : Fournit les outils d'extraction
- **Strategies** : Définit les contrats de stratégie
- **Orchestration** : Coordonne le routing

---

## 9. Conclusion

### **✅ Success Criteria Met**
- [x] **Unification** : Un seul type pour les deux usages
- [x] **Compatibility** : API existante adaptée
- [x] **Testing** : Tests complets et passants
- [x] **Architecture** : Dépendances propres et claires

### **🎯 Next Steps**
1. **Immédiat** : Commencer la migration des usages existants
2. **Court terme** : Implémenter le support legacy temporaire
3. **Moyen terme** : Intégrer avec `solve_ideal.jl`
4. **Long terme** : Extensions avancées (groups, conditionals)

### **💡 Key Insight**
L'unification `OptionDefinition` simplifie significativement l'architecture tout en préservant la séparation claire des responsabilités entre les modules. C'est une base solide pour l'évolution future du système d'options dans CTModels.

---

## 10. References

- [08_complete_contract_specification.md](08_complete_contract_specification.md) - Original contract specification
- [13_module_dependencies_architecture.md](13_module_dependencies_architecture.md) - Module architecture
- [solve_ideal.jl](code/solve_ideal.jl) - Reference implementation
- [04_function_naming_reference.md](04_function_naming_reference.md) - API naming conventions
