---
title: "08. KV cache management à grande échelle"
description: "Pourquoi le KV cache existe, comment il est dimensionné, et comment vLLM gère pages et eviction."
tags:
  - inference
aliases:
  - 04-kv-cache-management
  - 08-kv-cache-management
---

> [!info] Prérequis
> [[01-architecture/01-transformer-architecture|01. Transformer]] (self-attention, K/V, GQA) — la formule du KV cache s'appuie directement sur ces concepts.

> [!tip] Notes liées
> [[02-inference/09-prefill-vs-decode]] · [[02-inference/10-continuous-batching-paged-attention]] · [[02-inference/12-quantization-deep-dive]] · [[03-applied/15-prompt-vs-semantic-caching]]

## Rappel : qu'est-ce que le KV cache

Pendant la génération autoregressive, chaque step calcule l'attention. L'attention requiert les K (keys) et V (values) de tous les tokens précédents. Sans cache, ces matrices sont recalculées à chaque step → O(n²) en compute par token. Avec KV cache, les K et V des tokens passés sont conservées en mémoire → O(n) par token. C'est l'optimisation qui rend l'inference autoregressive viable.

> [!example] Intuition
> Le KV cache est une forme de **memoization au niveau token**. Pendant la génération autoregressive, K et V des positions passées ne changent jamais — les recalculer à chaque step donnerait du O(n²) en compute par token. Le cache les conserve en VRAM et ramène le coût à O(n). Le prix est mémoire : taille linéaire en `seq_len × batch_size`, ce qui en fait la ressource scarce du serving à scale.

## Formule canonique

```
KV cache size = 2 × n_layers × n_heads_kv × head_dim × seq_len × batch_size × bytes_per_dtype
```

- Le `2` représente K et V stockés séparément.
- `n_heads_kv` est déterminant : avec **GQA** (Grouped Query Attention) ou **MQA** (Multi-Query Attention), le nombre de heads pour K/V est inférieur au nombre de heads pour Q. Mistral 7B utilise GQA avec 8 KV heads (vs 32 Q heads) → KV cache divisé par 4.
- `bytes_per_dtype` : 2 pour [[02-inference/12-quantization-deep-dive|FP16]]/[[02-inference/12-quantization-deep-dive|BF16]], 1 pour [[02-inference/12-quantization-deep-dive|FP8]]/INT8.

## Exemple chiffré

Llama 70B en BF16, batch_size=1, seq_len=4096 :

- n_layers = 80, n_heads_kv = 8 (GQA), head_dim = 128, bytes = 2
- KV cache = 2 × 80 × 8 × 128 × 4096 × 1 × 2 = **1.34 GB**

Pour Llama 70B en [[01-architecture/01-transformer-architecture|MHA]] (sans GQA) : facteur 8 supplémentaire (64 vs 8 KV heads) → **10.7 GB**. C'est ce qui motive l'adoption généralisée de GQA.

## Problèmes à grande échelle

Servir N utilisateurs en parallèle, chacun avec une séquence de longueur variable, implique N KV caches actifs en VRAM. La VRAM est la ressource scarce. Sans optimisation :

- **Fragmentation** : allocation par max_seq_len → 80% de gaspillage typique.
- **Eviction** : un utilisateur idle voit son cache évincé pour libérer la place. Le restaurer coûte un prefill complet.
- **Memory pressure** : un OOM entraîne un crash serveur et la perte de toutes les sessions.

## Techniques de management

**1. PagedAttention ([[02-inference/10-continuous-batching-paged-attention|vLLM]], le canonique)** — voir [[02-inference/10-continuous-batching-paged-attention]]
- KV cache stocké en **pages** de taille fixe (typiquement 16 tokens).
- Une page table mappe chaque séquence à ses pages.
- Bénéfice : fragmentation nulle, sharing trivial entre séquences qui partagent un prefix (mécanisme de prompt caching naturel).

**2. Prefix sharing / radix tree**
- vLLM (et SGLang de manière plus agressive) maintient un radix tree des prefixes vus.
- Deux requêtes partageant un prefix partagent leurs pages KV en mémoire.
- Critique pour les agents qui réutilisent un même system prompt + tool defs.

**3. Eviction policies**
- **LRU** par défaut : la séquence inactive depuis le plus longtemps est évincée.
- Variantes sophistiquées : tenant-aware (conservation des VIP en cache), priorité par SLA.

**4. Offloading**
- Migration sur CPU RAM ou disque NVMe quand la VRAM est saturée.
- Trade-off : économie de mémoire mais re-load coûteux (PCIe bandwidth).
- Implémentations : DeepSpeed-Inference, KTransformers.

**5. KV cache quantization** — voir [[02-inference/12-quantization-deep-dive]]
- KV stocké en INT8 ou INT4. Réduction de la taille par 2-4.
- Risque qualité variable selon le modèle, généralement gérable en INT8.

**6. Cache compression**
- Techniques comme H2O (Heavy Hitter Oracle) ou StreamingLLM (sink tokens + recent window) : éviction dynamique des tokens peu attendus.
- Encore expérimental en production sérieuse.

**7. Multi-tier cache**
- L1 : HBM (VRAM GPU).
- L2 : CPU RAM (DRAM).
- L3 : NVMe.
- L4 : object storage.
- [[03-applied/15-prompt-vs-semantic-caching|TTL]] et migration entre tiers selon access pattern.

## Memory pressure : signaux et réponses

- **Signaux** : utilization VRAM > 90%, OOM kills, queueing latency en hausse.
- **Réponses graduelles** :
  1. Réduction du batch size maximal.
  2. Eviction plus agressive (TTL plus court).
  3. Troncature des contextes longs (sliding window).
  4. Refus des requêtes longues ([[03-applied/19-model-routing-fallback|429]] ou file d'attente).
  5. Scale horizontal (latence d'application non négligeable).

## Vocabulaire clé

`KV cache`, `PagedAttention`, `page table`, `prefix sharing`, `radix tree`, `LRU eviction`, `KV cache quantization`, `offloading`, `HBM`, `VRAM`, `fragmentation`, `block size`.

## Synthèse

Le KV cache stocke les K et V de tous les tokens passés en VRAM pour éviter leur recomputation à chaque step de génération. La formule canonique est `2 × n_layers × n_heads_kv × head_dim × seq_len × batch_size × bytes`. À grande échelle, les problèmes principaux sont la fragmentation et la pression mémoire. La solution canonique est PagedAttention dans vLLM : KV cache stocké en pages de taille fixe avec page table, ce qui élimine la fragmentation et permet le prefix sharing — deux séquences partageant un system prompt partagent leurs pages KV. Eviction LRU par défaut, quantization INT8 du cache en cas de forte contrainte, et offloading CPU RAM en dernier recours.

## Cas d'étude : Mistral 7B

Mistral 7B combine **GQA avec 8 KV heads** et **sliding window attention** (4096 tokens). Le KV cache est ainsi borné en taille indépendamment de la longueur du contexte logique — une propriété recherchée pour l'inference efficace.
