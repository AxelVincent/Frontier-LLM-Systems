---
title: "21. Retrieval evals"
description: "Recall@k, precision, grounding, attribution, answer relevancy : mesurer la qualité d'un système de retrieval."
tags:
  - retrieval-quality
aliases:
  - 14-retrieval-evals
  - 21-retrieval-evals
---

> [!tip] Notes liées
> [[04-retrieval-quality/20-rag-architecture]] · [[04-retrieval-quality/22-evals]] · [[05-ops-safety/23-llm-observability]]

## Le problème

Un système RAG fonctionne-t-il ? Sans mesure, on décide au "feeling", et on dégrade sans s'en rendre compte. La mesure est non-négociable.

## Les métriques

### Retrieval-side (qualité du retrieval seul, indépendant du LLM)

- **Recall@k** : proportion des chunks pertinents présents dans le top-k.
- **Precision@k** : proportion du top-k qui sont pertinents.
- **MRR** (Mean Reciprocal Rank) : 1 / rank du premier chunk pertinent. Mesure "le premier résultat est-il bon ?".
- **NDCG** (Normalized Discounted Cumulative Gain) : tient compte de l'ordre et de la gradation de pertinence.
- **Hit rate** : au moins un chunk pertinent dans le top-k ? Oui/non.

**Pré-requis** : un ground truth — dataset de (query, list of relevant chunk_ids), labellé manuellement ou semi-auto via LLM-as-judge.

### Generation-side (qualité de la réponse finale)

- **Faithfulness / Grounding** : la réponse est-elle supportée par les chunks retrieved ? (Pas d'[[01-architecture/07-post-training-alignment|hallucination]] au-delà du contexte fourni.)
- **Answer relevancy** : la réponse adresse-t-elle la question ?
- **Context relevancy** : les chunks fournis sont-ils pertinents pour la question ?
- **Citation accuracy** : si la réponse cite des sources, les citations correspondent-elles au contenu cité ?
- **Answer completeness** : la réponse couvre-t-elle tous les aspects de la question ?

## Outils

- **Ragas** : framework Python d'eval RAG. Métriques standards + LLM-as-judge.
- **TruLens** : eval + tracing.
- **DeepEval** : pytest pour LLM.
- **Phoenix (Arize)** : eval + observability.
- **[[05-ops-safety/23-llm-observability|LangSmith]]** : eval intégré dans l'écosystème LangChain.

## Grounding et attribution

**Grounding** : chaque claim dans la réponse est traçable à un chunk source. Sans grounding, aucune garantie sur l'absence d'invention.

**Attribution** : citer explicitement les chunks utilisés. Patterns :

- **Inline citations** : "Selon le document [chunk_3], X est vrai. Selon [chunk_7], Y."
- **Footnote-style** : réponse en prose, références à la fin.
- **Structured** : output JSON avec `claim` + `source_chunk_ids`.
- **Auto-citation via [[03-applied/16-structured-outputs|constrained decoding]]** : forcer le modèle à émettre des `<source id="X"/>` tags, validés contre les chunks fournis. Voir [[03-applied/16-structured-outputs]].

### Eval de l'attribution

- Citation precision : % de citations pointant au bon chunk.
- Citation recall : % de claims comportant une citation.

## Failure modes typiques

- **Hallucinated citation** : le modèle invente un `chunk_42` inexistant. Détection : valider que chaque citation existe dans le set fourni.
- **Misattribution** : le modèle cite le bon chunk pour une mauvaise raison (le chunk ne supporte pas le claim). Détection : LLM-as-judge sur (claim, cited_chunk) → "is this claim supported by this chunk?".
- **Over-citation** : citation à chaque phrase, même générale. Brouille l'utilité.
- **Under-citation** : citation uniquement quand "obvious", omission sur des claims importants.

## Workflow d'eval

1. **Constituer un [[04-retrieval-quality/22-evals|golden set]]** : 100-500 queries avec (relevant_chunks, ideal_answer). Labellé par humains ou via LLM-as-judge avec human spot-check.
2. **Run le pipeline** sur ce set, collecter les outputs.
3. **Compute metrics** : recall@k, precision@k, faithfulness, citation accuracy.
4. **Track over time** : à chaque changement ([[04-retrieval-quality/20-rag-architecture|chunking]] strategy, embedding model, reranker), re-run, comparer.
5. **[[04-retrieval-quality/22-evals|Adversarial set]]** : queries spécifiquement designed pour casser (ambiguës, hors-sujet, multi-hop).

## Vocabulaire clé

`recall@k`, `precision@k`, `MRR`, `NDCG`, `hit rate`, `faithfulness`, `grounding`, `answer relevancy`, `context relevancy`, `citation accuracy`, `attribution`, `inline citations`, `Ragas`, `LLM-as-judge`, `golden set`, `adversarial set`.

## Synthèse

Les retrieval evals se déclinent en deux couches. Retrieval-side : recall@k, precision@k, MRR, NDCG, sur un golden set query → chunks pertinents. Generation-side : faithfulness — la réponse est-elle supportée par les chunks — answer relevancy, context relevancy, et citation accuracy. Le grounding désigne la propriété que chaque claim trace à un chunk source. L'attribution désigne la citation explicite. Failure modes : hallucinated citations vers un chunk inexistant, misattribution où la citation pointe au bon chunk mais ne supporte pas le claim, sur-citation et sous-citation. Outils : Ragas, TruLens, DeepEval. Workflow : golden set + adversarial set, run à chaque changement, track over time pour détecter les regressions.
