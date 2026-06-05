---
title: "11. Speculative decoding, quantization, distillation"
description: "Trois familles d'accélération orthogonales : qui les choisit quand, et leurs trade-offs qualité/coût."
tags:
  - inference
aliases:
  - 07-speculative-quant-distill
  - 11-speculative-quant-distill
---

> [!tip] Notes liées
> [[02-inference/12-quantization-deep-dive]] · [[02-inference/09-prefill-vs-decode]] · [[02-inference/10-continuous-batching-paged-attention]] · [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]]

## Trois familles d'accélération

Ces trois techniques sont fréquemment confondues. Elles résolvent des problèmes différents avec des trade-offs différents.

## Speculative decoding

**Principe** : utiliser un petit modèle "draft" pour proposer plusieurs tokens d'un coup, puis faire valider/corriger par le gros modèle "target" en **une seule** forward pass.

- Le draft model génère K tokens.
- Le target model fait 1 forward pass qui calcule la proba de chaque token proposé.
- Les tokens sont acceptés depuis le début jusqu'au premier rejeté (rejection sampling).
- Garantie mathématique : la distribution de sortie est **identique** à celle du target seul. **Aucune perte qualité.**

> [!example] Intuition — propose + verify
> Analogie directe avec la **branch prediction** d'un CPU. Le draft model spécule K tokens en avance ; le target les vérifie en une seule forward pass parallèle (au lieu de K passes séquentielles). Tous les tokens acceptés depuis le préfixe sont commités, le premier rejeté déclenche un rollback. Le gain dépend de l'*acceptance rate* — élevé sur du texte prédictible (code, formats), faible sur de la génération divergente.

### Variantes

- **Vanilla speculative decoding** (Leviathan et al., Chen et al. 2023).
- **EAGLE / EAGLE-2** : draft via une head supplémentaire qui réutilise les hidden states du target.
- **Medusa** : plusieurs heads de prédiction sur le target lui-même.
- **Lookahead decoding** : self-speculative, sans draft model séparé.

**Gain** : 1.5x à 3x sur throughput/latency selon acceptance rate.

**Coût** : mémoire pour draft model (~1-2 GB pour un draft 1B), complexité scheduler.

**Quand c'est efficace** : génération avec patterns prédictibles (code, formats structurés, complétion). Acceptance rate élevé.

**Quand c'est moins efficace** : génération très créative ou divergente. Acceptance bas, gain modeste.

## Quantization

**Principe** : représenter les weights (et parfois les activations et le KV cache) avec moins de bits que les originaux (FP16/BF16).

- FP16 → INT8 = 2x mémoire, ~2x throughput, qualité quasi-intacte (W8A8 ou W8A16).
- FP16 → INT4 = 4x mémoire, qualité dégradée sur certains tasks, nécessite calibration soignée (GPTQ, AWQ).
- FP16 → FP8 = 2x, hardware-accelerated sur H100, qualité quasi-intacte.

**Le modèle est le même** (mêmes paramètres entraînés), avec une précision réduite. Détails : [[02-inference/12-quantization-deep-dive]].

**Gain** : mémoire (donc plus gros batch, plus longs contextes), throughput sur certains hardwares.

**Coût** : perte de qualité variable.

## Distillation

**Principe** : entraîner un **nouveau** modèle (plus petit, le "student") à imiter le comportement d'un gros modèle (le "teacher").

- Le student est un modèle séparé, plus petit, plus rapide.
- Entraîné soit sur les logits du teacher (KL divergence sur la distribution), soit sur des outputs samplés du teacher (output distillation).
- Variantes : DistilBERT (BERT 40% plus petit), Mistral Small (distillé de Mistral Large), Llama 3.2 1B/3B (distillés de Llama 3.1).

**Gain** : modèle 5-50x plus petit, gain proportionnel en latency/cost.

**Coût** : perte de qualité significative (le student n'égale jamais le teacher sur les long-tails) + coût d'entraînement (millions de tokens).

## Comparaison

| Technique | Qualité | Mémoire | Latency | Effort |
|---|---|---|---|---|
| Speculative decoding | Identique | + (draft model) | 1.5-3x mieux | Moyen (vLLM le supporte) |
| Quantization | Quasi-identique à très dégradée | 2-8x mieux | 1.5-2x mieux | Faible (modèles disponibles) |
| Distillation | Significativement moins bonne | 5-50x mieux | 5-50x mieux | Élevé (full training run) |

## Decision framework

- Budget latency strict, aucune perte qualité tolérable → speculative decoding.
- Budget mémoire serré (déploiement edge, ou cost-sensitive) → quantization INT8 d'abord, puis INT4 si la qualité tient.
- Workload bien défini, volume important, légère perte qualité tolérable → distillation. C'est le projet le plus lourd (data, training, eval).
- En production chez les providers : les trois sont combinées. Mistral Small (distillation) servi avec quantization FP8 et speculative decoding via continuous batching.

## Vocabulaire clé

`speculative decoding`, `draft model`, `target model`, `acceptance rate`, `EAGLE`, `Medusa`, `lookahead decoding`, `quantization`, `post-training quantization (PTQ)`, `quantization-aware training (QAT)`, `distillation`, `knowledge distillation`, `teacher`, `student`, `logit distillation`.

## Synthèse

Speculative decoding est lossless : le draft model propose K tokens, le target valide en une forward pass via rejection sampling. Distribution identique au target seul. Gain 1.5-3x. Quantization est lossy : weights représentés en INT8 ou INT4 au lieu de FP16. Gain 2-4x mémoire et throughput. La qualité se dégrade selon la technique — GPTQ/AWQ pour INT4 calibré. Distillation produit un nouveau modèle plus petit entraîné à imiter le gros. Gain 5-50x mais coût training + perte qualité. En production, les trois sont combinées : distillation pour le base modèle, quantization pour le serving, speculative decoding pour la latency.
