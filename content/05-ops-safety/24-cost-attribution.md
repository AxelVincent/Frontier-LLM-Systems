---
title: "24. Cost attribution"
description: "Attribuer le coût par feature, workflow, tenant : tags, cardinalité, budget enforcement."
tags:
  - ops-safety
aliases:
  - 17-cost-attribution
  - 24-cost-attribution
---

> [!tip] Notes liées
> [[05-ops-safety/23-llm-observability]] · [[03-applied/18-agent-guardrails]] · [[05-ops-safety/26-multi-tenant-isolation]] · [[06-meta/28-tradeoffs]]

## Le problème

À la fin du mois, la facture Mistral / OpenAI / GCP arrive avec un montant agrégé. Sans cost attribution, l'origine du coût reste opaque, et l'optimisation impossible.

## Au-delà de "cost per model"

L'attribution naïve : "Mistral Large = $300k, Mistral Small = $200k". Cette granularité ne fournit aucune information actionnable.

**Granularités utiles** :
- Quelle **feature** coûte combien ? (chat, summarize, semantic search, agent X)
- Quel **workflow** coûte combien ? (un agent qui fait N calls vs single-shot)
- Quel **tenant** coûte combien ? (et est-ce aligné avec ce qu'il paie ?)
- Quel **user journey** coûte combien ? (un onboarding flow vs un power user habituel)
- Quel **prompt template** coûte combien et combien de tokens consomme ?

## Comment attribuer

On attache des **tags** structurés à chaque appel modèle :

```typescript
const response = await mistral.chat.complete({
  model: "mistral-large",
  messages,
  metadata: {
    tenant_id,
    user_id,
    session_id,
    feature: "support_chat",
    workflow: "agent_v2",
    step: "tool_decision",
    prompt_template: "v3.1",
  }
});
```

Puis, dans l'observability platform ([[05-ops-safety/23-llm-observability]]), on agrège :
- `SELECT feature, SUM(cost) GROUP BY feature`
- `SELECT tenant, SUM(cost), COUNT(*) GROUP BY tenant ORDER BY 2 DESC`
- `SELECT prompt_template, AVG(prompt_tokens) GROUP BY prompt_template`

## Cost models à comprendre

**Per-token pricing** : `cost = input_tokens × input_price + output_tokens × output_price`.

Détail souvent négligé : input typiquement 3-5x moins cher que output. Une feature avec long context + court output peut donc être moins chère que ne le suggère l'intuition (et inversement).

**Cached tokens** : Anthropic / OpenAI / Mistral facturent les cached tokens à 0.1x du prix input. À intégrer dans l'attribution. Voir [[03-applied/15-prompt-vs-semantic-caching]].

**Self-hosted** : pas de per-token, mais `cost = GPU_hours × GPU_hourly_rate`. Ces GPU_hours doivent être imputés aux features. Typiquement : `cost_per_request = GPU_hourly / (requests_per_hour)`.

**Egress / network** : non-négligeable à grande échelle (streaming, [[04-retrieval-quality/20-rag-architecture|embeddings]] storage).

## Insights typiques

- **20% des features = 80% du cost** (Pareto). Cibler.
- **Un workflow agent peut faire 10-50 calls** par session → c'est lui qui coûte, pas le "chat one-shot" simple.
- **Un tenant power user peut représenter 50% du cost** d'un produit B2B → enjeu pricing.
- **Un prompt template avec un bug** (ex : tools redéfinis à chaque tour au lieu d'être cached) peut multiplier les coûts par 3-5x sans signal visible dans les graphs agrégés.

## Cost per session vs cost per user

Distinction utile :
- **Cost per request** : juste le call modèle.
- **Cost per session** : tous les calls dans une session conversation.
- **Cost per user-day** : tous les sessions d'un user dans 24h.
- **Cost per LTV** : sur la durée de vie d'un user.

Le **cost per LTV** est celui qui doit s'aligner sur l'ARPU.

## Budget per workflow / per tenant

Au-delà du tracking, on peut **enforcer** des budgets :
- Tenant free : $0.05 max/jour. Au-delà : refus + upgrade prompt.
- Workflow agent : $0.20 max/session. Au-delà : termination ([[03-applied/18-agent-guardrails]]).
- Feature beta : $1000 max/jour pour la feature. Au-delà : feature flag off.

## Failure modes

- **Cardinality explosion** : tagger avec `user_id` peut saturer le observability backend en cas de millions d'users. Utiliser `tenant_id` + `user_segment`.
- **Missing tags** : un endpoint nouvellement ajouté oublie le tag `feature` → blackhole dans le cost dashboard.
- **Wrong attribution** : un wrapper qui hardcode `feature=chat` peut tout matcher à la mauvaise dimension.
- **Cached tokens non comptés** : économie supposée non réelle. Vérifier le response usage.

## Vocabulaire clé

`cost attribution`, `cost per feature`, `cost per workflow`, `cost per tenant`, `cost per session`, `cost per request`, `unit economics`, `LTV/CAC`, `chargeback`, `tag cardinality`, `budget enforcement`, `tenant tier`.

## Synthèse

Le cost attribution dépasse le simple "cost per model". On tagge chaque call modèle avec feature, workflow, step, prompt_template, tenant, user, session. On agrège par dimension dans l'observability platform pour identifier qui coûte quoi. Insights typiques : 20% des features = 80% du coût, un workflow agent fait 10-50 calls par session donc c'est lui qui coûte vraiment, un tenant power user peut représenter 50% du coût d'un produit B2B. Le cost per LTV doit s'aligner sur l'ARPU. On peut aussi enforcer des budgets par workflow ou par tenant — tenant free $0.05 max par jour, workflow agent $0.20 max par session, au-delà kill switch. Failure modes : cardinality explosion si on tagge par user_id, missing tags sur les nouveaux endpoints qui créent un blackhole, et cached tokens non comptés dans les calculs.
