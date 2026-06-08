---
title: "Frontier LLM Systems"
description: "Wiki en français sur les LLM frontier et leur mise en production : architecture, inference, harness applicatif, retrieval, ops, safety, choix stratégiques (modèle, déploiement, fine-tuning)."
tags:
  - index
---

> [!abstract] Comment lire ce wiki
> Les notes sont **numérotées dans l'ordre d'apprentissage** : `01 → 37` part de l'architecture du Transformer pour arriver aux choix stratégiques (modèle, déploiement, fine-tuning, on-prem) et aux paradigmes émergents (reasoning, multimodal, MCP, EU AI Act). On peut lire en séquence, ou attaquer un **parcours** ciblé (voir plus bas).

Une ressource pour apprendre comment fonctionnent les modèles LLM frontier et comment ils sont mis en production. Chaque note est atomique, auto-suffisante, lisible en 5-10 minutes, et reliée aux notes connexes via wikilinks.

## Pour qui

- Ingénieur·e logiciel qui veut comprendre ce qu'il y a derrière une API LLM.
- ML/AI engineer qui shippe des features LLM et qui veut un référentiel complet.
- Curieux·se technique qui veut un mental model solide du domaine sans lire 30 papers.

## Pour quoi

Couvrir, en français, le vocabulaire et les concepts canoniques de l'industrie : ceux qui circulent dans les papers, la documentation des providers (Mistral, OpenAI, Anthropic), les serving stacks (vLLM, TensorRT-LLM, SGLang), et les outils d'observability. Les termes anglais sont conservés tels quels, parce que c'est ainsi qu'ils sont utilisés partout.

## Comment naviguer

- **Une note = un concept.**
- **Wikilinks** `[[nom-de-fichier]]` pour passer d'un concept à un autre.
- **Tags** (cliquables en haut de chaque note) regroupent les notes d'un même cluster : `#architecture`, `#inference`, `#applied`, `#retrieval-quality`, `#ops-safety`, `#meta`.
- **Backlinks** (colonne droite) montrent qui pointe vers la note courante.
- **Graphe** (colonne droite) visualise les voisins immédiats.
- **Vocabulaire clé** en fin de chaque note : les termes à connaître.
- **Synthèse** en fin de chaque note : résumé condensé.
- Glossaire global : [[_vocab|_vocab.md]] (alphabétique, avec liens vers la note source).

## Parcours suggérés

> [!tip] Choisis ton entrée
> Chaque parcours est cohérent end-to-end. Si tu n'as pas d'a priori, prends **fondamentaux** d'abord.

**Parcours "fondamentaux" (~6h)** — bâtir un mental model des LLM
[[01-architecture/01-transformer-architecture]] → [[01-architecture/02-position-encodings]] → [[01-architecture/03-flash-attention]] → [[01-architecture/04-tokenization]] → [[01-architecture/05-mixture-of-experts]] → [[01-architecture/06-distributed-training]] → [[01-architecture/07-post-training-alignment]]

**Parcours "inference et serving" (~5h)** — comprendre comment un modèle est servi à scale
[[02-inference/08-kv-cache-management]] → [[02-inference/09-prefill-vs-decode]] → [[02-inference/10-continuous-batching-paged-attention]] → [[02-inference/11-speculative-quant-distill]] → [[02-inference/12-quantization-deep-dive]]

**Parcours "applied" (~7h)** — shipper des features LLM en production
[[03-applied/13-harness-engineering]] → [[03-applied/14-context-engineering]] → [[03-applied/15-prompt-vs-semantic-caching]] → [[03-applied/16-structured-outputs]] → [[03-applied/17-function-calling-reliability]] → [[03-applied/18-agent-guardrails]] → [[03-applied/19-model-routing-fallback]] → [[04-retrieval-quality/20-rag-architecture]]

**Parcours "qualité et opérations" (~5h)**
[[04-retrieval-quality/21-retrieval-evals]] → [[04-retrieval-quality/22-evals]] → [[05-ops-safety/23-llm-observability]] → [[05-ops-safety/24-cost-attribution]] → [[05-ops-safety/25-safety-engineering]] → [[05-ops-safety/26-multi-tenant-isolation]]

**Parcours "synthèse" (~2h)** — à lire en dernier
[[06-meta/27-ft-vs-icl-vs-rag-vs-distill]] → [[06-meta/28-tradeoffs]] → [[06-meta/29-production-failure-modes]]

**Parcours "choix stratégiques" (~4h)** — quelle famille de modèle, où le déployer, comment le fine-tuner, et comment construire un cluster on-prem
[[06-meta/30-open-vs-closed-source]] → [[06-meta/31-on-prem-vs-cloud]] → [[06-meta/32-fine-tuning-en-pratique]] → [[06-meta/33-on-premise-en-pratique]]

**Parcours "paradigmes émergents 2025-2026" (~4h)** — reasoning, multimodal, MCP, régulation
[[06-meta/34-reasoning-models]] → [[06-meta/35-multimodal]] → [[06-meta/36-mcp-agent-protocols]] → [[06-meta/37-eu-ai-act]]

## Plan thématique

### Architecture des modèles · `#architecture`

1. [[01-architecture/01-transformer-architecture]] — Self-attention, MHA/MQA/GQA, FFN, normalisations
2. [[01-architecture/02-position-encodings]] — RoPE, ALiBi, YaRN, sliding window, alternatives
3. [[01-architecture/03-flash-attention]] — Tiling, online softmax, memory I/O
4. [[01-architecture/04-tokenization]] — BPE, SentencePiece, Tiktoken, multilingue
5. [[01-architecture/05-mixture-of-experts]] — Routing, expert capacity, Mixtral, DeepSeek
6. [[01-architecture/06-distributed-training]] — DP, ZeRO, FSDP, TP, PP, mixed precision
7. [[01-architecture/07-post-training-alignment]] — SFT, RLHF, DPO, Constitutional AI

### Inference et serving · `#inference`

8. [[02-inference/08-kv-cache-management]] — Mémoire, fragmentation, eviction
9. [[02-inference/09-prefill-vs-decode]] — Compute-bound vs memory-bound
10. [[02-inference/10-continuous-batching-paged-attention]] — Throughput optimization
11. [[02-inference/11-speculative-quant-distill]] — Trois familles d'accélération
12. [[02-inference/12-quantization-deep-dive]] — INT8, INT4, FP8, GPTQ, AWQ

### Engineering autour du modèle · `#applied`

13. [[03-applied/13-harness-engineering]] — Le système qui entoure le modèle
14. [[03-applied/14-context-engineering]] — Sélectionner ce qui rentre dans le contexte
15. [[03-applied/15-prompt-vs-semantic-caching]] — Deux types de cache distincts
16. [[03-applied/16-structured-outputs]] — Schemas, repair loops, fallback
17. [[03-applied/17-function-calling-reliability]] — Tool contracts, idempotency
18. [[03-applied/18-agent-guardrails]] — Budgets, termination, stuck detection
19. [[03-applied/19-model-routing-fallback]] — Router une gamme de modèles

### Retrieval et qualité · `#retrieval-quality`

20. [[04-retrieval-quality/20-rag-architecture]] — Chunking, hybrid search, reranking
21. [[04-retrieval-quality/21-retrieval-evals]] — Recall, grounding, attribution
22. [[04-retrieval-quality/22-evals]] — Golden sets, adversarial, LLM-as-judge

### Operations et sécurité · `#ops-safety`

23. [[05-ops-safety/23-llm-observability]] — Traces, spans, drift
24. [[05-ops-safety/24-cost-attribution]] — Par feature, workflow, tenant
25. [[05-ops-safety/25-safety-engineering]] — Prompt injection, data leakage, permissions
26. [[05-ops-safety/26-multi-tenant-isolation]] — Cache safety, cross-user contamination

### Mise en perspective et choix stratégiques · `#meta`

27. [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]] — Decision framework
28. [[06-meta/28-tradeoffs]] — Latency / quality / cost / reliability
29. [[06-meta/29-production-failure-modes]] — Le bestiaire des défaillances
30. [[06-meta/30-open-vs-closed-source]] — Open weights vs closed API, comparatif des labs frontier
31. [[06-meta/31-on-prem-vs-cloud]] — Quatre niveaux de déploiement, drivers réels
32. [[06-meta/32-fine-tuning-en-pratique]] — LoRA, QLoRA, datasets, hyperparamètres, outillage
33. [[06-meta/33-on-premise-en-pratique]] — Hardware, réseau, datacenter, stack software, compliance
34. [[06-meta/34-reasoning-models]] — o1/o3, DeepSeek R1, Magistral, QwQ, test-time compute scaling
35. [[06-meta/35-multimodal]] — Vision (Pixtral, GPT-4o, Gemini), audio (Voxtral, Whisper, TTS)
36. [[06-meta/36-mcp-agent-protocols]] — Model Context Protocol, gouvernance Linux Foundation
37. [[06-meta/37-eu-ai-act]] — Classifications, GPAI 10²⁵ FLOPs, obligations, postures des labs

## Clusters (graphe Obsidian)

- **Inference internals** : [[02-inference/08-kv-cache-management]] ↔ [[02-inference/09-prefill-vs-decode]] ↔ [[02-inference/10-continuous-batching-paged-attention]] ↔ [[01-architecture/03-flash-attention]] ↔ [[02-inference/12-quantization-deep-dive]]
- **Model architecture** : [[01-architecture/01-transformer-architecture]] ↔ [[01-architecture/02-position-encodings]] ↔ [[01-architecture/05-mixture-of-experts]] ↔ [[01-architecture/06-distributed-training]]
- **Harness applied** : [[03-applied/13-harness-engineering]] ↔ [[03-applied/14-context-engineering]] ↔ [[03-applied/16-structured-outputs]] ↔ [[03-applied/17-function-calling-reliability]] ↔ [[03-applied/18-agent-guardrails]] ↔ [[03-applied/19-model-routing-fallback]]
- **Retrieval** : [[04-retrieval-quality/20-rag-architecture]] ↔ [[04-retrieval-quality/21-retrieval-evals]] ↔ [[04-retrieval-quality/22-evals]] ↔ [[03-applied/15-prompt-vs-semantic-caching]]
- **Operations** : [[05-ops-safety/23-llm-observability]] ↔ [[05-ops-safety/24-cost-attribution]] ↔ [[06-meta/29-production-failure-modes]]
- **Safety** : [[05-ops-safety/25-safety-engineering]] ↔ [[05-ops-safety/26-multi-tenant-isolation]] ↔ [[03-applied/15-prompt-vs-semantic-caching]]
- **Méta** : [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]] ↔ [[06-meta/28-tradeoffs]] ↔ [[06-meta/29-production-failure-modes]] ↔ [[01-architecture/07-post-training-alignment]]
- **Stratégie de déploiement** : [[06-meta/30-open-vs-closed-source]] ↔ [[06-meta/31-on-prem-vs-cloud]] ↔ [[06-meta/32-fine-tuning-en-pratique]] ↔ [[06-meta/33-on-premise-en-pratique]] ↔ [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]] ↔ [[03-applied/19-model-routing-fallback]] ↔ [[05-ops-safety/26-multi-tenant-isolation]]
- **Paradigmes émergents 2025-2026** : [[06-meta/34-reasoning-models]] ↔ [[06-meta/35-multimodal]] ↔ [[06-meta/36-mcp-agent-protocols]] ↔ [[06-meta/37-eu-ai-act]] ↔ [[01-architecture/07-post-training-alignment]] ↔ [[03-applied/17-function-calling-reliability]]

> [!note] Notes
> Les anciens slugs (`01-harness-engineering`, etc.) redirigent automatiquement vers les nouveaux via le plugin `alias-redirects` — pas de lien externe cassé.
