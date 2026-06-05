---
title: "01. Architecture Transformer"
description: "Self-attention, MHA/MQA/GQA, MLA, FFN, RMSNorm, residual stream — la pièce centrale d'un LLM decoder-only."
tags:
  - architecture
aliases:
  - 23-transformer-architecture
  - 01-transformer-architecture
---

> [!tip] Notes liées
> [[01-architecture/02-position-encodings]] · [[01-architecture/03-flash-attention]] · [[02-inference/08-kv-cache-management]] · [[01-architecture/05-mixture-of-experts]]

## Vue d'ensemble

Le Transformer (Vaswani et al. 2017) est l'architecture qui sous-tend l'ensemble des LLM modernes. Un LLM decoder-only se compose d'une stack de N blocs identiques, chacun contenant :

1. **Self-attention** (avec masque causal pour decoder-only).
2. **Feed-forward network (FFN / MLP)**.
3. **Layer normalization** appliquée avant chaque sous-bloc (pré-norm) ou après (post-norm).
4. **Residual connections** autour de chaque sous-bloc.

L'output passe ensuite par une projection finale (`lm_head`) sur le vocabulaire pour produire les logits.

## Self-attention

L'opération centrale. Pour chaque token, on calcule :

```
Q = X · W_Q
K = X · W_K
V = X · W_V
attn_scores = softmax(Q · K^T / sqrt(d_head))
output = attn_scores · V
```

- `Q` (queries), `K` (keys), `V` (values) sont des projections linéaires des hidden states.
- La division par `sqrt(d_head)` évite la saturation du softmax sur des grandes dimensions.
- **Masque causal** (decoder-only) : on masque les positions futures avant le softmax, pour que chaque token n'attende que sur les tokens précédents.

> [!example] Intuition — Q/K/V
> Self-attention est une **recherche par similarité différentiable**. Chaque token projette ses hidden states selon trois rôles : `K` indexe son contenu, `Q` formule ce qu'il cherche, `V` porte ce qu'il retournerait. Le produit `Q · K^T` calcule un score de pertinence par paire, le softmax le normalise en distribution de poids, et la sortie est la combinaison pondérée des `V`. Conceptuellement, c'est un *content-addressable lookup* — un hash table où le matching est continu.

### Multi-head attention (MHA)

L'attention est calculée en parallèle sur **plusieurs heads**, chacune avec ses propres `W_Q / W_K / W_V`. Les outputs sont concaténés puis projetés.

- `n_heads` typique : 32, 64, 96 selon la taille du modèle.
- `head_dim` typique : 64, 128.

Chaque head apprend un pattern d'attention distinct (positionnel, sémantique, syntaxique).

### MQA et GQA

L'innovation pour réduire la taille du **KV cache** (voir [[02-inference/08-kv-cache-management]]) :

- **MHA** (Multi-Head Attention) : `n_heads_kv = n_heads_q`. Standard original.
- **MQA** (Multi-Query Attention) : `n_heads_kv = 1`. Toutes les Q-heads partagent K et V. Très efficace mémoire, légère perte qualité.
- **GQA** (Grouped Query Attention) : `n_heads_kv = n_heads_q / G`. Compromis. G typiquement 4 ou 8. Standard moderne (Llama 2 70B, Mistral 7B, Llama 3).

Le KV cache est divisé par `n_heads_q / n_heads_kv`.

### MLA (Multi-head Latent Attention)

Introduit par DeepSeek-V2/V3. Au lieu de cacher K et V directement, on cache une **représentation latente compressée** qui est ensuite projetée vers K et V au moment du compute. Le KV cache devient considérablement plus petit, sans perte de qualité significative.

## Cross-attention

Présente uniquement dans les architectures **encoder-decoder** (T5, BART, modèles de traduction). Le decoder attend sur les hidden states de l'encoder via Q venant du decoder et K, V venant de l'encoder.

Les LLM decoder-only modernes (GPT, Llama, Mistral) n'utilisent pas de cross-attention.

## FFN / MLP

Le second sous-bloc de chaque layer. Une transformation non-linéaire appliquée indépendamment à chaque position :

```
FFN(x) = activation(x · W_1) · W_2
```

- `W_1` projette dans une dimension intermédiaire `d_ff` (typiquement 4 × d_model).
- `W_2` projette retour vers `d_model`.

### Activation : GELU vs SwiGLU

- **GELU** (Gaussian Error Linear Unit) : `x · Φ(x)`. Standard initial (GPT, BERT).
- **SwiGLU** (Swish-Gated Linear Unit) : `Swish(x · W_gate) ⊗ (x · W_up)`. Variante "gated" qui multiplie l'output par un gating signal. Standard moderne (Llama, Mistral, PaLM).

SwiGLU améliore légèrement la qualité au coût d'un troisième linear layer (donc plus de paramètres pour le même `d_ff`).

## Normalization

### LayerNorm

```
LN(x) = γ · (x - μ) / sqrt(σ² + ε) + β
```

Normalisation par feature pour chaque token. Deux paramètres appris (γ, β).

### RMSNorm

```
RMSNorm(x) = γ · x / sqrt(mean(x²) + ε)
```

Variante simplifiée : pas de centrage par la moyenne, pas de `β`. Légèrement plus rapide, qualité quasi-équivalente. Standard moderne (Llama, Mistral).

### Pré-norm vs post-norm

- **Post-norm** (Transformer original) : `x + Sublayer(x)` puis `LN`. Instable à grand profondeur.
- **Pré-norm** : `x + Sublayer(LN(x))`. Plus stable à l'entraînement, gradient mieux conditionné. Standard moderne.

## Residual stream

Le pattern `x = x + Sublayer(x)` crée un **residual stream** continu où chaque sublayer **ajoute** une contribution au hidden state. Cette structure additive a deux conséquences :

1. **Gradient flow** : les gradients atteignent les layers profonds via les skip connections, ce qui permet d'entraîner des stacks très profondes.
2. **Interpretability** : les contributions des heads et MLPs s'analysent comme des "écritures" successives dans le residual stream, fondement du domaine de mechanistic interpretability.

> [!example] Intuition — residual stream
> Le hidden state n'est jamais *remplacé*, seulement *additionné*. Chaque sublayer lit le state courant et y écrit un delta. Cette structure additive a deux propriétés : le gradient backpropage sans atténuation (skip connections), et les contributions de chaque head/MLP s'analysent en isolation — fondement de la mechanistic interpretability.

## Vocabulaire clé

`self-attention`, `multi-head attention` (MHA), `multi-query attention` (MQA), `grouped query attention` (GQA), `multi-head latent attention` (MLA), `cross-attention`, `causal mask`, `FFN`, `MLP`, `SwiGLU`, `GELU`, `LayerNorm`, `RMSNorm`, `pre-norm`, `post-norm`, `residual stream`, `residual connection`, `softmax`, `Q/K/V`.

## Synthèse

Le Transformer decoder-only se compose d'une stack de blocs identiques, chacun avec self-attention masquée puis FFN, autour de residual connections et de normalisation. Self-attention : Q, K, V via projections linéaires, attention scores via dot-product scaled puis softmax. Multi-head pour apprendre des patterns d'attention distincts. MQA et GQA réduisent le KV cache en partageant K et V entre heads ; GQA est le standard moderne. MLA va plus loin en cachant une représentation latente compressée. FFN avec SwiGLU et RMSNorm pré-norm sont les choix canoniques modernes. Le residual stream est central, à la fois pour le gradient flow et l'interprétabilité.
