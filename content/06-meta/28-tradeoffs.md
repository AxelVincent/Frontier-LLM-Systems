---
title: "28. Tradeoffs : latency / quality / cost / reliability"
description: "Les quatre axes en tension permanente — chaque décision technique pousse sur deux et dégrade les autres."
tags:
  - meta
aliases:
  - 21-tradeoffs
  - 28-tradeoffs
---

> [!tip] Notes liées
> [[03-applied/19-model-routing-fallback]] · [[02-inference/10-continuous-batching-paged-attention]] · [[02-inference/08-kv-cache-management]] · [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]]

## Les quatre dimensions

Le inference stack se tune selon **latency / quality / cost / reliability**. Les quatre dimensions ne sont pas maximisables simultanément. Le choix porte sur un point d'opération.

## Latency

Composants :
- Network (client → API).
- Queue time (provider load).
- [[02-inference/09-prefill-vs-decode|Prefill time]] ([[02-inference/09-prefill-vs-decode|TTFT]]). Voir [[02-inference/09-prefill-vs-decode]].
- [[02-inference/09-prefill-vs-decode|Decode time]] ([[02-inference/09-prefill-vs-decode|TPOT]] × n_output_tokens).
- Tool call latency (si agent).
- Post-processing.

Leviers de réduction :
- Petit modèle (quality trade-off).
- Quantization (légère quality trade-off). Voir [[02-inference/12-quantization-deep-dive]].
- [[02-inference/11-speculative-quant-distill|Speculative decoding]] (lossless). Voir [[02-inference/11-speculative-quant-distill]].
- [[03-applied/15-prompt-vs-semantic-caching|Prompt caching]] (cache hit). Voir [[03-applied/15-prompt-vs-semantic-caching]].
- Réduction du context ([[03-applied/14-context-engineering]]).
- [[01-architecture/03-flash-attention|FlashAttention]], [[02-inference/08-kv-cache-management|paged attention]] (côté serving).
- Streaming pour la latency perçue.
- Co-location géographique.

## Quality

Composants :
- Base model capability.
- Prompt design.
- Context relevance (RAG).
- Tool reliability.
- Eval-driven iteration.

Leviers :
- Plus gros modèle.
- Meilleur retrieved context. Voir [[04-retrieval-quality/20-rag-architecture]].
- [[06-meta/27-ft-vs-icl-vs-rag-vs-distill|Few-shot examples]].
- [[03-applied/18-agent-guardrails|Reflection]] / self-critique.
- Multi-judge / ensemble.

## Cost

Composants :
- Tokens input + output × model price.
- Retrieval infra (vector store, embed compute).
- Tool exec cost (downstream APIs).
- Observability / logging storage.

Leviers :
- Petit modèle où possible (routing). Voir [[03-applied/19-model-routing-fallback]].
- Caching (prompt, semantic).
- [[02-inference/11-speculative-quant-distill|Distillation]].
- [[02-inference/12-quantization-deep-dive|Quantization]].
- Output max_tokens calibré.
- Batch processing offline.

## Reliability

Composants :
- Provider uptime.
- [[03-applied/19-model-routing-fallback|Rate limits]].
- Schema validation pass rate.
- Tool success rate.
- Agent termination correctness.

Leviers :
- [[03-applied/16-structured-outputs|Fallback chains]].
- [[03-applied/19-model-routing-fallback|Hedging]].
- [[03-applied/19-model-routing-fallback|Circuit breakers]].
- Repair loops. Voir [[03-applied/16-structured-outputs]].
- [[03-applied/19-model-routing-fallback|Multi-provider]].

## Les trade-offs concrets

**Quality ↔ Cost**
- Plus gros modèle = qualité supérieure + coût supérieur. Choix de routing.

**Quality ↔ Latency**
- Reflection / self-critique = qualité supérieure + latency supérieure (1 call de plus).
- [[04-retrieval-quality/20-rag-architecture|Cross-encoder reranker]] = retrieval supérieur + 100-200ms de latency ajoutée.

**Cost ↔ Latency**
- Hedging (lancer sur 2 providers) = p99 latency réduite + cost ×2.
- Prompt caching = amélioration des deux (mais courbe d'apprentissage).

**Quality ↔ Reliability**
- Plus de fallbacks = reliability supérieure mais réponses dégradées plus fréquemment.
- Schema strict = reliability supérieure + plus de schema failures → repair loops.

**Cost ↔ Reliability**
- Fallback chain à 4 niveaux = reliability supérieure + worst-case cost = somme des modèles.
- Hedging = reliability supérieure + 2x cost sur certaines requêtes.

## Pareto frontier

Le système opère sur une Pareto frontier. Améliorer une dimension dégrade une autre.

Exceptions (gains gratuits) :
- FlashAttention.
- [[02-inference/10-continuous-batching-paged-attention|Continuous batching]]. Voir [[02-inference/10-continuous-batching-paged-attention]].
- Paged attention.
- Speculative decoding (lossless).
- Prompt caching.

Lorsqu'un gain gratuit est disponible, il doit être pris. Le reste relève de la négociation.

## Cas pratique : choix d'architecture

### Use case 1 : chatbot support customer, B2B SaaS

100k req/jour, SLA p99 < 3s, cost target $0.01/req.

Choix :
- Routing classifier-based : 80% queries simples → Mistral Small, 20% complexes → Large.
- RAG [[04-retrieval-quality/20-rag-architecture|hybrid search]] + reranker (qualité +30%).
- Prompt caching sur system prompt + docs (cost ×0.3 sur cache hits).
- Continuous batching côté serving.
- Repair loop max 2 retries.
- Fallback Small si Large timeout > 2s.

### Use case 2 : agent autonome multi-step

1000 sessions/jour, SLA p99 < 60s/session, cost target $0.50/session.

Choix :
- Mistral Large par défaut (quality > latency unitaire).
- Strict budgets : max 20 iter, max $0.50. Voir [[03-applied/18-agent-guardrails]].
- Tool layer avec idempotency.
- [[03-applied/18-agent-guardrails|Stuck detection]].
- Observability dense (chaque step traced). Voir [[05-ops-safety/23-llm-observability]].
- [[03-applied/18-agent-guardrails|Approval gates]] sur actions critiques.

## Vocabulaire clé

`latency budget`, `quality bar`, `cost target`, `reliability SLA`, `Pareto frontier`, `routing`, `tradeoff`, `gain gratuit`, `bottleneck`, `goodput`.

## Synthèse

Quatre dimensions à tuner : latency, quality, cost, reliability. Aucune maximisation simultanée possible — on choisit un point. Certains gains sont gratuits — FlashAttention, continuous batching, paged attention, speculative decoding, prompt caching — toujours à prendre. Le reste relève de la négociation : plus gros modèle = quality up, cost up. Reflection = quality up, latency up. Hedging = reliability et tail latency up, cost ×2. Fallback chain = reliability up mais worst-case cost = somme des modèles. Pour choisir, on part du use case : SLAs strictes pour chat interactif, throughput pour batch offline, agent autonome où quality > latency individuelle. L'architecture résultante combine routing + caching + serving optim + budget enforcement, pas un seul levier.
