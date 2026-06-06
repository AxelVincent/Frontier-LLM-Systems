---
title: "09. Prefill vs decode latency"
description: "Compute-bound vs memory-bound : les deux régimes de l'inference et leurs métriques (TTFT, TPOT)."
tags:
  - inference
aliases:
  - 05-prefill-vs-decode
  - 09-prefill-vs-decode
---

> [!tip] Notes liées
> [[02-inference/08-kv-cache-management]] · [[02-inference/10-continuous-batching-paged-attention]] · [[02-inference/11-speculative-quant-distill]] · [[03-applied/14-context-engineering]]

## Les deux phases de l'inference

**Prefill** : le prompt complet (N tokens) est traité en parallèle sur le GPU pour calculer K, V, et la première forward pass produisant le premier token de sortie. Régime **compute-bound** : le bottleneck est la puissance de calcul (TFLOPS).

**Decode** : à chaque step, un seul token est généré. Une seule colonne de Q est calculée mais l'intégralité du [[02-inference/08-kv-cache-management|KV cache]] doit être relue (n_layers × n_heads × head_dim × seq_len). Régime **memory-bound** : le bottleneck est la bande passante mémoire (GB/s).

> [!example] Intuition — deux régimes hardware distincts
> Les deux phases sollicitent le GPU différemment :
> - **Prefill** traite N tokens en parallèle ; le ratio compute/memory est élevé, on sature les Tensor Cores → *compute-bound*. La métrique pertinente est `TTFT`.
> - **Decode** traite 1 token mais relit l'intégralité du [[02-inference/08-kv-cache-management|KV cache]] à chaque step ; le ratio compute/memory s'effondre, le bottleneck devient la bande passante [[02-inference/08-kv-cache-management|HBM]] → *memory-bound*. La métrique pertinente est `TPOT`.
>
> Conséquence : les leviers d'optimisation diffèrent ([[01-architecture/03-flash-attention|FlashAttention]], [[01-architecture/06-distributed-training|TP]] pour prefill ; [[02-inference/10-continuous-batching-paged-attention|continuous batching]], [[02-inference/11-speculative-quant-distill|speculative decoding]], [[02-inference/12-quantization-deep-dive|quantization]] pour decode), et la latence end-to-end est `TTFT + N_output × TPOT`.

## Pourquoi les deux phases s'optimisent différemment

| Aspect | Prefill | Decode |
|---|---|---|
| Bound | Compute (TFLOPS) | Memory bandwidth (GB/s) |
| Parallelism | N tokens en parallèle | 1 token à la fois |
| Métrique clé | TTFT (Time To First Token) | TPOT (Time Per Output Token), inter-token latency |
| Optimisations | [[01-architecture/03-flash-attention|FlashAttention]], [[01-architecture/06-distributed-training|Tensor Parallelism]], gros batch | [[02-inference/10-continuous-batching-paged-attention|Continuous batching]], [[02-inference/11-speculative-quant-distill|speculative decoding]], [[02-inference/12-quantization-deep-dive|quantization]] |
| Hardware utilization | GPU saturé à ~100% facilement | 30-40% utilization typique, memory-bound |

## Conséquences pratiques

**Latency budget = TTFT + N_output × TPOT.**

- UX chat : TTFT < 500 ms idéal, TPOT < 50 ms (≈20 tok/s, vitesse de lecture confortable).
- Agent appelant un tool : TTFT peu critique si la réponse est courte (10-50 tokens). TPOT prioritaire.
- Génération longue (résumé d'un document) : TPOT domine la latence totale.

**Tactiques différenciées** :

- TTFT trop lent → réduction du prompt ([[03-applied/14-context-engineering]]), [[03-applied/15-prompt-vs-semantic-caching|prompt caching]] ([[03-applied/15-prompt-vs-semantic-caching]]), tensor parallelism, FlashAttention, hardware H100 plutôt que A100.
- TPOT trop lent → continuous batching avec batch plus large (decode étant memory-bound, l'ajout d'une requête est quasi-gratuit), speculative decoding (1.5-3x sans perte qualité, voir [[02-inference/11-speculative-quant-distill]]), quantization du modèle ou du KV cache ([[02-inference/12-quantization-deep-dive]]), [[01-architecture/05-mixture-of-experts|MoE]] pour réduire les paramètres actifs.

## Streaming

Le streaming SSE consiste à émettre chaque token dès qu'il est décodé. La latence perçue par l'utilisateur dépend de deux grandeurs : TTFT (pour signaler le démarrage) et TPOT (pour la vitesse de lecture). User-perceived latency ≠ total latency.

## Trade-off prefill vs decode au niveau system design

- Système servant beaucoup de prompts courts avec génération courte (classification, function calling) → prefill dominant → optimiser TTFT et throughput requests/sec.
- Système servant peu de prompts longs avec génération longue (résumé d'un document de plusieurs pages) → decode dominant → optimiser tokens/sec.

C'est ce qui motive les approches de **chunked prefill** et de **disaggregated serving** (séparation prefill / decode sur des GPUs distincts, adoptée notamment par DeepSeek-V3) dans les serving stacks récents.

## Vocabulaire clé

`prefill`, `decode`, `TTFT` (Time To First Token), `TPOT` (Time Per Output Token), `inter-token latency`, `compute-bound`, `memory-bound`, `arithmetic intensity`, `disaggregated serving`, `chunked prefill`.

## Synthèse

L'inference a deux phases distinctes. Prefill traite tout le prompt en parallèle, donc régime compute-bound — le GPU est saturé en TFLOPS. Decode génère un token à la fois avec une colonne de Q mais doit relire l'intégralité du KV cache à chaque step, donc régime memory-bound — bottleneck = bande passante HBM. Les optimisations diffèrent. Prefill bénéficie de tensor parallelism et FlashAttention. Decode bénéficie de continuous batching — étant memory-bound, l'ajout d'une requête au batch est quasi-gratuit en compute — et de speculative decoding. Sur la latence perçue, TTFT correspond au prefill, TPOT au decode. La priorisation dépend du workload.
