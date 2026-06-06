---
title: "23. LLM observability"
description: "Traces, spans, drift, token usage, latency percentiles : observability spécifique aux systèmes LLM."
tags:
  - ops-safety
aliases:
  - 16-llm-observability
  - 23-llm-observability
---

> [!info] Prérequis
> [[03-applied/13-harness-engineering|13. Harness engineering]] — l'observability instrumente précisément les composants du harness (event loop, tool calls, state transitions).

> [!tip] Notes liées
> [[05-ops-safety/24-cost-attribution]] · [[04-retrieval-quality/22-evals]] · [[06-meta/29-production-failure-modes]]

## Pourquoi observability "first-class"

Le debug d'un système LLM n'est pas accessible via de simples logs print. Le système est non-déterministe, à latence variable, multi-services, et son état est distribué dans le contexte. Sont nécessaires :

- **Traces** : reconstruction de chaque requête end-to-end.
- **Spans** : sous-opérations (model call, tool call, retrieval).
- **Metrics** : agrégés (p50/p99, error rate, cost).
- **Events / logs structurés** : description de ce qui s'est passé, pas seulement signalement d'erreur.

C'est une discipline à part entière, et non un nice-to-have.

## Traces et spans

**Trace** = une requête utilisateur end-to-end, du HTTP receive jusqu'à la response.

**Span** = une sous-opération dans la trace, avec son propre start/end, attributes et events.

Exemple de trace pour une requête RAG agent :

```
trace_id=abc123 (user query: "What's our refund policy?")
├── span: classify_intent (model: small, 50ms, cost: $0.0001)
├── span: retrieve (
│     ├── span: embed_query (50ms)
│     ├── span: vector_search (top-100, 20ms)
│     ├── span: rerank (top-10, 200ms)
│     └── total: 270ms, 10 chunks
│   )
├── span: model_call (model: large, prefill_tokens: 4200, decode_tokens: 180, 
│         ttft: 800ms, tpot: 35ms, total: 7s, cost: $0.012)
└── span: post_process (validation: pass, 5ms)
```

Standard : **OpenTelemetry** + extensions LLM-specific (semantic conventions for LLM spans : gen_ai.* attributes).

## Attributes à logguer (par span de model call)

- `model_name` (e.g., mistral-large-2411)
- `provider` (mistral, openai, anthropic, self-hosted)
- `prompt_token_count` / `completion_token_count` / `cached_token_count`
- `ttft_ms` / `tpot_ms` / `total_latency_ms`
- `cost_usd_input` / `cost_usd_output` / `cost_usd_total`
- `finish_reason` (stop, length, content_filter, tool_calls)
- `temperature` / `top_p` / `max_tokens`
- `tenant_id` / `user_id` / `session_id`
- `feature_name` / `workflow_id` (cf. [[05-ops-safety/24-cost-attribution]])
- `request_id` / `parent_request_id` (pour chaining)
- `error` / `error_type` / `error_message`
- `retry_count` / `fallback_invoked`

Et le **prompt complet** (input messages, tool definitions) + **response** stockés ([[05-ops-safety/25-safety-engineering|PII]] handling requis, voir [[05-ops-safety/25-safety-engineering]]).

## Outils

**Tracing platforms LLM-aware** :
- **LangSmith** (LangChain).
- **Langfuse** (open source, self-hostable).
- **Helicone**.
- **Phoenix (Arize)**.
- **Traceloop**.
- **PostHog LLM Analytics**.

**Generic** :
- OpenTelemetry + Jaeger/Tempo/Honeycomb/Datadog.

## Drift detection

**Concept drift** : la distribution des inputs change avec le temps. Le modèle entraîné/calibré pour X reçoit Y.

**Output drift** : la distribution des outputs change (souvent dû à un changement de modèle backend, ou de prompt).

**Performance drift** : la qualité se dégrade silencieusement.

Méthodes de détection :
- **Embedding-based drift** : embed des inputs et outputs sur une période, comparaison aux periodes précédentes via distance moyenne.
- **Statistical tests** : chi-squared sur catégories (intent, output_format, etc.), KS test sur distributions numériques.
- **Eval continue** : sample 1% du traffic, run d'un eval batch quotidien, alerte si pass_rate drop. Voir [[04-retrieval-quality/22-evals]].

## Metrics à dashboarder

- Volume : requests/sec, total tokens/sec.
- Latency : ttft p50/p95/p99, tpot p50/p99, total p99.
- Error rate : 4xx/5xx, model errors, validation failures.
- Cost : $/hour, $ par feature, $ par tenant.
- Quality : eval pass rate (continuous sample), thumbs up/down, regeneration rate.
- Tool usage : tool call frequency, tool success rate.
- Cache : [[03-applied/15-prompt-vs-semantic-caching|prompt cache]] hit rate, [[03-applied/15-prompt-vs-semantic-caching|semantic cache]] hit rate.
- Capacity : GPU utilization, queue depth, [[02-inference/08-kv-cache-management|KV cache]] utilization.

## Alerting

Threshold-based :
- p99 latency > 5s pendant 5 min.
- Error rate > 1% pendant 10 min.
- Cost burn rate > 2x baseline pendant 1h.

Anomaly-based :
- 3-sigma deviation sur metric clé.
- Distribution shift sur output category.

## Vocabulaire clé

`trace`, `span`, `attribute`, `event`, `OpenTelemetry`, `gen_ai semantic conventions`, `tracing`, `LangSmith`, `Langfuse`, `Helicone`, `concept drift`, `output drift`, `performance drift`, `embedding drift`, `KS test`, `cardinality`, `sampling`, `tail latency`, `p99`.

## Synthèse

La LLM observability repose sur traces, spans et attributes structurés. OpenTelemetry constitue le standard, avec les gen_ai semantic conventions. Une trace correspond à la requête end-to-end, avec un span par sous-op : intent classification, retrieve, model call, post-process. Chaque span de model call logue model, provider, prompt et completion token count, ttft, tpot, cost, finish_reason, tenant, feature. Outils : LangSmith, Langfuse, Helicone, Phoenix, PostHog LLM Analytics. Drift detection : embedding-based sur inputs/outputs comparés period vs period, KS test sur distributions, eval continue sur sample 1% du traffic. Metrics dashboardés : latency p50/p99, error rate, cost, quality, cache hit rates, KV utilization. Alerting threshold + anomaly. Discipline first-class parce que le debug d'un système non-déterministe, distribué et stateful n'est pas accessible autrement.
