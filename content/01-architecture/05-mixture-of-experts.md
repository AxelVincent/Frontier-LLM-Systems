---
title: "05. Mixture of Experts (MoE)"
description: "Routing top-k, expert capacity, auxiliary-loss-free balancing, all-to-all : sparse activation en pratique."
tags:
  - architecture
aliases:
  - 27-mixture-of-experts
  - 05-mixture-of-experts
---

> [!tip] Notes liées
> [[01-architecture/01-transformer-architecture]] · [[01-architecture/06-distributed-training]] · [[02-inference/08-kv-cache-management]] · [[02-inference/11-speculative-quant-distill]]

## Le concept

Dans un Transformer dense, chaque token traverse l'intégralité des paramètres à chaque forward pass. Dans un Transformer **Mixture of Experts (MoE)**, le bloc FFN est remplacé par un ensemble d'**experts** (FFN parallèles), et un **router** sélectionne dynamiquement les experts activés pour chaque token.

Conséquence : on dispose d'un modèle avec un grand nombre de paramètres **totaux**, mais un faible nombre de paramètres **actifs** par token. Le compute par token reste comparable à un modèle dense beaucoup plus petit, alors que la capacité représentationnelle approche celle d'un modèle dense beaucoup plus gros.

> [!example] Intuition — sparse activation
> MoE est une forme de **routage conditionnel** : le FFN devient un pool de E sous-réseaux, et un dispatcher (le router) sélectionne k experts par token. La capacité représentationnelle scale avec E ; le coût compute par token scale avec k. Cette décorrélation permet d'augmenter agressivement le nombre de paramètres totaux sans inflation proportionnelle du FLOP/token — au prix d'un coût mémoire qui, lui, reste proportionnel à E.

## Architecture

Pour chaque token (au niveau du bloc FFN) :

1. Le **router** (typiquement une simple projection linéaire suivie d'un softmax) calcule un score pour chacun des E experts.
2. Les **top-k experts** sont sélectionnés (typiquement k=2).
3. Le token passe à travers ces k experts.
4. Les outputs sont combinés pondérés par les scores du router.

```
gate_logits = router(x)            # [E]
top_k_indices, top_k_weights = topk(softmax(gate_logits), k)
output = sum(top_k_weights[i] * expert_i(x) for i in top_k_indices)
```

## Métriques clés

- **Total parameters** : somme des paramètres de tous les experts + reste du modèle.
- **Active parameters** : paramètres traversés par un token donné.
- **Ratio actif/total** : indicateur de "sparsité" du modèle.

Exemple : **Mixtral 8x7B** dispose de 47B paramètres totaux et 13B actifs (2 experts sur 8 sélectionnés par token, sur des layers FFN qui représentent l'essentiel des paramètres). Une attention particulière : "8x7B" ne signifie pas 56B — les composants non-MoE (attention, embedding) sont partagés entre experts.

## Routing

### Top-k gating

Le router choisit les k experts avec les plus hauts scores. k=2 est le choix le plus fréquent (Mixtral, GShard). k=1 (Switch Transformer) est plus rapide mais moins performant.

### Expert capacity

À l'entraînement, le routing peut devenir **déséquilibré** : un petit sous-ensemble d'experts reçoit la majorité des tokens. Pour limiter cela, on impose une **capacity** : nombre maximum de tokens routés vers chaque expert par batch. Les tokens excédentaires sont :
- soit **dropped** (perte d'information),
- soit routés vers un expert backup.

Capacity factor typique : 1.0 à 1.5 × (n_tokens / n_experts).

### Load balancing loss

Pour encourager une utilisation équilibrée des experts, on ajoute une **auxiliary loss** au training qui pénalise le déséquilibre :

```
L_aux = E × sum(f_i × P_i)
```

avec `f_i` la fraction de tokens routés vers l'expert `i` et `P_i` la fraction de la masse de probabilité du router pour l'expert `i`.

### Auxiliary-loss-free balancing (DeepSeek-V3)

DeepSeek-V3 a remplacé la auxiliary loss par un mécanisme de **bias dynamique** ajouté aux logits du router et ajusté à la volée selon l'utilisation observée. Évite les artefacts d'optimisation introduits par la auxiliary loss.

### Fine-grained experts (DeepSeek)

Au lieu de quelques experts larges (Mixtral : 8), DeepSeek utilise un grand nombre d'experts plus petits (DeepSeek-V3 : 256 routed + 1 shared) avec un k plus élevé. Améliore la spécialisation et la qualité.

### Shared experts

Certains experts sont **toujours activés** (DeepSeek). Capture les patterns communs, libère les experts routés pour la spécialisation.

## Modèles MoE notables

- **Switch Transformer** (Google, 2021) : premier MoE à l'échelle, k=1.
- **GShard** (Google) : MoE avec sharding distribué.
- **Mixtral 8x7B / 8x22B** (Mistral, 2024) : 8 experts, k=2, 47B/141B total.
- **DeepSeek-V2 / V3** : MoE avec MLA, fine-grained experts, auxiliary-loss-free, 236B/671B total, ~21B/37B actifs.
- **Qwen2-MoE**, **Grok-1** (314B total).

## Inference MoE

### Expert parallelism

Les experts sont distribués sur plusieurs GPUs. Chaque token est routé via communication all-to-all vers le GPU hébergeant son expert. Voir [[01-architecture/06-distributed-training]].

- Coût : latence de communication.
- Avantage : permet de loader des modèles trop gros pour un seul GPU.

### Mémoire vs compute

MoE en inference a une particularité : le **compute** par token est faible (peu de params actifs), mais la **mémoire** nécessaire est élevée (tous les experts doivent être chargés au cas où). Souvent mémoire-bound même en prefill.

Stratégies :
- Offloading des experts inactifs sur CPU RAM.
- Expert pruning offline (élimination des experts rarement activés).

## Trade-offs

| Aspect | Dense | MoE |
|---|---|---|
| Compute par token | Élevé | Faible |
| Mémoire totale | Modérée | Élevée (tous les experts) |
| Qualité par compute | Bonne | Meilleure |
| Qualité par paramètre | Meilleure | Moins bonne |
| Complexité serving | Simple | Complexe (routing, expert parallelism) |
| Robustesse training | Standard | Délicate (load balancing) |

## Vocabulaire clé

`Mixture of Experts` (MoE), `expert`, `router`, `top-k gating`, `top-k routing`, `expert capacity`, `capacity factor`, `load balancing loss`, `auxiliary-loss-free balancing`, `fine-grained experts`, `shared expert`, `sparse activation`, `active parameters`, `total parameters`, `expert parallelism`, `all-to-all`, `Switch Transformer`, `Mixtral`, `DeepSeek-V3`.

## Synthèse

Un Transformer MoE remplace le bloc FFN par un ensemble d'experts (FFN parallèles), avec un router qui sélectionne les top-k experts par token. Conséquence : le modèle a un grand nombre de paramètres totaux mais peu de paramètres actifs par token. Mixtral 8x7B = 47B total, 13B actifs (k=2 sur 8 experts). DeepSeek-V3 = 671B total, 37B actifs (fine-grained experts, auxiliary-loss-free balancing). Le routing nécessite une expert capacity et une load balancing loss pour éviter le collapse vers un petit ensemble d'experts. En inference, MoE est typiquement mémoire-bound : compute par token faible mais tous les experts doivent être chargés. Expert parallelism distribue les experts sur plusieurs GPUs au prix d'un coût de communication all-to-all.
