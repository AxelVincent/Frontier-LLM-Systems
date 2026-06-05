---
title: "27. Fine-tuning vs ICL vs RAG vs distillation"
description: "Decision framework : quand fine-tuner, quand faire du in-context learning, quand RAG, quand distiller."
tags:
  - meta
aliases:
  - 20-ft-vs-icl-vs-rag-vs-distill
  - 27-ft-vs-icl-vs-rag-vs-distill
---

> [!info] Prérequis
> [[01-architecture/07-post-training-alignment|07. Post-training]] · [[04-retrieval-quality/20-rag-architecture|20. RAG]] · [[03-applied/14-context-engineering|14. Context engineering]] — cette note compare ces approches, donc en avoir une idée concrète au préalable est utile.

> [!tip] Notes liées
> [[04-retrieval-quality/20-rag-architecture]] · [[02-inference/11-speculative-quant-distill]] · [[02-inference/12-quantization-deep-dive]] · [[06-meta/28-tradeoffs]]

## Le concept

Quatre outils pour "adapter un LLM à un problème". Chacun a un sweet spot. Choisir le mauvais conduit à des coûts ou des dégradations évitables.

## In-Context Learning (ICL)

Inclure des exemples (few-shot) ou des instructions détaillées dans le prompt à chaque call.

**Quand c'est le bon outil** :
- 1-20 exemples disponibles.
- Format / style à transférer clair et visible.
- Prototypage ou itération rapide.
- Pas de besoin de scale économique très important.

**Quand c'est le mauvais** :
- 1000+ exemples : ICL plafonne, le fine-tuning bat l'ICL.
- Les exemples sont facturés à chaque call (hors prompt caching, voir [[03-applied/15-prompt-vs-semantic-caching]]).
- Format très spécifique / technique mal maîtrisé par le base model.

## Retrieval-Augmented Generation (RAG)

Injecter du contexte récupéré dynamiquement à chaque call. Voir [[04-retrieval-quality/20-rag-architecture]].

**Quand c'est le bon outil** :
- Données qui changent (docs, knowledge base, prix).
- Volume de connaissance > context window.
- Besoin de citer la source.
- Besoin d'audit / traçabilité.

**Quand c'est le mauvais** :
- Objectif : changer le **comportement** du modèle (style, format, raisonnement), pas lui fournir des faits.
- Données stables et petites (ICL suffit).
- Latency critique sub-second et budget pour retrieval limité.

## Fine-tuning

Update des weights du modèle sur un dataset spécifique.

### Variantes

- **Full fine-tuning** : tous les weights bougent. Coûteux, risque de catastrophic forgetting.
- **LoRA / QLoRA** : adapters bas-rang ajoutés, base model frozen. Cheap, deployable per-tenant. Voir [[05-ops-safety/26-multi-tenant-isolation]].
- **SFT** : sur des paires (instruction, response).
- **DPO / RLHF** : alignement sur préférences humaines.

**Quand c'est le bon outil** :
- 1000+ exemples de high quality.
- Style / format / raisonnement spécifique à internaliser dans le modèle.
- Production scale économique (le fine-tune amortit le coût d'opération).
- Domaine spécialisé que le base model maîtrise mal.

**Quand c'est le mauvais** :
- Objectif : que le modèle "connaisse" des faits qui changent (utiliser RAG).
- Peu d'exemples (utiliser ICL).
- Phase de prototypage : le cycle de fine-tune est lent par rapport à l'ICL.
- Multi-tenant avec data privée : risque de leakage hors LoRA per-tenant.

## Distillation

Entraîner un modèle plus petit à imiter un modèle plus gros. Voir [[02-inference/11-speculative-quant-distill]].

**Quand c'est le bon outil** :
- Workload bien défini et stable.
- Volume important justifiant le coût training (sinon l'ICL coûte moins).
- Latency / cost à contrainte serrée.
- Possibilité de générer un dataset de teacher outputs ou d'utiliser un teacher accessible.

**Quand c'est le mauvais** :
- Workload qui évolue : le student dérive.
- Long-tail tasks où le teacher excelle mais où le student rate.
- Pas de teacher accessible (modèle propriétaire interdisant la distillation).

## Quand chacun est le mauvais outil

| Use case | Mauvais choix | Bon choix |
|---|---|---|
| Knowledge qui change (docs internes, prix) | Fine-tuning | RAG |
| Style spécifique à transférer | RAG | Fine-tuning ou prompt eng riche |
| 5 exemples de format | Fine-tuning | ICL few-shot |
| Réduction latency/cost à scale | RAG | Quantization + distillation |
| Multi-tenant avec data privée | Full fine-tuning shared | LoRA per-tenant ou RAG par-tenant |
| Edge deployment | RAG (besoin du retrieval store) | Distilled small model embedded |
| Cas où le base model est déjà bon | Fine-tuning (overengineering) | ICL |

## Combinaisons en production

Rarement un seul des quatre :
- **RAG + ICL** : retrieved chunks comme contexte, plus few-shot examples du format de réponse attendu. **Pattern dominant 2024-2025.**
- **Fine-tuning + RAG** : fine-tune pour le style, RAG pour les faits.
- **Distillation + Fine-tuning** : distiller un gros teacher en student, puis fine-tuner sur edge cases.
- **Distillation + Quantization** : Mistral Small (distillé) servi en FP8 quantized.

## Decision framework

```
1. Le base model marche-t-il déjà bien out-of-the-box ?
   Oui → ICL, éventuellement prompt eng riche. Done.
   Non → continue.

2. Le gap concerne-t-il la knowledge ou le comportement ?
   Knowledge (faits, docs, prix) → RAG.
   Comportement (style, format, raisonnement) → continue.

3. Dispose-t-on de 1000+ exemples high quality ?
   Non → ICL avec long prompt + better few-shot. Boucle.
   Oui → continue.

4. Le workload est-il stable et économique-relevant ?
   Non (prototype) → ICL. Iter.
   Oui → fine-tuning (LoRA par défaut).

5. Latency/cost en prod toujours pas OK ?
   → Distillation + quantization du base model.
```

## Vocabulaire clé

`in-context learning` (ICL), `few-shot`, `zero-shot`, `RAG`, `retrieval-augmented generation`, `fine-tuning`, `SFT`, `LoRA`, `QLoRA`, `adapter`, `catastrophic forgetting`, `distillation`, `teacher`, `student`, `task-specific model`.

## Synthèse

Quatre outils aux sweet spots distincts. ICL pour 1-20 exemples, prototyping, peu de volume. RAG pour les knowledge qui changent et l'attribution. Fine-tuning pour modifier le comportement quand on dispose de 1000+ exemples et d'un workload stable — LoRA par défaut pour éviter le catastrophic forgetting et permettre du per-tenant. Distillation pour réduire latency/cost à scale sur un workload bien défini. Le piège classique est le mismatch : utiliser fine-tuning pour de la knowledge qui change (utiliser RAG), utiliser RAG pour transférer un style (utiliser few-shot ou fine-tune), utiliser fine-tuning shared en multi-tenant avec data privée (utiliser LoRA par tenant). En production, rarement un seul : RAG + ICL est le pattern dominant, et Mistral Small représente distillation + quantization.
