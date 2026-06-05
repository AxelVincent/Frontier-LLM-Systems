---
title: "10. Continuous batching et paged attention"
description: "Comment vLLM atteint un throughput élevé : continuous batching, PagedAttention, prefix sharing."
tags:
  - inference
aliases:
  - 06-continuous-batching-paged-attention
  - 10-continuous-batching-paged-attention
---

> [!tip] Notes liées
> [[02-inference/08-kv-cache-management]] · [[02-inference/09-prefill-vs-decode]] · [[02-inference/11-speculative-quant-distill]] · [[06-meta/28-tradeoffs]]

## Le problème : static batching

Approche naïve : on attend que N requêtes arrivent, on les regroupe en batch, et le batch génère jusqu'à ce que **la requête la plus longue** soit terminée. Les requêtes courtes finissent vite et **attendent** dans le batch — le GPU produit des padding tokens inutiles. Throughput effectif faible, latency variable car déterminée par la requête la plus longue du batch.

> [!example] Intuition — scheduling au niveau token, pas requête
> Le static batching synchronise la durée du batch sur la **requête la plus longue** : tous les tokens des autres requêtes sont gaspillés en padding. Le continuous batching schedule à la granularité du **step de génération** : à chaque tick, les requêtes terminées libèrent leur slot et de nouvelles entrent. Vu autrement, on passe d'un scheduler par lot fermé à un scheduler par tâche préemptible.

## Continuous batching (iteration-level batching)

Synonymes : **dynamic batching**, **in-flight batching**.

- À chaque **step de génération** (chaque token), le scheduler évalue les requêtes actives.
- Lorsqu'une requête termine (EOS ou max_tokens), elle quitte le batch.
- Lorsqu'une nouvelle requête arrive, elle est intégrée dès qu'il y a de la place (KV cache disponible).
- Le batch est **dynamique** : sa composition évolue à chaque step.

## Pourquoi cette approche change tout

Le decode est memory-bound ([[02-inference/09-prefill-vs-decode]]). Le GPU passe son temps à lire le KV cache plutôt qu'à compute. L'ajout d'une requête au batch a donc un coût compute marginal (calcul d'une colonne de Q supplémentaire). Le throughput scale presque linéairement avec le batch size, jusqu'à saturation mémoire (KV cache total).

Gain typique vs static batching : **5x à 20x** sur le throughput.

## PagedAttention

PagedAttention rend ce schéma viable. Sans pages, ajouter et retirer dynamiquement des requêtes du batch créerait une fragmentation catastrophique. Avec pages :

- Chaque séquence est une liste de pointers vers des pages KV.
- Allocation et désallocation atomiques au niveau page.
- Sharing trivial entre séquences (plusieurs pointers vers la même page).

> [!example] Intuition — virtual memory pour le KV cache
> PagedAttention applique au KV cache le principe de pagination d'un OS. Avant : allocation contiguë au `max_seq_len` → fragmentation interne (jusqu'à 80% inutilisé). Après : le KV est découpé en pages de taille fixe (typiquement 16 tokens), chaque séquence détient une *page table* qui pointe vers ses pages. Deux conséquences : zéro fragmentation, et le **prefix sharing** devient trivial — deux séquences avec le même préfixe pointent vers les mêmes pages physiques.

C'est l'innovation centrale de vLLM. Avant vLLM (2023), les implémentations équivalentes étaient hand-rolled et fragiles. Détails sur la gestion mémoire : [[02-inference/08-kv-cache-management]].

## Leviers de throughput

| Levier | Gain typique | Coût |
|---|---|---|
| Continuous batching | 5-20x | Implémentation complexe (vLLM le fournit) |
| Tensor parallelism (TP=2,4,8) | Permet plus gros modèle | Communication all-reduce |
| Pipeline parallelism (PP) | Permet modèle très volumineux | Bubble overhead, latency individuelle dégradée |
| KV cache quantization | 2-4x batch size max | Légère perte qualité |
| Speculative decoding | 1.5-3x throughput | Mémoire pour draft model |
| FlashAttention | 2-4x sur attention | Aucun (gain pur) |
| Chunked prefill | Mix prefill+decode dans le batch | Légère latency overhead |
| Disaggregated serving | TTFT et TPOT optimisés séparément | Infrastructure plus complexe |

## Métriques de throughput

- **Requests/sec** : nombre de requêtes complètes par seconde.
- **Tokens/sec output** : nombre de tokens générés par seconde, agrégé sur tous les users.
- **Goodput** : tokens générés qui respectent les SLAs (filtre les requêtes ayant dépassé TTFT/TPOT cible). Concept récent et important.
- **GPU utilization** : MFU (Model FLOPs Utilization). En decode, on est souvent à 30-40% MFU même bien tuné — comportement normal en régime memory-bound.

## Trade-off latency vs throughput

Augmenter le batch size : throughput en hausse, mais TPOT également (plus de tokens à compute par step). Le point d'opération dépend du workload. SLAs strictes (chat interactif) : batch size plus petit. Batch jobs (génération offline) : batch size élevé. Voir [[06-meta/28-tradeoffs]].

## Vocabulaire clé

`continuous batching`, `iteration-level scheduling`, `in-flight batching`, `static batching`, `PagedAttention`, `page table`, `prefix sharing`, `goodput`, `MFU`, `chunked prefill`.

## Synthèse

Le continuous batching est un scheduling iteration-level : à chaque step de génération, le scheduler ajoute les nouvelles requêtes au batch et retire celles qui ont fini, au lieu d'attendre que tout le batch termine. C'est essentiel parce que le decode est memory-bound — l'ajout d'une requête au batch est quasi-gratuit en compute. Gain 5-20x sur le throughput vs static batching. PagedAttention rend ce schéma viable : KV cache stocké en pages de taille fixe, allocation atomique au niveau page, fragmentation nulle et sharing trivial entre requêtes. C'est l'innovation centrale de vLLM. Combiné à tensor parallelism, FlashAttention et speculative decoding, on atteint l'essentiel du throughput potentiel d'un serving stack moderne.
