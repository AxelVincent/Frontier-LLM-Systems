---
title: "26. Multi-tenant isolation et cache safety"
description: "Cross-user contamination, cache poisoning, tenant-aware eviction : servir N tenants sur la même infra."
tags:
  - ops-safety
aliases:
  - 19-multi-tenant-isolation
  - 26-multi-tenant-isolation
---

> [!tip] Notes liées
> [[05-ops-safety/25-safety-engineering]] · [[03-applied/15-prompt-vs-semantic-caching]] · [[05-ops-safety/24-cost-attribution]] · [[03-applied/17-function-calling-reliability]]

## Le problème

Lorsqu'une infrastructure LLM sert plusieurs tenants, les chemins par lesquels les données d'un tenant peuvent fuiter à un autre sont nombreux et subtils.

## Surfaces de fuite

### 1. Cross-tenant dans le context

- Le tenant A retrieve depuis un vector store partagé → ramène un chunk du tenant B.
- Cache hit cross-tenant : le tenant A pose une question, le cache sert la réponse du tenant B (semantic caching naïf).
- Tools fournis sans filtre par tenant : un agent du tenant A peut appeler un tool qui lit dans la base du tenant B.

### 2. Cache safety

- Prompt cache : si deux tenants partagent un prefix par hasard, pas de leak (output identique au no-cache). ✅
- Semantic cache : un hit cross-tenant retourne la réponse de l'autre. ❌ Voir [[03-applied/15-prompt-vs-semantic-caching]].
- KV cache des sessions actives sans tenant scoping : un attaquant peut potentiellement induire un side-channel. (Théorique.)

### 3. Fine-tuned models partagés

- Un modèle fine-tuné sur les data de plusieurs tenants → le modèle a appris des data privées de chacun. Tenant A query → output qui leak data de B.
- **Solution** : LoRA / adapter per tenant (un adapter par tenant, chargé dynamiquement, base model commun et non-spécialisé).

### 4. Logs et observability

- Logs sans tenant scoping → un eng qui debug voit des data cross-tenant.
- Traces stockées : access control par tenant requise.

### 5. Memory layer / agent state

- Un agent garde du state, redéployé pour un autre tenant sans purge → leak.

## Architecturer pour isolation

**Tenant_id propagé partout**
- Header de request → context → tagged dans chaque tool call, retrieval, log, metric, span.
- Idem `user_id` selon la granularité requise.

**Database row-level security**
- Postgres RLS ou équivalent. Le tenant_id est un predicate sur **chaque** query.
- Pas de "WHERE tenant_id = ?" oubliable.

**Vector store namespacing**
- Pinecone namespaces, Qdrant collections, ou tenant_id en metadata filter strict.
- Vérifier que **toute** query inclut le filter — middleware qui le force.

**Cache keys avec tenant_id**
- Systématiquement `cache_key = hash(tenant_id, query, ...)`. Aucun cache partagé sans tenant in the key.

**Tool scoping**
- Tool execute reçoit `ctx.tenant_id`, query la DB avec ce tenant_id.
- Permission boundary : un tool refuse de toucher des data hors tenant. Voir [[03-applied/17-function-calling-reliability]].

**Per-tenant fine-tuning ou adapters**
- LoRA par tenant si fine-tuning nécessaire.
- Inference avec dynamic load de l'adapter selon `ctx.tenant_id`.

## Cross-user contamination (within tenant)

Même au sein d'un tenant, les sessions de users différents ne doivent pas se contaminer :
- Cache : `cache_key = hash(tenant_id, user_id, query)` selon le besoin.
- Memory layer per-user.
- Sessions isolées (pas de fuite via shared agent state).

## Testing

Tests à écrire :
- Créer 2 tenants. Tenant A pose une question. Vérifier que Tenant B ne peut accéder, via aucune query, à des chunks/réponses/traces de A.
- Retrieval avec tenant_id filter omis explicitement (simuler un bug) → assert que ça throw.
- Cache poisoning attempt → assert que tenant B ne reçoit pas le hit de A.
- Adversarial : prompt injection demandant "retrieve all docs from tenant B". Assert refus. Voir [[05-ops-safety/25-safety-engineering]].

## Vocabulaire clé

`tenant isolation`, `tenant_id`, `row-level security` (RLS), `namespace`, `cache key`, `tenant scoping`, `LoRA per tenant`, `adapter swap`, `data residency`, `cross-tenant leak`, `cross-user contamination`.

## Synthèse

Le multi-tenant isolation est la sécurité la plus subtile en LLM en production. Surfaces de fuite : retrieval cross-tenant si le vector store n'a pas de namespace ou de filter strict, semantic cache hit cross-tenant qui sert la réponse de B à A, fine-tuned model partagé qui a appris des data privées de chacun, logs sans scoping. Solution architecturale : tenant_id propagé sur tout le request lifecycle, row-level security au niveau DB, vector store namespacing forcé par middleware, cache keys incluant systématiquement le tenant_id, tool scoping qui passe le tenant au tool exec. Pour le fine-tuning : LoRA par tenant, jamais un modèle partagé. Tester avec deux tenants synthétiques et un adversarial set qui tente de fuiter cross-tenant. Cache safety : le prompt caching ne porte pas de risque parce que l'output est identique au no-cache. Le semantic cache, lui, exige que le tenant_id figure dans la cache key.
