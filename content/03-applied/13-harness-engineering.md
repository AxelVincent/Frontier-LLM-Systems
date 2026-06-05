---
title: "13. Harness engineering vs prompt engineering"
description: "Le système qui entoure le modèle (event loop, tool layer, state, recovery, observability) — où se gagne la qualité perçue."
tags:
  - applied
aliases:
  - 01-harness-engineering
  - 13-harness-engineering
---

> [!abstract] Point d'entrée du parcours "applied"
> Cette note ouvre la section *Engineering autour du modèle*. Aucun prérequis dur — utile d'avoir survolé [[02-inference/09-prefill-vs-decode|09. Prefill vs decode]] pour comprendre pourquoi le coût d'un appel se décompose en TTFT et TPOT, mais non bloquant.

> [!tip] Notes liées
> [[03-applied/14-context-engineering]] · [[03-applied/17-function-calling-reliability]] · [[03-applied/18-agent-guardrails]] · [[05-ops-safety/23-llm-observability]]

## Concept

**Prompt engineering** consiste à optimiser le texte qui constitue l'input du modèle.

**Harness engineering** consiste à concevoir le **système qui entoure** le modèle : la logique qui décide *quand* l'appeler, *avec quel contexte*, *quels outils sont exposés*, *comment recover en cas d'échec*, *comment déterminer qu'une tâche est terminée*, et *comment l'observer*.

> [!example] Intuition
> Le modèle est un **artefact stateless** : `(prompt, params) → distribution sur le next token`. Le harness est le *runtime* qui le pilote : il décide quoi mettre dans le prompt, quels tools exposer, comment parser la sortie, comment retry, quand terminer, comment instrumenter. Deux produits sur le même modèle (Cursor, Claude Code, Copilot) divergent radicalement parce que leurs harness divergent — la qualité perçue se joue ici, pas dans le system prompt.

L'industrie a établi en 2023-2024 qu'une part majoritaire de la qualité perçue d'une feature LLM provient du harness, et non du prompt. Des produits comme Claude Code, Cursor, Devin et Copilot utilisent des prompts comparables mais offrent des expériences radicalement différentes — la différence se fait dans leur harness respectif.

## Composants d'un harness

- **Boucle de contrôle** : l'event loop qui orchestre {model call → tool call → observation → model call}. Patterns canoniques : linéaire (single-shot), ReAct (think/act/observe), Plan-and-Execute (planification puis exécution), Tree-of-Thought (branches parallèles).
- **State management** : ce qui persiste entre les tours, ce qui est compacté, ce qui est tronqué, ce qui est rejoué. Voir [[03-applied/14-context-engineering]].
- **Tool layer** : registry des outils, validation des arguments, exécution sandboxée, formatage des résultats. Voir [[03-applied/17-function-calling-reliability]].
- **Recovery** : gestion des hallucinations de tool names, du JSON invalide, du dépassement de budget. Voir [[03-applied/16-structured-outputs]].
- **Termination logic** : signaux à partir desquels le harness conclut que la tâche est terminée. Voir [[03-applied/18-agent-guardrails]].
- **Observability hooks** : émission de traces, metrics et events. Voir [[05-ops-safety/23-llm-observability]].

## Anti-pattern : "tout est dans le system prompt"

Le réflexe initial fréquent consiste à concentrer tous les problèmes dans un system prompt monolithique. Trois raisons de l'éviter :

- Le prompt est facturé à **chaque** appel (hors prompt caching).
- Cela rend non-déterministe des décisions qui devraient être déterministes ("appeler tool X si Y" relève de la logique applicative, pas du LLM).
- Le code devient non-testable. Un harness modulaire se teste unitairement ; un prompt monolithique se "vibe-checke".

## Vocabulaire clé

`harness`, `event loop`, `tool registry`, `state compaction`, `repair loop`, `termination condition`, `agent loop`, `ReAct`, `Plan-and-Execute`, `Tree-of-Thought`.

## Synthèse

Le prompt engineering optimise le texte d'une call unique. Le harness engineering conçoit le système : boucle de contrôle, tool layer, gestion d'état inter-tours, conditions de terminaison, recovery, hooks d'observability. Dans des produits matures comme Claude Code ou Cursor, l'essentiel de la qualité perçue provient du harness. C'est aussi ce qui rend un système LLM testable : on teste le harness en mockant le modèle, pas l'inverse.
