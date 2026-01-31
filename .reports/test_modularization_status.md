# Test Modularization Status - CTModels.jl

**Date**: 2026-01-26  
**Objective**: Encapsuler tous les tests dans des modules selon `test/README.md`  
**Status**: 25/54 fichiers modularisés (46%)

---

## 📊 Vue d'ensemble

| Catégorie | Modularisés | Non-modularisés | Total | Progression |
|-----------|-------------|-----------------|-------|-------------|
| **OCP** | 0 | 18 | 18 | 0% |
| **Strategies** | 0 | 9 | 9 | 0% |
| **Optimization** | 1 | 2 | 3 | 33% |
| **Options** | 4 | 0 | 4 | 100% ✅ |
| **Orchestration** | 3 | 0 | 3 | 100% ✅ |
| **Utils** | 4 | 0 | 4 | 100% ✅ |
| **DOCP** | 1 | 0 | 1 | 100% ✅ |
| **Init** | 2 | 0 | 2 | 100% ✅ |
| **Modelers** | 1 | 0 | 1 | 100% ✅ |
| **IO** | 2 | 0 | 2 | 100% ✅ |
| **Plot** | 1 | 0 | 1 | 100% ✅ |
| **Integration** | 1 | 0 | 1 | 100% ✅ |
| **Meta** | 3 | 0 | 3 | 100% ✅ |
| **Ext** | 1 | 0 | 1 | 100% ✅ |
| **Types** | 1 | 0 | 1 | 100% ✅ |
| **TOTAL** | **25** | **29** | **54** | **46%** |

---

## ✅ Modules déjà conformes (25 fichiers)

### Options (4/4) ✅
- `test/suite/options/test_extraction_api.jl` → `TestOptionsExtractionAPI`
- `test/suite/options/test_not_provided.jl` → `TestOptionsNotProvided`
- `test/suite/options/test_option_definition.jl` → `TestOptionsOptionDefinition`
- `test/suite/options/test_options_value.jl` → `TestOptionsOptionsValue`

### Orchestration (3/3) ✅
- `test/suite/orchestration/test_disambiguation.jl` → `TestOrchestrationDisambiguation`
- `test/suite/orchestration/test_method_builders.jl` → `TestOrchestrationMethodBuilders`
- `test/suite/orchestration/test_routing.jl` → `TestOrchestrationRouting`

### Utils (4/4) ✅
- `test/suite/utils/test_function_utils.jl` → `TestUtilsFunctionUtils`
- `test/suite/utils/test_interpolation.jl` → `TestUtilsInterpolation`
- `test/suite/utils/test_macros.jl` → `TestUtilsMacros`
- `test/suite/utils/test_matrix_utils.jl` → `TestUtilsMatrixUtils`

### Autres modules complets (14 fichiers) ✅
- `test/suite/docp/test_docp.jl` → `TestDOCP`
- `test/suite/init/test_initial_guess.jl` → `TestInitInitialGuess`
- `test/suite/init/test_initial_guess_types.jl` → `TestInitInitialGuessTypes`
- `test/suite/modelers/test_modelers.jl` → `TestModelers`
- `test/suite/io/test_export_import.jl` → `TestExportImport`
- `test/suite/io/test_ext_exceptions.jl` → `TestExtExceptions`
- `test/suite/plot/test_plot.jl` → `TestPlot`
- `test/suite/integration/test_end_to_end.jl` → `TestEndToEnd`
- `test/suite/meta/test_CTModels.jl` → `TestCTModels`
- `test/suite/meta/test_aqua.jl` → `TestAqua`
- `test/suite/meta/test_exports.jl` → `TestExports`
- `test/suite/ext/test_madnlp.jl` → `TestExtMadNLP`
- `test/suite/types/test_types.jl` → `TestTypes`
- `test/suite/optimization/test_real_problems.jl` → `TestOptimizationRealProblems`

---

## ❌ Fichiers à modulariser (29 fichiers)

### 🔴 PRIORITÉ 1 : OCP (18 fichiers - 0% modularisés)

**Impact** : 543 tests, module le plus important du projet

1. `test/suite/ocp/test_constraints.jl` (~50 tests)
2. `test/suite/ocp/test_control.jl` (~30 tests)
3. `test/suite/ocp/test_defaults.jl` (~20 tests)
4. `test/suite/ocp/test_definition.jl` (~40 tests)
5. `test/suite/ocp/test_dual_model.jl` (~25 tests)
6. `test/suite/ocp/test_dynamics.jl` (~35 tests)
7. `test/suite/ocp/test_model.jl` (~45 tests)
8. `test/suite/ocp/test_objective.jl` (~40 tests)
9. `test/suite/ocp/test_ocp.jl` (~60 tests)
10. `test/suite/ocp/test_ocp_components.jl` (~30 tests)
11. `test/suite/ocp/test_ocp_model_types.jl` (~25 tests)
12. `test/suite/ocp/test_ocp_solution_types.jl` (~30 tests)
13. `test/suite/ocp/test_print.jl` (~15 tests)
14. `test/suite/ocp/test_solution.jl` (~40 tests)
15. `test/suite/ocp/test_state.jl` (~30 tests)
16. `test/suite/ocp/test_time_dependence.jl` (~20 tests)
17. `test/suite/ocp/test_times.jl` (~25 tests)
18. `test/suite/ocp/test_variable.jl` (~30 tests)

**Modules à créer** :
- `TestOCPConstraints`
- `TestOCPControl`
- `TestOCPDefaults`
- `TestOCPDefinition`
- `TestOCPDualModel`
- `TestOCPDynamics`
- `TestOCPModel`
- `TestOCPObjective`
- `TestOCP`
- `TestOCPComponents`
- `TestOCPModelTypes`
- `TestOCPSolutionTypes`
- `TestOCPPrint`
- `TestOCPSolution`
- `TestOCPState`
- `TestOCPTimeDependence`
- `TestOCPTimes`
- `TestOCPVariable`

### 🟡 PRIORITÉ 2 : Strategies (9 fichiers - 0% modularisés)

**Impact** : 389 tests

1. `test/suite/strategies/test_abstract_strategy.jl`
2. `test/suite/strategies/test_builders.jl`
3. `test/suite/strategies/test_configuration.jl`
4. `test/suite/strategies/test_introspection.jl`
5. `test/suite/strategies/test_metadata.jl`
6. `test/suite/strategies/test_registry.jl`
7. `test/suite/strategies/test_strategy_options.jl`
8. `test/suite/strategies/test_utilities.jl`
9. `test/suite/strategies/test_validation.jl`

**Modules à créer** :
- `TestStrategiesAbstractStrategy`
- `TestStrategiesBuilders`
- `TestStrategiesConfiguration`
- `TestStrategiesIntrospection`
- `TestStrategiesMetadata`
- `TestStrategiesRegistry`
- `TestStrategiesStrategyOptions`
- `TestStrategiesUtilities`
- `TestStrategiesValidation`

### 🟢 PRIORITÉ 3 : Optimization (2 fichiers - 33% modularisés)

**Impact** : ~50 tests

1. `test/suite/optimization/test_error_cases.jl`
2. `test/suite/optimization/test_optimization.jl`

**Modules à créer** :
- `TestOptimizationErrorCases`
- `TestOptimization`

---

## 📋 Convention de modularisation (selon test/README.md)

### Structure requise

```julia
module TestModuleName  # Nom du module en PascalCase

using Test
using CTModels
using Main.TestOptions: VERBOSE, SHOWTIMING  # Si disponible
# ... autres imports

# Définir les structs au top-level (CRUCIAL !)
struct MyDummyModel end

function test_module_name()
    Test.@testset "Module Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Tests ici
    end
end

end # module

# CRITIQUE : Redéfinir la fonction dans le scope externe
test_module_name() = TestModuleName.test_module_name()
```

### Règles importantes

1. ✅ **Module** : Chaque fichier doit définir un module
2. ✅ **Nom du module** : `TestCategoryName` (PascalCase)
3. ✅ **Fonction d'entrée** : `test_category_name()` (snake_case)
4. ✅ **Structs au top-level** : JAMAIS dans la fonction de test
5. ✅ **Qualification** : Toujours qualifier les appels (ex: `CTModels.solve(...)`)
6. ✅ **VERBOSE/SHOWTIMING** : Utiliser si `Main.TestOptions` existe
7. ✅ **Re-export** : Fonction d'entrée redéfinie hors du module

---

## 🎯 Plan d'action proposé

### Phase 1 : OCP (18 fichiers) - Priorité HAUTE
**Temps estimé** : 3-4 heures  
**Impact** : 543 tests, ~50% du total

**Approche** :
1. Commencer par les plus petits fichiers (test_print.jl, test_defaults.jl)
2. Continuer avec les fichiers moyens
3. Terminer avec les plus gros (test_ocp.jl, test_model.jl)

### Phase 2 : Strategies (9 fichiers) - Priorité MOYENNE
**Temps estimé** : 2-3 heures  
**Impact** : 389 tests, ~35% du total

### Phase 3 : Optimization (2 fichiers) - Priorité BASSE
**Temps estimé** : 30 minutes  
**Impact** : ~50 tests, ~5% du total

### Temps total estimé : 6-8 heures

---

## 📊 Bénéfices attendus

### Isolation des namespaces
- ✅ Évite les conflits de noms
- ✅ Meilleure organisation du code
- ✅ Facilite le debugging

### Conformité aux standards
- ✅ Suit les conventions de CTBase.jl
- ✅ Compatible avec TestRunner
- ✅ Structure cohérente dans tout le projet

### Maintenabilité
- ✅ Code plus facile à comprendre
- ✅ Tests plus faciles à modifier
- ✅ Meilleure séparation des responsabilités

---

## 🔧 Commandes utiles

### Vérifier la modularisation d'un fichier
```bash
grep -q "^module Test" test/suite/ocp/test_constraints.jl && echo "✅ Modularisé" || echo "❌ Non modularisé"
```

### Lister tous les fichiers non modularisés
```bash
for f in test/suite/**/*.jl; do 
  if [[ -f "$f" && "$f" == *test_*.jl ]]; then 
    if ! grep -q "^module Test" "$f"; then 
      echo "$f"
    fi
  fi
done
```

### Tester un fichier spécifique après modularisation
```bash
julia --project -e 'include("test/suite/ocp/test_constraints.jl"); test_constraints()'
```

---

## 📝 Checklist de modularisation

Pour chaque fichier à modulariser :

- [ ] Créer le module avec le bon nom
- [ ] Ajouter les imports nécessaires
- [ ] Déplacer les structs au top-level du module
- [ ] Wrapper les tests dans la fonction d'entrée
- [ ] Ajouter VERBOSE et SHOWTIMING si disponible
- [ ] Re-exporter la fonction d'entrée
- [ ] Tester que le fichier fonctionne
- [ ] Vérifier que tous les tests passent
- [ ] Commit les changements

---

**Prochaine étape recommandée** : Commencer par modulariser les fichiers OCP, en commençant par les plus petits.
