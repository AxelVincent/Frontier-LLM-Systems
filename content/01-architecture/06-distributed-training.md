---
title: "06. Distributed training"
description: "DP, ZeRO, FSDP, TP, PP, EP, mixed precision : les axes de parallelisme pour entraîner un LLM frontier."
tags:
  - architecture
aliases:
  - 28-distributed-training
  - 06-distributed-training
---

> [!tip] Notes liées
> [[01-architecture/05-mixture-of-experts]] · [[02-inference/12-quantization-deep-dive]] · [[01-architecture/01-transformer-architecture]] · [[02-inference/08-kv-cache-management]]

## Le problème

Un modèle de 70B paramètres en BF16 occupe ≈140 GB. Les optimisateurs (Adam) requièrent typiquement **3 copies supplémentaires** par paramètre : gradient, moment d'ordre 1, moment d'ordre 2 — soit ≈560 GB de plus. Un seul GPU H100 (80 GB) ne peut pas accueillir un tel modèle en training. Le distributed training devient nécessaire.

Trois axes orthogonaux peuvent être combinés : **data parallelism**, **model parallelism**, **pipeline parallelism**.

> [!example] Intuition — trois axes de partitionnement
> Chaque axe partitionne une dimension différente du training :
> - **Data parallelism** partitionne le *batch*. Le modèle est répliqué, les gradients sont agrégés par all-reduce. Mémoire ∝ taille modèle × N replicas.
> - **Tensor parallelism** partitionne les *matrices de poids* à l'intérieur d'un layer. Économe en mémoire, mais chaque MatMul requiert une communication collective — viable seulement sur NVLink intra-nœud.
> - **Pipeline parallelism** partitionne la *profondeur* (layers). Le coût est la *bubble* : tant que le pipeline n'est pas rempli, des GPUs sont idle. Mitigation : micro-batches.

## Data Parallelism (DP)

Chaque GPU possède une **copie complète** du modèle, mais traite un **sous-batch** différent des données. Les gradients sont **agrégés** via all-reduce après le backward pass.

### DDP (Distributed Data Parallel)

L'implémentation standard en PyTorch. Communication all-reduce des gradients à chaque backward.

- Avantage : simple, scale linéairement avec le nombre de GPUs.
- Limite : la mémoire requise est celle du modèle complet × N copies. Inadapté aux gros modèles.

### ZeRO (Zero Redundancy Optimizer)

Introduit par DeepSpeed (Rajbhandari et al. 2020). Élimine la redondance de l'état d'optimisation et des gradients en les **shardant** entre GPUs.

- **ZeRO-1** : optimizer states sharded.
- **ZeRO-2** : optimizer states + gradients sharded.
- **ZeRO-3** : optimizer states + gradients + **weights** sharded. Chaque GPU possède 1/N du modèle ; les weights sont temporairement gather lors du forward/backward.

Mémoire par GPU : ZeRO-3 réduit de N × M à ~M/N + overhead, où M est la mémoire d'un modèle complet.

Coût : communication accrue (gather des weights à chaque forward et backward).

### FSDP (Fully Sharded Data Parallel)

Implémentation native de PyTorch équivalente à ZeRO-3. Plus intégrée dans l'écosystème PyTorch. Standard moderne.

## Tensor Parallelism (TP)

Split horizontal : chaque GPU possède une **portion d'un même tensor** (typiquement une matrice de weights).

Pour un MatMul `Y = X · W` :
- Split W en colonnes : chaque GPU calcule une portion de Y. Concaténation à la fin.
- Split W en lignes : il faut splitter X en colonnes, chaque GPU produit une contribution partielle de Y, et un all-reduce somme les contributions.

### Megatron-LM

Le pattern canonique (Shoeybi et al. 2019) :
- Dans le bloc attention : split column-parallel sur les Q/K/V, puis row-parallel sur la projection finale. Un seul all-reduce par bloc.
- Dans le FFN : column-parallel sur W_1, row-parallel sur W_2.

TP fonctionne bien jusqu'à TP=8 (un nœud single-GPU avec NVLink). Au-delà, la communication inter-nœuds dégrade fortement.

## Pipeline Parallelism (PP)

Split vertical : les **layers** du modèle sont répartis entre GPUs. Le GPU 0 contient les layers 0-9, le GPU 1 les layers 10-19, etc. Les activations sont transmises de GPU à GPU.

### Bubble

Le problème central : si chaque GPU attend la fin du forward complet pour démarrer le backward, les GPUs sont **idle** la plupart du temps. C'est le **pipeline bubble**.

### Micro-batches

Solution (GPipe, PipeDream) : découper un batch en **micro-batches** qui s'enchaînent dans le pipeline. Pendant que le GPU 0 traite le micro-batch 2 en forward, le GPU 1 traite le micro-batch 1, etc. La bubble est réduite à `(P - 1) / (P + M - 1)` où P = nombre de stages et M = nombre de micro-batches.

### Schedules

- **GPipe** : tous les forwards d'abord, puis tous les backwards.
- **PipeDream / 1F1B** : alterner forward et backward pour réduire la mémoire d'activation.
- **Interleaved 1F1B** : assigner plusieurs portions de layers non-contiguës à chaque GPU pour réduire encore la bubble.

## Context / Sequence Parallelism

Pour les très long contextes (32k+ tokens), le calcul d'attention sur une séquence complète ne tient plus sur un seul GPU. Le **context parallelism** (alias **sequence parallelism**) split la **dimension séquence** entre GPUs.

- Ring Attention (Liu et al. 2023) : chaque GPU traite une portion de la séquence, et les K, V circulent en anneau entre GPUs.
- Permet d'entraîner sur des contextes de 1M tokens et plus.

## Combinaisons : 3D / 4D parallelism

En production, les trois (ou quatre) axes sont combinés. Un modèle de 175B+ peut être entraîné avec :

- DP × TP × PP × CP.
- Exemple Megatron-DeepSpeed : `DP=8 × TP=8 × PP=16 × CP=2 = 2048 GPUs`.

Le choix dépend du trade-off entre communication intra-nœud (rapide, NVLink) et inter-nœud (plus lent, InfiniBand).

## Expert Parallelism (pour MoE)

Spécifique à MoE (voir [[01-architecture/05-mixture-of-experts]]). Les experts sont distribués entre GPUs. Chaque token est routé via communication **all-to-all** vers le GPU hébergeant son expert. Le all-to-all est l'opération critique, à optimiser pour ne pas devenir un bottleneck.

## Mixed precision

Le training en pure FP32 est inutilement coûteux. Le mixed precision combine plusieurs précisions :

- **FP16** : 16-bit float standard. Range étroite, overflow possible. Nécessite **loss scaling** pour éviter le underflow dans le gradient.
- **BF16** (Brain Float 16) : 16-bit float avec même range que FP32. Pas de loss scaling nécessaire. Standard moderne sur Ampere+.
- **FP8** : 8-bit float, hardware-accelerated sur Hopper (H100). DeepSeek-V3 a fait son training en FP8.

### AMP (Automatic Mixed Precision)

API PyTorch (`torch.cuda.amp`) qui sélectionne automatiquement la précision par opération : matmul en FP16/BF16, reductions et accumulators en FP32.

### Loss scaling

En FP16, les gradients peuvent underflow (devenir 0). On multiplie la loss par un facteur (typiquement 2^15) avant le backward, puis on divise les gradients par le même facteur avant l'update. Évite l'underflow sans modifier le résultat.

Non nécessaire en BF16 (range suffisante).

## Vocabulaire clé

`data parallelism` (DP), `DDP` (Distributed Data Parallel), `ZeRO` (Zero Redundancy Optimizer), `ZeRO-1`, `ZeRO-2`, `ZeRO-3`, `FSDP` (Fully Sharded Data Parallel), `tensor parallelism` (TP), `Megatron`, `pipeline parallelism` (PP), `bubble`, `micro-batch`, `GPipe`, `1F1B`, `interleaved 1F1B`, `context parallelism`, `sequence parallelism`, `ring attention`, `expert parallelism`, `all-reduce`, `all-to-all`, `mixed precision`, `FP16`, `BF16`, `FP8`, `AMP`, `loss scaling`.

## Synthèse

Le distributed training combine trois axes orthogonaux. Data parallelism (DDP) duplique le modèle et partitionne les données ; ZeRO et FSDP shardent en plus les optimizer states (ZeRO-1), gradients (ZeRO-2), et weights (ZeRO-3) pour réduire la mémoire par GPU. Tensor parallelism (Megatron) split horizontalement les matrices de weights ; performant jusqu'à TP=8 dans un nœud NVLink. Pipeline parallelism distribue les layers entre GPUs, avec des micro-batches pour réduire le pipeline bubble. Context parallelism (Ring Attention) split la dimension séquence pour les très long contextes. Expert parallelism distribue les experts MoE avec communication all-to-all. En production, on combine 3D ou 4D parallelism. Mixed precision : BF16 standard, FP8 sur H100. AMP automatise la sélection ; loss scaling est nécessaire en FP16 mais pas en BF16.
