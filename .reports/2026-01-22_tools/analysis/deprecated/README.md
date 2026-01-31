# Deprecated Documents

This directory contains documents that have been **superseded** by newer approaches or designs.

---

## Documents

### [03_api_and_interface_naming.md](03_api_and_interface_naming.md)

**Status**: ❌ **OBSOLÈTE**

**Raison**: Remplacé par le document 04 (référence complète des noms de fonctions).

**Remplacé par**: [../reference/04_function_naming_reference.md](../reference/04_function_naming_reference.md)

---

### [06_registration_system_analysis.md](06_registration_system_analysis.md)

**Status**: ❌ **OBSOLÈTE**

**Raison**: Analyse initiale du système de registration qui a conduit aux documents 07 puis 11.

**Remplacé par**: [../reference/11_explicit_registry_architecture.md](../reference/11_explicit_registry_architecture.md)

**Chaîne d'évolution**:

- Document 06 (analyse) → Document 07 (design hybride) → **Document 11 (design final)**

---

### [07_registration_final_design.md](07_registration_final_design.md)

**Status**: ❌ **OBSOLÈTE**

**Raison**: Décrit l'approche hybride avec registre global (`GLOBAL_REGISTRY`), qui a été abandonnée au profit du registre explicite.

**Remplacé par**: [../reference/11_explicit_registry_architecture.md](../reference/11_explicit_registry_architecture.md)

**Différences clés**:

- ❌ Registre global mutable → ✅ Registre explicite (paramètre)
- ❌ `register_family!()` → ✅ `create_registry()`
- ❌ État global → ✅ Immutable local
- ❌ Pas thread-safe → ✅ Thread-safe

---

## Pourquoi conserver ces documents ?

Les documents obsolètes sont conservés pour :

- 📚 **Historique** : Comprendre l'évolution des décisions de design
- 🔍 **Référence** : Voir pourquoi certaines approches ont été abandonnées
- 📖 **Apprentissage** : Documenter les leçons apprises

---

## Note

Ces documents **ne doivent pas** être utilisés comme référence pour l'implémentation actuelle.
Consultez toujours les documents dans `../reference/` pour l'architecture finale.
