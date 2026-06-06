---
title: "03. FlashAttention"
description: "Tiling, online softmax, IO-awareness : pourquoi FlashAttention accélère l'attention sans changer le résultat."
tags:
  - architecture
aliases:
  - 25-flash-attention
  - 03-flash-attention
---

> [!tip] Notes liées
> [[01-architecture/01-transformer-architecture]] · [[02-inference/09-prefill-vs-decode]] · [[02-inference/10-continuous-batching-paged-attention]] · [[02-inference/08-kv-cache-management]]

## Le problème

L'attention naïve est implémentée en trois étapes :
1. `S = Q · K^T` — matrice (N × N).
2. `P = softmax(S)` — matrice (N × N).
3. `O = P · V` — matrice (N × d).

Le problème : les matrices `S` et `P` sont de taille `N²`. Pour `N = 8192` (un context long), `S` fait 67M d'éléments. Elle doit être **matérialisée en HBM** (high bandwidth memory) du GPU, alors que l'attention est mathématiquement décomposable. Le bottleneck devient le **memory I/O** entre HBM et SRAM (la mémoire on-chip rapide), pas le compute.

> [!example] Intuition — hiérarchie mémoire GPU
> Même logique que la hiérarchie L1/L2/DRAM d'un CPU. La **HBM** est la DRAM du GPU : large (~80 GB sur H100) mais ~1.5 TB/s. La **SRAM** est le cache on-chip : ~200 KB par streaming multiprocessor mais ~10× plus rapide. L'attention naïve est *[[02-inference/09-prefill-vs-decode|memory-bound]]* parce qu'elle matérialise la matrice `N × N` en HBM. FlashAttention garde les fragments en SRAM le temps du calcul et ne réécrit en HBM que la sortie compacte.

## FlashAttention v1 (Dao et al. 2022)

**Innovation principale** : calculer l'attention en **tiling** sur Q et K, en utilisant l'**online softmax** pour ne jamais matérialiser la matrice complète `S` en HBM.

### Mécanisme

- Q est découpé en blocs `Q_i` de taille `B_r × d`.
- K et V sont découpés en blocs `K_j, V_j` de taille `B_c × d`.
- Pour chaque bloc `Q_i`, on itère sur tous les blocs `K_j, V_j`.
- À chaque itération :
  1. Calculer `S_ij = Q_i · K_j^T` en SRAM.
  2. Calculer `P_ij = softmax(S_ij)` en SRAM, en maintenant les statistiques (max et somme) pour la **renormalisation** du softmax global.
  3. Accumuler `O_i += P_ij · V_j` en SRAM, avec renormalisation.
- Une fois toutes les itérations terminées, `O_i` est écrit en HBM.

### Online softmax

Le [[01-architecture/01-transformer-architecture|softmax]] est numériquement stable lorsqu'on soustrait le max avant l'exponentielle. En tiling, on ne connaît pas le max global avant la fin. L'online softmax maintient un running max `m` et une running sum `l`, mis à jour à chaque bloc, et **renormalise** rétroactivement les contributions précédentes lorsqu'un nouveau max est rencontré.

### Bénéfices

- Mémoire : `O(N · d)` au lieu de `O(N²)`. Permet d'attaquer des contextes très longs.
- Throughput : 2-4x plus rapide que l'attention naïve sur des contextes moyens, davantage sur les longs.
- **Exact** : pas une approximation, le résultat est identique à l'attention naïve.

## FlashAttention v2 (Dao 2023)

Optimisations sur la parallélisation et la réduction des opérations non-matmul :

- Meilleure parallélisation entre warps (sub-groupes de threads sur GPU).
- Permutation des boucles pour réduire la pression sur les registres.
- Gain typique : 2x supplémentaire vs v1.

## FlashAttention v3 (Shah et al. 2024)

Spécifique au hardware Hopper (H100). Exploite :
- Les nouveaux instruction sets matmul de Hopper (WGMMA).
- L'asynchronie compute/data movement (TMA — Tensor Memory Accelerator).
- Le format [[02-inference/12-quantization-deep-dive|FP8]] hardware-accelerated.

Gain typique : 1.5-2x supplémentaire vs v2 sur H100.

## Backward pass

Le backward pass naïf nécessiterait de matérialiser la matrice `P` pour le gradient. FlashAttention utilise la **recomputation** : on stocke seulement `O` et les statistiques softmax, puis on recalcule `P` en SRAM lors du backward. Trade-off : un peu plus de compute mais beaucoup moins de mémoire.

## Intégration en pratique

- **PyTorch** : `scaled_dot_product_attention` utilise FlashAttention automatiquement quand les conditions sont réunies (depuis PyTorch 2.0).
- **[[02-inference/10-continuous-batching-paged-attention|vLLM]], TensorRT-LLM, SGLang** : intégration native pour le serving.
- **Triton** : implémentations alternatives en kernel custom, parfois utilisées pour des variantes (sliding window, ALiBi).
- **xFormers** : librairie qui expose des memory-efficient attention kernels variés.

## Variantes et extensions

- **FlashAttention avec [[01-architecture/02-position-encodings|sliding window]]** : tiling adapté pour ne considérer que les K_j dans la fenêtre.
- **FlashAttention avec [[01-architecture/02-position-encodings|ALiBi]]** : intégration du biais linéaire dans le kernel.
- **FlashDecoding** : variante optimisée pour la phase de [[02-inference/09-prefill-vs-decode|decode]] (un seul query token, beaucoup de KV). Réorganise la parallélisation pour saturer le GPU même avec N_q = 1.

## Vocabulaire clé

`FlashAttention`, `tiling`, `online softmax`, `running max`, `running sum`, `renormalization`, `memory I/O`, `HBM`, `SRAM`, `recomputation`, `WGMMA`, `TMA`, `FlashDecoding`, `xFormers`, `scaled dot-product attention`.

## Synthèse

FlashAttention calcule l'attention exact en tiling sur Q et K, en utilisant l'online softmax pour ne jamais matérialiser la matrice attention `N × N` en HBM. Le bottleneck de l'attention naïve étant le memory I/O entre HBM et SRAM, l'évitement de cette matérialisation produit un gain de 2-4x sur le throughput et une mémoire en `O(N · d)` au lieu de `O(N²)`. Le résultat est exact, pas une approximation. v2 optimise la parallélisation, v3 exploite le hardware H100 et FP8. Le backward pass utilise la recomputation pour conserver l'efficacité mémoire. Intégré nativement dans PyTorch 2.0, vLLM, TensorRT-LLM. Des variantes existent pour sliding window, ALiBi, et FlashDecoding pour la phase de decode.
