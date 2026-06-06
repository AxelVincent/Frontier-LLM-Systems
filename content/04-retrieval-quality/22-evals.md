---
title: "22. Evals : golden sets, regression, adversarial, LLM-as-judge"
description: "La discipline qui permet d'itérer sans casser : datasets, métriques, LLM-as-judge, adversarial."
tags:
  - retrieval-quality
aliases:
  - 15-evals
  - 22-evals
---

> [!tip] Notes liées
> [[04-retrieval-quality/21-retrieval-evals]] · [[05-ops-safety/23-llm-observability]] · [[06-meta/29-production-failure-modes]]

## Le problème

Lorsqu'un système LLM est déployé en production, les questions critiques deviennent : la qualité est-elle meilleure qu'avant ? Les changements (prompt, model, retrieval) ont-ils introduit une régression ? Sans evals, ces questions ne sont pas répondables, et les régressions silencieuses s'accumulent.

## Les types d'eval

### 1. Golden sets

- Dataset fixe de (input, expected_output) curated manuellement.
- Typiquement 50-500 examples.
- "Référence" stable. Le pipeline tourne sur le golden set et les résultats sont comparés.

### 2. Regression tests

- Analogues aux tests unitaires : `expect(model("X")).to.equal_or_satisfy_criterion(Y)`.
- Ajoutés réactivement : un bug en production → ajout du case au regression set.
- Pipeline CI : à chaque PR, run du regression set, blocage si delta négatif.

### 3. Adversarial tests

- Cases designed pour casser : [[05-ops-safety/25-safety-engineering|prompt injection]], edge cases, multi-hop reasoning, distractors.
- Sources : red team manuelle, datasets publics ([[05-ops-safety/25-safety-engineering|jailbreak datasets]], MMLU Pro, GPQA), génération auto via LLM.
- Métrique : pass rate sur le adversarial set.

### 4. LLM-as-judge

- Un autre LLM évalue la sortie selon des critères définis.
- Patterns : pairwise comparison (A vs B), absolute scoring (1-5), criteria-based (faithful? relevant? helpful?).

> [!example] Intuition — LLM-as-judge
> Quand aucune métrique déterministe (BLEU, exact match) ne capture la qualité réelle, on délègue le scoring à un LLM tiers via un prompt d'évaluation. Avantage : scalable et capable de juger des dimensions floues (fidélité, utilité, ton). Limites à connaître : biais positionnel (préfère le premier item d'une comparaison pairwise), biais de longueur, et **corrélation des erreurs** — un juge basé sur la même famille de modèle que le système évalué partage ses angles morts. Mitigations standard : randomiser l'ordre, swap A/B, et calibrer le juge contre un set d'annotations humaines.
- Avantage : scale au-delà du human labeling.
- Limites : biais du judge (position bias, length bias, self-preference si le judge est de la même famille que le candidate), inconsistance.
- Mitigations : random shuffling, multi-judge ensemble, calibration vs human ratings.

### 5. Human evals

- Nécessaire en bout de chaîne. Judge ultime.
- Coût élevé. Sub-set restreint (10-50 examples) revu manuellement.
- Annotateurs internes vs crowdsourcing (Scale, Surge, Toloka). Trade-off coût/qualité/spécialisation.

## Eval-driven development

Workflow mature :

1. **Définir le problème** : "réponses fidèles au doc fourni, en français, sans citations hallucinées".
2. **Constituer le golden set** initial : 30-100 examples couvrant les cases représentatifs.
3. **Définir les métriques** : [[04-retrieval-quality/21-retrieval-evals|faithfulness]] > 95%, [[01-architecture/07-post-training-alignment|hallucinated]] citations = 0, latency p99 < 3s.
4. **Build une baseline** : un pipeline naïf.
5. **Mesurer** : scores sur golden set.
6. **Iterate** : modifier une variable à la fois, mesurer.
7. **Ajouter au golden set** au fur et à mesure que de nouveaux cases apparaissent en production.
8. **CI** : run des evals à chaque PR, blocage des regressions.

## LLM-as-judge en détail

Prompt pattern :

```
You are evaluating an AI response.

Question: {query}
Response: {response}
Expected: {gold}

Score 1-5 on:
- Faithfulness: is the response grounded in the source?
- Relevance: does it answer the question?
- Quality: is it well-formed?

Output JSON: {"faithfulness": int, "relevance": int, "quality": int, "reasoning": string}
```

### Biais documentés

- **Position bias** : en pairwise, l'option en première position est favorisée.
- **Length bias** : les réponses plus longues sont jugées meilleures.
- **Verbosity bias** : réponses avec beaucoup de mots de "qualité" gagnent.
- **Self-preference** : GPT-4 préfère les réponses de GPT-4.
- **Anchoring** : le judge ancre sur le premier critère, néglige les autres.

### Mitigations

- Random shuffling de l'ordre.
- Multi-judge (GPT-4 + Claude + Mistral) + majority vote.
- Calibration : 50 examples labellés humainement, mesure de correlation avec judge, recalibration du prompt.

## Pièges classiques

- **Overfit au golden set** : optimisation jusqu'à 95% sur le set, en réalité overfit du prompt à ces 100 examples. Nécessite un test set distinct + adversarial.
- **Stale golden set** : le produit évolue, le golden set n'est plus représentatif.
- **LLM-as-judge bias non mesuré** : le score est trusté sans vérification de la correlation avec human labels.
- **Absence d'adversarial set** : on rate les jailbreaks et les edge cases.
- **Eval uniquement offline** : on rate les drift en production. Nécessite eval continue sur sample de traffic réel. Voir [[05-ops-safety/23-llm-observability]].

## Vocabulaire clé

`golden set`, `regression test`, `adversarial test`, `red team`, `LLM-as-judge`, `pairwise comparison`, `absolute scoring`, `criteria-based eval`, `position bias`, `length bias`, `self-preference`, `human eval`, `inter-annotator agreement`, `calibration`, `eval harness`, `Ragas`, `DeepEval`, `OpenEval`, `Promptfoo`.

## Synthèse

Les evals se déclinent en plusieurs couches. Golden sets, fixes, labellés, pour mesurer la qualité de base. Regression tests qui croissent à chaque bug en production. Adversarial tests designed pour casser : prompt injection, multi-hop reasoning, distractors. LLM-as-judge pour scaler au-delà du human labeling, avec attention aux biais : position bias, length bias, self-preference si judge et candidate sont de la même famille. Mitigations : random shuffling, multi-judge ensemble, calibration vs human ratings sur un petit subset. Human eval reste le judge ultime, sur un sub-set bien choisi. CI qui bloque les PRs en régression. Pièges : overfit au golden set, stale golden set, et eval offline seulement qui rate les drifts en production — d'où l'eval continue sur sample de traffic réel.
