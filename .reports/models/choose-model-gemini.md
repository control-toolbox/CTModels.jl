# 🚀 Guide de Sélection IA : Projet OptimalControl.jl

Ce document définit la stratégie d'utilisation des Large Language Models (LLM) pour le développement professionnel de la suite **control-toolbox**. Le choix du modèle dépend de la complexité de la tâche : mathématiques symboliques, métaprogrammation Julia ou gestion de projet.

---

## 🏆 Classement Top 10 (Édition 2026)

| Rang | Modèle | Force Majeure | Cas d'usage privilégié |
| :--- | :--- | :--- | :--- |
| 1 | **Claude Opus 4.5 (Thinking)** | Rigueur Mathématique | Architecture, Macros `@def`, Hamiltoniens. |
| 2 | **GPT-5.2 (Extra High Reasoning)** | Algorithmique Numérique | Optimisation des solveurs, discrétisation. |
| 3 | **Claude Sonnet 4.5 (Thinking)** | Équilibre Vitesse/Logique | Développement quotidien et logique métier. |
| 4 | **DeepSeek-R1** | Raisonnement Open Source | Alternative robuste pour la logique pure. |
| 5 | **Gemini 3 Pro High** | Fenêtre de contexte (1M+) | Refactoring global, analyse de toute la toolbox. |
| 6 | **SWE-1.5 (Windsurf)** | Mode Agent Intégré | Application de changements multi-fichiers. |
| 7 | **GPT-5.2-Codex (High)** | Spécialisation Julia | Tests unitaires, documentation, conformité API. |
| 8 | **o3 (High Reasoning)** | Débogage par étapes | Résolution d'erreurs de convergence complexes. |
| 9 | **Qwen3-Coder** | Écosystème SciML | Intégration avec `DifferentialEquations.jl`. |
| 10 | **Claude 3.7 Sonnet** | Stabilité éprouvée | Maintenance de code existant et legacy. |

---

## 🛠️ Stratégie d'Utilisation par Tâche

### 1. Conception Mathématique et Symbolique
**Modèles :** `Claude Opus 4.5 (Thinking)` ou `o3 (High)`.
* **Focus :** Traduction des conditions de Karush-Kuhn-Tucker (KKT) ou du Principe du Maximum de Pontryagin (PMP).
* **Atout :** Le mode "Thinking" réduit drastiquement les erreurs de signe et les confusions dans les dérivations analytiques.

### 2. Développement de l'Infrastructure Julia
**Modèles :** `Claude Sonnet 4.5` ou `GPT-5.2-Codex`.
* **Focus :** Utilisation intensive du **Multiple Dispatch** et de la métaprogrammation.
* **Atout :** Excellente compréhension des macros Julia et de la gestion des types paramétrés pour la performance.

### 3. Analyse Globale (control-toolbox)
**Modèle :** `Gemini 3 Pro High`.
* **Focus :** Cohérence entre les packages (ex: `OptimalControl.jl` vs `CTBase.jl`).
* **Atout :** Capacité à "lire" l'intégralité du dépôt pour s'assurer qu'une modification n'entraîne pas de régression systémique.

---

## 💡 Conseils "Julia Pro" pour les Prompts

> [!IMPORTANT]
> Pour obtenir le meilleur code possible, ajoutez ces consignes à vos instructions :
> 1. **Performance :** "Privilégie les structures immuables et évite les allocations inutiles (views, in-place operations `!`)."
> 2. **Macros :** "Respecte scrupuleusement la syntaxe `@def` propre à OptimalControl.jl."
> 3. **Type Safety :** "Utilise le typage fort pour optimiser la compilation JIT."

---
**Dernière mise à jour :** Janvier 2026  
**Projet :** [control-toolbox/OptimalControl.jl](https://github.com/control-toolbox/OptimalControl.jl)