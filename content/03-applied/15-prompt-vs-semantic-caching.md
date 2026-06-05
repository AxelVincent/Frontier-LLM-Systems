---
title: "15. Prompt caching vs semantic caching"
description: "Deux types de cache complètement distincts : un sur les KV, l'autre sur les embeddings — quand utiliser quoi."
tags:
  - applied
aliases:
  - 03-prompt-vs-semantic-caching
  - 15-prompt-vs-semantic-caching
---

> [!tip] Notes liées
> [[02-inference/08-kv-cache-management]] · [[05-ops-safety/26-multi-tenant-isolation]] · [[05-ops-safety/24-cost-attribution]] · [[03-applied/14-context-engineering]]

> [!example] Intuition — deux mécanismes orthogonaux
> Les deux portent le nom *cache* mais opèrent à des niveaux différents :
> - **Prompt caching** mémoize le **KV cache** d'un préfixe. Match exact byte-à-byte, lookup côté provider, **résultat identique** à un appel non caché — c'est un cache de *compute*.
> - **Semantic caching** mémoize des **réponses** complètes, indexées par embedding de la requête. Match approximatif sur la similarité cosinus, **résultat potentiellement différent** d'un appel non caché — c'est un cache de *décision*.
>
> Le premier est toujours safe ; le second introduit un risque qualité à calibrer (seuil de similarité, scope par tenant, invalidation).

## Deux mécanismes distincts

**Prompt caching** (Anthropic, OpenAI, Mistral) : un prefix de prompt est marqué comme cachable. Le serveur conserve le **KV cache** du prefix entre les requêtes. Toute requête ultérieure partageant ce prefix bénéficie d'un prefill évité (typiquement 90% de réduction de latence et de coût sur la portion cachée).

**Semantic caching** : la requête utilisateur est hashée sémantiquement (via embedding) et une réponse précédente d'une requête sémantiquement proche est servie, sans appel au modèle.

Les deux résolvent des problèmes différents.

## Prompt caching

### Fonctionnement

- Le provider hash le prefix (system prompt, tool definitions, few-shot examples, doc context) et conserve le KV cache associé côté serveur avec un TTL (5 min sur Anthropic, plus long sur tier supérieur).
- Le matching est **prefix-based** et **byte-exact** : un seul token modifié avant la cache breakpoint invalide complètement le cache.
- Tarification : l'écriture est légèrement plus chère (1.25x sur Anthropic), la lecture significativement moins chère (0.1x).

### Quand l'utiliser

- System prompt long et stable.
- Few-shot examples partagés entre requêtes.
- Tool definitions volumineuses (2-5k tokens fréquents).
- Doc context réutilisé (RAG avec mêmes chunks).

### Échecs

- User message inséré au milieu du prefix : invalidation systématique.
- Tool definitions générées dynamiquement par tenant : cache miss systématique.
- TTL trop court par rapport à la fréquence de requêtes.

## Semantic caching

### Fonctionnement

- Embedding de la requête utilisateur.
- Recherche dans un vector store des requêtes précédentes dont la similarité dépasse un seuil (typiquement ≥0.95 pour limiter les risques).
- En cas de match : la réponse cachée est servie. Sinon : appel au modèle puis écriture de la nouvelle entrée.

### Quand l'utiliser

- Cas d'usage très répétitif (FAQ, support tier 1, classification).
- Réponses déterministes ou tolérantes à de petites variations.
- Volume élevé justifiant l'infrastructure.

### Échecs

- **Faux positifs sémantiques** : "comment annuler mon abonnement" vs "comment **renouveler** mon abonnement" ont des embeddings très proches mais des réponses opposées. Mitigation : seuil élevé + reranker.
- **Stale data** : la réponse cachée référence un état qui a changé depuis.
- **Personalisation** : la réponse cachée d'un user A servie à un user B constitue un anti-pattern et un leak de données. Voir [[05-ops-safety/26-multi-tenant-isolation]].
- **Coût de l'embedding** : non-trivial à fort volume.

## Trade-off principal

| Dimension | Prompt cache | Semantic cache |
|---|---|---|
| Gain latency | 50-90% (prefill évité) | 99%+ (pas d'appel modèle) |
| Gain cost | 90% sur la portion cachée | 100% sur le hit |
| Risque correctness | Nul (output identique à no-cache) | Élevé (faux positifs) |
| Use case | System prompt stable, RAG, agents | FAQ, classification, query répétitive |

## Vocabulaire clé

`prompt caching`, `cache breakpoint`, `prefix cache`, `cache hit ratio`, `TTL`, `semantic cache`, `embedding similarity`, `cache key collision`.

## Synthèse

Le prompt caching met en cache le KV cache d'un prefix stable côté serveur. On marque le prefix avec un breakpoint et le prefill est réutilisé sur toutes les requêtes qui matchent. Gain : 90% latency, 90% cost sur la partie cachée, sans risque de correctness. Le semantic caching est un mécanisme distinct : on hash la requête en embedding et on sert une réponse précédente si la similarité est haute. Gain : 100% — pas d'appel modèle. Risque : faux positifs sémantiques comme "annuler" vs "renouveler" qui ont des embeddings proches. Les deux mécanismes sont compatibles et adressent des problèmes différents.
