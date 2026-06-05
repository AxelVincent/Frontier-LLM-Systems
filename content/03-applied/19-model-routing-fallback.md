---
title: "19. Model routing et graceful fallback"
description: "Cascade routing, classifier routing, provider fallback : router une gamme de modèles sous contrainte de coût/latence."
tags:
  - applied
aliases:
  - 12-model-routing-fallback
  - 19-model-routing-fallback
---

> [!tip] Notes liées
> [[03-applied/16-structured-outputs]] · [[05-ops-safety/24-cost-attribution]] · [[06-meta/28-tradeoffs]] · [[06-meta/29-production-failure-modes]]

## Le concept

Un système LLM mature ne sert pas un seul modèle. Il sert une **gamme**. Le bon modèle pour une requête dépend de :

- Complexité de la tâche.
- Latency SLA.
- Cost budget.
- Disponibilité (provider down).
- Tenant tier (free vs enterprise).
- A/B test en cours.

Le **model router** décide à chaque request quel modèle utiliser.

## Patterns de routing

**1. Static routing**
- Mapping hardcoded : `task_type=summarize → mistral-small`, `task_type=code → mistral-large`.
- Simple, prévisible. Pas adaptatif.

**2. Rule-based routing**
- Decision tree : `if prompt_length > 50k: mistral-large else: mistral-small`.
- `if requires_function_calling: mistral-large`.
- Adapté aux règles métier claires.

**3. Classifier-based routing**
- Un petit modèle (ou regex/heuristique) classifie la requête : easy / medium / hard.
- Route vers small / medium / large.
- Bon ratio cost/quality.

**4. Cascade routing**
- Try small model d'abord. Si confidence bas (logprobs, self-eval, schema fail) → re-call large.
- Avantage : on paie large uniquement quand nécessaire.
- Coût : la latency totale est small + large dans le worst case.

**5. Ensemble / consensus**
- Plusieurs modèles répondent, on prend le consensus.
- Coûteux mais améliore la qualité sur tasks critiques.

## Fallback logic

**Cas d'usage du fallback** :
- Provider down (5xx, timeout).
- Rate limit (429).
- Budget dépassé (plus de quota pour ce modèle).
- Schema validation failure ([[03-applied/16-structured-outputs]]).
- Quality threshold non atteint.

**Patterns** :

**Sequential fallback chain**
```
primary: mistral-large
  on error: mistral-small
    on error: claude-sonnet (different provider)
      on error: cached_response or static_message
```

**Parallel fallback (hedging)**
- Lancer la requête sur 2 providers en parallèle.
- Garder la première réponse acceptable.
- Coût : 2x sur certaines requêtes. Gain : tail latency réduite.

**Circuit breaker**
- Si un provider échoue N fois en M secondes, l'écarter de la rotation pendant T.
- Évite de saturer un provider down.
- Recovery automatique après timeout.

## Graceful degradation UX

L'utilisateur ne doit pas savoir qu'un failover a eu lieu. Lorsque la dégradation est forte, en revanche, elle doit être communiquée :

- **Light degradation** : passage de large à small. Réponse moins précise mais plausible. Pas d'avertissement nécessaire.
- **Medium degradation** : timeout sur tool call, réponse partielle. "I couldn't complete X. Here's what I have so far."
- **Heavy degradation** : impossible de répondre. "Service temporarily degraded. Please retry."

**Anti-pattern** : silence sur la dégradation. L'utilisateur réessaie la même prompt en croyant que tout fonctionne, et son workflow comporte un bug invisible.

## Multi-tenant routing

Tenants différents → modèles différents :
- Tenant enterprise : Mistral Large + low latency + redundancy.
- Tenant free : Mistral Small + best effort.
- Tenant trial : Mistral Small avec quota strict.

Critique pour la viabilité économique d'une plateforme LLM. Voir [[05-ops-safety/24-cost-attribution]].

## Métriques

- `routing_decision_distribution` per model.
- `fallback_invocation_rate` per fallback level.
- `circuit_breaker_state` per provider.
- `degraded_mode_response_rate` (fréquence de dégradation visible).
- `cost_per_request` per route.

## Vocabulaire clé

`model router`, `static routing`, `cascade routing`, `classifier-based routing`, `fallback chain`, `hedging`, `circuit breaker`, `graceful degradation`, `degraded mode`, `multi-provider`, `quota`, `rate limit`, `429`, `provider failover`.

## Synthèse

Un model router décide à chaque request quel modèle utiliser, selon complexité, latency SLA, cost budget et tenant tier. Patterns : static, rule-based, classifier-based, cascade (try small puis fallback large si confidence bas). Le fallback chain assure la résilience : primary Mistral Large, fallback Small en cas d'erreur, fallback à un autre provider en cas de provider down, et enfin fallback à une réponse cached ou statique. Circuit breaker pour éviter de saturer un provider down. Hedging pour réduire les tail latencies. UX : light degradation invisible, medium degradation explicitée ("partial result"), heavy degradation explicitée ("service degraded"). Anti-pattern à éviter : le silent failure qui laisse l'utilisateur croire que tout va bien.
