---
title: "02. Position encodings et long context"
description: "RoPE, ALiBi, YaRN, sliding window : comment un Transformer encode et étend la notion de position."
tags:
  - architecture
aliases:
  - 24-position-encodings
  - 02-position-encodings
---

> [!tip] Notes liées
> [[01-architecture/01-transformer-architecture]] · [[02-inference/08-kv-cache-management]] · [[03-applied/14-context-engineering]] · [[01-architecture/03-flash-attention]]

## Pourquoi encoder la position

L'opération de self-attention est **permutation-invariante** : sans information de position, le modèle ne peut pas distinguer "le chat mange la souris" de "la souris mange le chat". Un mécanisme d'encodage de position est donc nécessaire.

> [!example] Intuition
> Sans signal de position, le Transformer dégénère en **bag-of-tokens** : la sortie pour `[A, B, C]` est identique à celle pour `[C, B, A]`. Tout schéma d'encodage existe pour réinjecter cet ordre, soit dans les embeddings d'entrée (absolu), soit directement dans le calcul d'attention (RoPE, ALiBi).

## Les approches

### Sinusoidal (Transformer original)

Vecteurs sinusoïdaux de fréquences variables ajoutés aux embeddings. N'est plus utilisé en LLM moderne.

### Learned absolute

Vecteurs appris pour chaque position absolue (GPT-2, BERT). Limite : pas de généralisation au-delà de la longueur vue à l'entraînement.

### ALiBi (Attention with Linear Biases)

Ajoute un **biais linéaire négatif** aux attention scores en fonction de la distance entre tokens. Pas d'embeddings de position ; le biais est ajouté directement dans le calcul d'attention.

- Avantage : extrapolation à des contextes plus longs que l'entraînement (le biais reste défini).
- Adopté notamment par BLOOM, MPT.
- Plus utilisé en LLM cutting-edge depuis RoPE.

### RoPE (Rotary Position Embedding)

**Le standard moderne** (Llama, Mistral, Mixtral, DeepSeek, Qwen).

**Idée** : appliquer une **rotation** dans le plan complexe aux vecteurs Q et K en fonction de leur position. Le produit scalaire `Q · K^T` devient ainsi sensible à la **distance relative** entre tokens.

```
RoPE(x, m) = rotate(x, θ_i × m)
```

avec `θ_i = base^(-2i/d)` pour la dimension i, et `m` la position du token. `base` typiquement 10000.

Propriétés :
- Encode la position **relative** (la distance entre deux tokens).
- Pas de paramètres appris.
- Calcul direct sur Q et K avant le dot-product, pas d'addition aux embeddings.

> [!example] Intuition — pourquoi « rotation »
> Q et K sont traités comme des paires de coordonnées dans le plan complexe ; RoPE leur applique une rotation d'angle `θ · m` où `m` est la position. Le produit scalaire `Q · K^T` devient alors une fonction du **décalage angulaire** entre positions, donc de la distance relative — la position absolue n'apparaît jamais dans le résultat final.

### NoPE (No Positional Encoding)

Certains travaux récents (Kazemnejad et al. 2023) montrent que des Transformers decoder-only **sans aucun encodage de position** peuvent atteindre des performances compétitives, le masque causal suffisant à induire un biais positionnel implicite. Encore expérimental.

## Long context et RoPE scaling

Le problème : un modèle entraîné avec un context window de 4k tokens dégrade fortement au-delà. RoPE étant définie par `θ_i`, étendre le contexte sans réentraînement nécessite de **rescaler** les fréquences.

### Linear interpolation (Position Interpolation, PI)

(Chen et al. 2023.) Diviser les positions par un facteur `s`. Si le modèle a été entraîné sur 4k et qu'on vise 16k, `s=4`. Marche mais dégrade légèrement la résolution sur les positions proches.

### NTK-aware scaling

Plutôt que d'interpoler uniformément toutes les fréquences, on modifie `base` pour préserver les hautes fréquences (qui encodent la position locale) et compresser les basses fréquences (qui encodent la distance globale).

- Meilleure préservation de la qualité sans fine-tuning.
- Popularisé par la communauté open-source en 2023.

### YaRN (Yet another RoPE extensioN)

(Peng et al. 2023.) Combinaison de NTK-aware scaling avec une attention temperature scaling pour compenser la dégradation du softmax sur de long contextes. Permet d'étendre le contexte par un facteur 4-8x avec un fine-tuning minimal.

Adopté notamment par les variantes long-context de Llama et Mistral.

## Sliding window attention

Approche alternative : restreindre l'attention de chaque token aux **W tokens précédents** au lieu de toute la séquence. Le KV cache est borné par `W` indépendamment de la longueur du contexte.

- **Mistral 7B** : sliding window de 4096 tokens. Combiné à des layers profondes, l'information se propage au-delà de la fenêtre.
- Avantage : KV cache borné.
- Limite : perte de l'attention exacte à longue portée.

## Architectures non-Transformer pour long context

### Mamba (State Space Models)

Architecture basée sur des state space models (SSM) avec un mécanisme de sélection. Complexité linéaire en longueur de séquence (vs quadratique pour Transformer). Compétitif avec Transformer sur certains benchmarks.

### RWKV

Hybride RNN/Transformer. Inference linéaire en longueur, parallélisme au training. Communauté open-source active.

Ces architectures restent minoritaires en production cutting-edge, mais constituent le pôle de recherche principal sur les alternatives au Transformer.

## Needle-in-haystack vs reasoning

Un point critique : un modèle peut **retrouver** une information dans 1M tokens (needle test) sans pour autant pouvoir **raisonner** dessus. Voir [[03-applied/14-context-engineering]]. RoPE scaling et long context améliorent surtout le retrieval, moins le reasoning.

## Vocabulaire clé

`positional encoding`, `sinusoidal`, `learned position`, `ALiBi`, `RoPE` (Rotary Position Embedding), `NoPE`, `position interpolation` (PI), `NTK-aware scaling`, `YaRN`, `sliding window attention`, `Mamba`, `state space model` (SSM), `RWKV`, `linear attention`.

## Synthèse

Self-attention est permutation-invariante, d'où la nécessité d'encoder la position. RoPE est le standard moderne : rotation appliquée à Q et K en fonction de la position, ce qui rend l'attention sensible à la distance relative. Pour étendre le contexte sans réentraîner, plusieurs schémas de scaling : Position Interpolation, NTK-aware, et YaRN (le plus utilisé). ALiBi est une approche alternative via biais linéaire négatif. Sliding window attention borne le KV cache à la fenêtre — adoptée par Mistral 7B. Pour le très long contexte, des architectures non-Transformer comme Mamba et RWKV offrent une complexité linéaire. Distinction critique : un long context window n'implique pas un long reasoning ; needle-in-haystack ≠ reasoning over haystack.
