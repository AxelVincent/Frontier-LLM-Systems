---
title: "Glossaire"
description: "Glossaire alphabétique des termes anglais canoniques, avec lien vers la fiche source."
tags:
  - reference
aliases:
  - vocab
  - glossaire
---

> [!abstract] Format
> Tous les termes anglais canoniques, classés par ordre alphabétique.
> Format : `terme` — sens court — [[fiche-source]]

## A

- `acceptance rate` — % de tokens acceptés du draft model en speculative decoding — [[02-inference/11-speculative-quant-distill]]
- `adapter` (LoRA) — modules bas-rang ajoutés sur base frozen — [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]]
- `adversarial test` — case designed pour casser — [[04-retrieval-quality/22-evals]]
- `agent loop` — event loop d'orchestration {model → tool → observation} — [[03-applied/13-harness-engineering]] · [[03-applied/18-agent-guardrails]]
- `AI feedback` — feedback généré par un modèle (Constitutional AI) — [[01-architecture/07-post-training-alignment]]
- `ALiBi` — position encoding via biais linéaire — [[01-architecture/02-position-encodings]]
- `all-reduce` — communication collective de sommation — [[01-architecture/06-distributed-training]]
- `all-to-all` — communication MoE expert parallelism — [[01-architecture/05-mixture-of-experts]] · [[01-architecture/06-distributed-training]]
- `AMP` (Automatic Mixed Precision) — API PyTorch mixed precision — [[01-architecture/06-distributed-training]]
- `answer relevancy` — la réponse adresse-t-elle la question — [[04-retrieval-quality/21-retrieval-evals]]
- `approval gate` — confirmation user requise avant action critique — [[03-applied/18-agent-guardrails]]
- `arithmetic intensity` — ratio compute / memory access — [[02-inference/09-prefill-vs-decode]]
- `attention dilution` — perte d'attention sur long context — [[03-applied/14-context-engineering]]
- `attribution` — citation explicite des sources — [[04-retrieval-quality/21-retrieval-evals]]
- `auxiliary-loss-free balancing` — load balancing MoE sans loss auxiliaire (DeepSeek-V3) — [[01-architecture/05-mixture-of-experts]]
- `AWQ` — Activation-aware Weight Quantization — [[02-inference/12-quantization-deep-dive]]

## B

- `Bradley-Terry` — modèle de préférence en RLHF — [[01-architecture/07-post-training-alignment]]
- `BF16` — brain float 16, range FP32 / précision réduite — [[02-inference/12-quantization-deep-dive]] · [[01-architecture/06-distributed-training]]
- `bi-encoder` — embedding query et chunk séparément — [[04-retrieval-quality/20-rag-architecture]]
- `block size` — taille des pages KV — [[02-inference/08-kv-cache-management]]
- `BM25` — sparse retrieval TF-IDF — [[04-retrieval-quality/20-rag-architecture]]
- `BNB` (bitsandbytes) — lib quantization — [[02-inference/12-quantization-deep-dive]]
- `BOS` (Beginning Of Sequence) — token de début — [[01-architecture/04-tokenization]]
- `BPE` (Byte-Pair Encoding) — algorithme de tokenization — [[01-architecture/04-tokenization]]
- `bubble` — gap idle en pipeline parallelism — [[01-architecture/06-distributed-training]]
- `budget enforcement` — kill switch sur dépassement — [[03-applied/18-agent-guardrails]] · [[05-ops-safety/24-cost-attribution]]
- `byte-level BPE` — BPE sur les bytes — [[01-architecture/04-tokenization]]
- `byte-level fallback` — decomposition en bytes si OOV — [[01-architecture/04-tokenization]]

## C

- `cache breakpoint` — marqueur fin de prefix cachable — [[03-applied/15-prompt-vs-semantic-caching]]
- `cache hit ratio` — % requêtes servies du cache — [[03-applied/15-prompt-vs-semantic-caching]]
- `cache poisoning` — cache contaminé cross-user — [[06-meta/29-production-failure-modes]]
- `calibration` (alignment) — confiance reflète l'incertitude — [[01-architecture/07-post-training-alignment]]
- `calibration set` — dataset pour calibrer quantization — [[02-inference/12-quantization-deep-dive]]
- `capacity factor` — multiplicateur de l'expert capacity (MoE) — [[01-architecture/05-mixture-of-experts]]
- `cardinality` — # valeurs distinctes d'un tag — [[05-ops-safety/24-cost-attribution]]
- `cascade routing` — try small puis fallback large — [[03-applied/19-model-routing-fallback]]
- `catastrophic forgetting` — fine-tune efface skills initiaux — [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]]
- `causal mask` — masque pour decoder-only — [[01-architecture/01-transformer-architecture]]
- `chunked prefill` — prefill split en morceaux — [[02-inference/09-prefill-vs-decode]] · [[02-inference/10-continuous-batching-paged-attention]]
- `chunking` — découpage doc en chunks — [[04-retrieval-quality/20-rag-architecture]]
- `circuit breaker` — écarter provider qui échoue — [[03-applied/19-model-routing-fallback]]
- `citation accuracy` — citation pointe au bon contenu — [[04-retrieval-quality/21-retrieval-evals]]
- `classifier-based routing` — classifie query → route — [[03-applied/19-model-routing-fallback]]
- `compaction` — compresser tours anciens — [[03-applied/14-context-engineering]]
- `compensating action` — annule l'effet d'une partial failure — [[03-applied/17-function-calling-reliability]] · [[06-meta/29-production-failure-modes]]
- `compute-bound` — bottleneck = TFLOPS — [[02-inference/09-prefill-vs-decode]]
- `concept drift` — distribution des inputs change — [[05-ops-safety/23-llm-observability]]
- `confabulation` — invention de faits sous pression — [[01-architecture/07-post-training-alignment]]
- `constrained decoding` — sampler limité par grammaire — [[03-applied/16-structured-outputs]]
- `Constitutional AI` — alignment via constitution — [[01-architecture/07-post-training-alignment]]
- `context engineering` — sélectionner ce qui rentre — [[03-applied/14-context-engineering]]
- `context parallelism` — split de la dimension séquence — [[01-architecture/06-distributed-training]]
- `context relevancy` — chunks pertinents pour la question — [[04-retrieval-quality/21-retrieval-evals]]
- `contextualized chunks` — chunk préfixé de son origine — [[04-retrieval-quality/20-rag-architecture]]
- `continuous batching` — scheduling iteration-level — [[02-inference/10-continuous-batching-paged-attention]]
- `cosine similarity` — métrique embedding — [[04-retrieval-quality/20-rag-architecture]]
- `cost attribution` — décomposition du coût — [[05-ops-safety/24-cost-attribution]]
- `cost budget` — max $ par session — [[03-applied/18-agent-guardrails]] · [[05-ops-safety/24-cost-attribution]]
- `cross-attention` — attention encoder → decoder — [[01-architecture/01-transformer-architecture]]
- `cross-encoder` — query et chunk dans un transformer — [[04-retrieval-quality/20-rag-architecture]]
- `cross-tenant leak` — fuite entre tenants — [[05-ops-safety/26-multi-tenant-isolation]]
- `cross-user contamination` — fuite entre users — [[05-ops-safety/26-multi-tenant-isolation]]

## D

- `data exfiltration` — leak data via prompt injection — [[05-ops-safety/25-safety-engineering]]
- `data leakage` — PII exposé indûment — [[05-ops-safety/25-safety-engineering]]
- `data parallelism` (DP) — duplication du modèle, split des données — [[01-architecture/06-distributed-training]]
- `DDP` (Distributed Data Parallel) — implémentation PyTorch de DP — [[01-architecture/06-distributed-training]]
- `decode` — phase autoregressive memory-bound — [[02-inference/09-prefill-vs-decode]]
- `degraded mode` — service fonctionne partiellement — [[03-applied/19-model-routing-fallback]]
- `dense retrieval` — search par embeddings — [[04-retrieval-quality/20-rag-architecture]]
- `disaggregated serving` — prefill et decode sur GPUs séparés — [[02-inference/09-prefill-vs-decode]]
- `distillation` — student imite teacher — [[02-inference/11-speculative-quant-distill]]
- `DPO` (Direct Preference Optimization) — alignment sans reward model — [[01-architecture/07-post-training-alignment]]
- `draft model` — petit modèle pour speculative — [[02-inference/11-speculative-quant-distill]]
- `drift detection` — repérer changement distribution — [[05-ops-safety/23-llm-observability]]

## E

- `EAGLE` — speculative decoding via head supplémentaire — [[02-inference/11-speculative-quant-distill]]
- `embedding drift` — distance entre embeddings sur périodes — [[05-ops-safety/23-llm-observability]]
- `embeddings` — vecteurs sémantiques — [[04-retrieval-quality/20-rag-architecture]]
- `EOS` (End Of Sequence) — token de fin — [[01-architecture/04-tokenization]]
- `eval harness` — framework qui run les evals — [[04-retrieval-quality/22-evals]]
- `event loop` — orchestration agent — [[03-applied/13-harness-engineering]]
- `eviction` — virer du cache — [[02-inference/08-kv-cache-management]]
- `expert capacity` — limite tokens par expert MoE — [[01-architecture/05-mixture-of-experts]]
- `expert parallelism` — experts MoE distribués sur GPUs — [[01-architecture/05-mixture-of-experts]] · [[01-architecture/06-distributed-training]]

## F

- `faithfulness` — réponse supportée par le contexte — [[04-retrieval-quality/21-retrieval-evals]]
- `fallback chain` — séquence de fallbacks — [[03-applied/16-structured-outputs]] · [[03-applied/19-model-routing-fallback]]
- `few-shot` — exemples dans le prompt — [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]]
- `FFN` (Feed-Forward Network) — sous-bloc MLP du Transformer — [[01-architecture/01-transformer-architecture]]
- `fine-grained experts` — petits experts nombreux (DeepSeek) — [[01-architecture/05-mixture-of-experts]]
- `fine-tuning` — update weights — [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]]
- `finish_reason` — pourquoi le decode s'arrête — [[05-ops-safety/23-llm-observability]]
- `finite-state machine` — base de constrained decoding — [[03-applied/16-structured-outputs]]
- `FlashAttention` — attention exact avec tiling — [[01-architecture/03-flash-attention]]
- `FlashDecoding` — variante FlashAttention pour decode — [[01-architecture/03-flash-attention]]
- `FP8` (E4M3, E5M2) — format quantization moderne — [[02-inference/12-quantization-deep-dive]] · [[01-architecture/06-distributed-training]]
- `FP16` — float 16 standard — [[02-inference/12-quantization-deep-dive]] · [[01-architecture/06-distributed-training]]
- `fragmentation` (VRAM) — gaspillage d'allocation — [[02-inference/08-kv-cache-management]]
- `freshness` — fraîcheur des chunks — [[04-retrieval-quality/20-rag-architecture]]
- `FSDP` (Fully Sharded Data Parallel) — équivalent PyTorch de ZeRO-3 — [[01-architecture/06-distributed-training]]
- `function calling` — modèle choisit tool + args — [[03-applied/17-function-calling-reliability]]

## G

- `GELU` — activation Gaussian Error Linear Unit — [[01-architecture/01-transformer-architecture]]
- `gen_ai semantic conventions` — schema OpenTelemetry pour LLM — [[05-ops-safety/23-llm-observability]]
- `GGUF` — format fichier llama.cpp — [[02-inference/12-quantization-deep-dive]]
- `golden set` — dataset référence pour evals — [[04-retrieval-quality/22-evals]]
- `goodput` — tokens utiles dans SLA — [[02-inference/10-continuous-batching-paged-attention]]
- `GPipe` — schedule pipeline parallelism — [[01-architecture/06-distributed-training]]
- `GPTQ` — Generalized Post-Training Quantization — [[02-inference/12-quantization-deep-dive]]
- `GQA` (Grouped Query Attention) — partage K/V entre groupes de heads — [[01-architecture/01-transformer-architecture]] · [[02-inference/08-kv-cache-management]]
- `graceful degradation` — fail gracefully — [[03-applied/16-structured-outputs]] · [[03-applied/19-model-routing-fallback]]
- `grammar-constrained sampling` — sampling avec grammaire — [[03-applied/16-structured-outputs]]
- `grounding` — chaque claim trace à une source — [[04-retrieval-quality/21-retrieval-evals]]
- `guided decoding` — synonyme constrained decoding — [[03-applied/16-structured-outputs]]

## H

- `hallucinated tool call` — modèle invente un tool — [[06-meta/29-production-failure-modes]]
- `hallucination` — invention factuelle — [[01-architecture/07-post-training-alignment]]
- `hard limit` — budget non-négociable — [[03-applied/18-agent-guardrails]]
- `harness` — système autour du modèle — [[03-applied/13-harness-engineering]]
- `HBM` — High Bandwidth Memory (VRAM GPU) — [[02-inference/08-kv-cache-management]] · [[01-architecture/03-flash-attention]]
- `hedging` — lancer 2 providers en parallèle — [[03-applied/19-model-routing-fallback]]
- `hit rate` — au moins 1 chunk pertinent dans top-k — [[04-retrieval-quality/21-retrieval-evals]]
- `HNSW` — Hierarchical Navigable Small World — [[04-retrieval-quality/20-rag-architecture]]
- `hybrid search` — dense + sparse fusionnés — [[04-retrieval-quality/20-rag-architecture]]

## I

- `ICL` (in-context learning) — apprendre via prompt — [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]]
- `idempotency key` — hash pour dédup — [[03-applied/17-function-calling-reliability]]
- `in-flight batching` — synonyme continuous batching — [[02-inference/10-continuous-batching-paged-attention]]
- `inline citations` — sources dans le texte — [[04-retrieval-quality/21-retrieval-evals]]
- `input filtering` — classifier pour bloquer inputs — [[05-ops-safety/25-safety-engineering]]
- `instruction reinforcement` — répéter instructions critiques — [[05-ops-safety/25-safety-engineering]]
- `instruction tuning` — SFT sur diversité d'instructions — [[01-architecture/07-post-training-alignment]]
- `inter-token latency` — synonyme TPOT — [[02-inference/09-prefill-vs-decode]]
- `interleaved 1F1B` — schedule pipeline parallelism — [[01-architecture/06-distributed-training]]
- `IPO` (Identity Preference Optimization) — variante DPO — [[01-architecture/07-post-training-alignment]]
- `IVF` — Inverted File Index — [[04-retrieval-quality/20-rag-architecture]]

## J

- `jailbreak` — bypass des safety — [[05-ops-safety/25-safety-engineering]] · [[06-meta/29-production-failure-modes]]
- `JSON mode` — output JSON garanti syntaxiquement — [[03-applied/16-structured-outputs]]
- `JSON schema` — schéma de structure — [[03-applied/16-structured-outputs]]

## K

- `KL penalty` / `KL divergence` — terme régularisation RLHF — [[01-architecture/07-post-training-alignment]]
- `KS test` — Kolmogorov-Smirnov, test distrib — [[05-ops-safety/23-llm-observability]]
- `KTO` (Kahneman-Tversky Optimization) — alignment sur signaux unaires — [[01-architecture/07-post-training-alignment]]
- `KV cache` — Keys + Values en mémoire — [[02-inference/08-kv-cache-management]]
- `KV cache quantization` — KV en INT8/INT4 — [[02-inference/08-kv-cache-management]]

## L

- `Lakera` — provider input filtering — [[05-ops-safety/25-safety-engineering]]
- `Langfuse` — observability LLM open-source — [[05-ops-safety/23-llm-observability]]
- `LangSmith` — observability LangChain — [[05-ops-safety/23-llm-observability]]
- `late chunking` — chunk après embed du doc complet — [[04-retrieval-quality/20-rag-architecture]]
- `latency budget` — total time autorisé — [[06-meta/28-tradeoffs]]
- `LayerNorm` — normalisation par feature — [[01-architecture/01-transformer-architecture]]
- `length bias` — judge favorise plus long — [[04-retrieval-quality/22-evals]]
- `LLM-as-judge` — LLM évalue output — [[04-retrieval-quality/21-retrieval-evals]] · [[04-retrieval-quality/22-evals]]
- `LLM.int8` — Dettmers, gestion outliers W8A8 — [[02-inference/12-quantization-deep-dive]]
- `load balancing loss` — auxiliary loss pour MoE — [[01-architecture/05-mixture-of-experts]]
- `logit distillation` — student apprend logits du teacher — [[02-inference/11-speculative-quant-distill]]
- `lookahead decoding` — self-speculative — [[02-inference/11-speculative-quant-distill]]
- `loop budget` — max iterations — [[03-applied/18-agent-guardrails]]
- `LoRA` / `QLoRA` — adapters bas-rang — [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]]
- `loss scaling` — multiplier loss en FP16 contre underflow — [[01-architecture/06-distributed-training]]
- `lost in the middle` — biais attention début/fin — [[03-applied/14-context-engineering]]
- `LRU eviction` — Least Recently Used — [[02-inference/08-kv-cache-management]]
- `LTV/CAC` — unit economics — [[05-ops-safety/24-cost-attribution]]

## M

- `Mamba` — architecture SSM alternative au Transformer — [[01-architecture/02-position-encodings]]
- `matryoshka embeddings` — embeddings tronquables — [[04-retrieval-quality/20-rag-architecture]]
- `max iterations` — synonyme loop budget — [[03-applied/18-agent-guardrails]]
- `Medusa` — speculative decoding multi-head — [[02-inference/11-speculative-quant-distill]]
- `Megatron` — pattern tensor parallelism — [[01-architecture/06-distributed-training]]
- `memory layer` — store de faits durables — [[03-applied/14-context-engineering]]
- `memory-bound` — bottleneck = bande passante — [[02-inference/09-prefill-vs-decode]]
- `MFU` — Model FLOPs Utilization — [[02-inference/10-continuous-batching-paged-attention]]
- `MHA` (Multi-Head Attention) — attention multi-heads standard — [[01-architecture/01-transformer-architecture]]
- `micro-batch` — sous-batch en pipeline parallelism — [[01-architecture/06-distributed-training]]
- `mixed precision` — combinaison FP32/FP16/BF16/FP8 — [[01-architecture/06-distributed-training]]
- `Mixtral` — MoE de Mistral, 8x7B / 8x22B — [[01-architecture/05-mixture-of-experts]]
- `MLA` (Multi-head Latent Attention) — cache compressé (DeepSeek) — [[01-architecture/01-transformer-architecture]]
- `MLP` — synonyme FFN — [[01-architecture/01-transformer-architecture]]
- `MoE` (Mixture of Experts) — experts parallèles + router — [[01-architecture/05-mixture-of-experts]]
- `model router` — routage par requête — [[03-applied/19-model-routing-fallback]]
- `MQA` (Multi-Query Attention) — un seul KV head — [[01-architecture/01-transformer-architecture]] · [[02-inference/08-kv-cache-management]]
- `MRR` — Mean Reciprocal Rank — [[04-retrieval-quality/21-retrieval-evals]]
- `MTTD/MTTR` — Mean Time To Detect/Recover — [[06-meta/29-production-failure-modes]]
- `multi-provider` — utiliser plusieurs APIs — [[03-applied/19-model-routing-fallback]]
- `multilingual tokenization` — tokenization équilibrée entre langues — [[01-architecture/04-tokenization]]

## N

- `namespace` (vector store) — isolation logique — [[05-ops-safety/26-multi-tenant-isolation]]
- `NDCG` — Normalized Discounted Cumulative Gain — [[04-retrieval-quality/21-retrieval-evals]]
- `needle in a haystack` — test retrieval long context — [[03-applied/14-context-engineering]] · [[01-architecture/02-position-encodings]]
- `NoPE` — pas d'encodage de position — [[01-architecture/02-position-encodings]]
- `NTK-aware scaling` — extension RoPE pour long context — [[01-architecture/02-position-encodings]]

## O

- `offloading` — KV sur CPU RAM/NVMe — [[02-inference/08-kv-cache-management]]
- `online softmax` — softmax incrémental (FlashAttention) — [[01-architecture/03-flash-attention]]
- `OOV` (Out-Of-Vocabulary) — token absent du vocab — [[01-architecture/04-tokenization]]
- `OpenTelemetry` — standard tracing — [[05-ops-safety/23-llm-observability]]
- `ORPO` (Odds Ratio Preference Optimization) — SFT + preference en une étape — [[01-architecture/07-post-training-alignment]]
- `outlier` (activation) — valeurs énormes qui cassent la quant — [[02-inference/12-quantization-deep-dive]]
- `outlines` — lib constrained decoding — [[03-applied/16-structured-outputs]]
- `output drift` — distribution des outputs change — [[05-ops-safety/23-llm-observability]]
- `output filtering` — scan avant return — [[05-ops-safety/25-safety-engineering]]

## P

- `p50/p99` — latency percentiles — [[05-ops-safety/23-llm-observability]]
- `PagedAttention` — KV en pages, vLLM — [[02-inference/08-kv-cache-management]] · [[02-inference/10-continuous-batching-paged-attention]]
- `pairwise comparison` — A vs B en LLM-as-judge — [[04-retrieval-quality/22-evals]]
- `Pareto frontier` — courbe tradeoff — [[06-meta/28-tradeoffs]]
- `partial failure` — tool fait 2/3 actions — [[03-applied/17-function-calling-reliability]] · [[06-meta/29-production-failure-modes]]
- `per-channel/per-group` — granularité quant — [[02-inference/12-quantization-deep-dive]]
- `permission boundary` — limite des actions autorisées — [[03-applied/17-function-calling-reliability]] · [[05-ops-safety/25-safety-engineering]]
- `PII` — Personal Identifiable Information — [[05-ops-safety/25-safety-engineering]]
- `pipeline parallelism` (PP) — layers split entre GPUs — [[01-architecture/06-distributed-training]]
- `Plan-and-Execute` — pattern d'agent — [[03-applied/13-harness-engineering]]
- `policy` — modèle entraîné en RL — [[01-architecture/07-post-training-alignment]]
- `position interpolation` (PI) — RoPE scaling par interpolation — [[01-architecture/02-position-encodings]]
- `position bias` — judge favorise premier — [[04-retrieval-quality/22-evals]]
- `positional encoding` — encodage de position — [[01-architecture/02-position-encodings]]
- `post-norm` — normalisation après sublayer — [[01-architecture/01-transformer-architecture]]
- `post-training` — phase après pre-training — [[01-architecture/07-post-training-alignment]]
- `PPO` (Proximal Policy Optimization) — RL algorithm pour RLHF — [[01-architecture/07-post-training-alignment]]
- `PQ` — Product Quantization — [[04-retrieval-quality/20-rag-architecture]]
- `pre-norm` — normalisation avant sublayer — [[01-architecture/01-transformer-architecture]]
- `pre-training` — phase next-token prediction — [[01-architecture/07-post-training-alignment]]
- `precision@k` — % top-k pertinents — [[04-retrieval-quality/21-retrieval-evals]]
- `prefill` — phase initiale compute-bound — [[02-inference/09-prefill-vs-decode]]
- `prefix cache` — synonyme prompt cache — [[03-applied/15-prompt-vs-semantic-caching]]
- `prefix sharing` — pages KV partagées — [[02-inference/08-kv-cache-management]] · [[02-inference/10-continuous-batching-paged-attention]]
- `preference tuning` — alignment via préférences — [[01-architecture/07-post-training-alignment]]
- `principle of least privilege` — perm minimale — [[05-ops-safety/25-safety-engineering]]
- `prompt caching` — cache du KV prefix — [[03-applied/15-prompt-vs-semantic-caching]]
- `prompt drift` — perf dégrade silencieusement — [[06-meta/29-production-failure-modes]]
- `prompt injection` — input qui détourne le modèle — [[05-ops-safety/25-safety-engineering]]
- `Protect AI` — provider safety — [[05-ops-safety/25-safety-engineering]]
- `PTQ` (Post-Training Quantization) — [[02-inference/12-quantization-deep-dive]]

## Q

- `QAT` (Quantization-Aware Training) — [[02-inference/12-quantization-deep-dive]]
- `quality bar` — seuil qualité — [[06-meta/28-tradeoffs]]
- `quantization` — réduire bits de précision — [[02-inference/12-quantization-deep-dive]]
- `quota` — limite per tenant — [[03-applied/19-model-routing-fallback]]

## R

- `radix tree` — structure pour prefix sharing — [[02-inference/08-kv-cache-management]]
- `Ragas` — framework eval RAG — [[04-retrieval-quality/21-retrieval-evals]]
- `rate limit` (429) — limite requêtes — [[03-applied/19-model-routing-fallback]]
- `RCA` — Root Cause Analysis — [[06-meta/29-production-failure-modes]]
- `ReAct` — pattern Think-Act-Observe — [[03-applied/13-harness-engineering]]
- `recall@k` — % chunks pertinents dans top-k — [[04-retrieval-quality/21-retrieval-evals]]
- `recomputation` — recalcul au backward (FlashAttention) — [[01-architecture/03-flash-attention]]
- `red team` — adversarial testing humain — [[04-retrieval-quality/22-evals]]
- `reference policy` — policy SFT de référence (RLHF/DPO) — [[01-architecture/07-post-training-alignment]]
- `reflection` — self-critique avant action — [[03-applied/18-agent-guardrails]]
- `regression test` — protection contre régressions — [[04-retrieval-quality/22-evals]]
- `re-entrant call` — tool qui s'appelle lui-même — [[03-applied/17-function-calling-reliability]]
- `repair loop` — retry après schema fail — [[03-applied/16-structured-outputs]]
- `reranking` — rerank top-100 → top-10 — [[04-retrieval-quality/20-rag-architecture]]
- `residual stream` — flux additif Transformer — [[01-architecture/01-transformer-architecture]]
- `reward hacking` — gaming du reward model — [[01-architecture/07-post-training-alignment]]
- `reward model` — prédicteur de préférence RLHF — [[01-architecture/07-post-training-alignment]]
- `ring attention` — context parallelism via anneau — [[01-architecture/06-distributed-training]]
- `RLHF` (Reinforcement Learning from Human Feedback) — [[01-architecture/07-post-training-alignment]]
- `RMSNorm` — normalisation par RMS — [[01-architecture/01-transformer-architecture]]
- `RoPE` (Rotary Position Embedding) — encodage relatif par rotation — [[01-architecture/02-position-encodings]]
- `router` (MoE) — sélecteur des experts — [[01-architecture/05-mixture-of-experts]]
- `row-level security` (RLS) — DB isolation — [[05-ops-safety/26-multi-tenant-isolation]]
- `RRF` — Reciprocal Rank Fusion — [[04-retrieval-quality/20-rag-architecture]]
- `runaway agent` — boucle infinie — [[06-meta/29-production-failure-modes]]
- `RWKV` — architecture RNN/Transformer hybride — [[01-architecture/02-position-encodings]]

## S

- `salient weights` — weights qui multiplient outliers — [[02-inference/12-quantization-deep-dive]]
- `sandboxing` — exec isolée — [[03-applied/18-agent-guardrails]]
- `scaled dot-product attention` — formule canonique d'attention — [[01-architecture/01-transformer-architecture]] · [[01-architecture/03-flash-attention]]
- `schema pass rate` — % outputs valides — [[03-applied/16-structured-outputs]]
- `self-attention` — attention sur la même séquence — [[01-architecture/01-transformer-architecture]]
- `self-critique` — synonyme reflection — [[03-applied/18-agent-guardrails]]
- `self-preference` (bias) — judge préfère même famille — [[04-retrieval-quality/22-evals]]
- `semantic cache` — cache par similarité embedding — [[03-applied/15-prompt-vs-semantic-caching]]
- `SentencePiece` — librairie tokenization — [[01-architecture/04-tokenization]]
- `sequence parallelism` — synonyme context parallelism — [[01-architecture/06-distributed-training]]
- `SFT` (Supervised Fine-Tuning) — fine-tuning sur (instruction, response) — [[01-architecture/07-post-training-alignment]]
- `shared expert` — expert toujours activé (MoE) — [[01-architecture/05-mixture-of-experts]]
- `sliding window` (attention) — fenêtre bornée sur K tokens — [[01-architecture/02-position-encodings]] · [[02-inference/08-kv-cache-management]]
- `sliding window` (context) — ne garder que N derniers tours — [[03-applied/14-context-engineering]]
- `SmoothQuant` — gestion outliers W8A8 — [[02-inference/12-quantization-deep-dive]]
- `softmax` — normalisation probabiliste — [[01-architecture/01-transformer-architecture]]
- `span` — sous-op dans une trace — [[05-ops-safety/23-llm-observability]]
- `sparse activation` — peu de paramètres actifs (MoE) — [[01-architecture/05-mixture-of-experts]]
- `sparse retrieval` — BM25, SPLADE — [[04-retrieval-quality/20-rag-architecture]]
- `speculative decoding` — draft + verify lossless — [[02-inference/11-speculative-quant-distill]]
- `SPLADE` — sparse learned retrieval — [[04-retrieval-quality/20-rag-architecture]]
- `SRAM` — mémoire on-chip GPU — [[01-architecture/03-flash-attention]]
- `SSM` (State Space Model) — base architecture Mamba — [[01-architecture/02-position-encodings]]
- `state compaction` — résumer historique — [[03-applied/13-harness-engineering]]
- `static batching` — batch fixe (anti-pattern) — [[02-inference/10-continuous-batching-paged-attention]]
- `stuck detection` — hash actions récentes — [[03-applied/18-agent-guardrails]]
- `structured context` — XML tags, sections — [[03-applied/14-context-engineering]]
- `structured outputs` — JSON schema garanti — [[03-applied/16-structured-outputs]]
- `subword` — unité de tokenization — [[01-architecture/04-tokenization]]
- `SwiGLU` — activation gated (Llama, Mistral) — [[01-architecture/01-transformer-architecture]]
- `symmetric/asymmetric` (quant) — schéma de quantization — [[02-inference/12-quantization-deep-dive]]

## T

- `tail latency` — p95/p99 — [[03-applied/19-model-routing-fallback]] · [[05-ops-safety/23-llm-observability]]
- `target model` — gros modèle qui valide — [[02-inference/11-speculative-quant-distill]]
- `temperature` — sampling param — [[05-ops-safety/23-llm-observability]]
- `tenant_id` — clé d'isolation — [[05-ops-safety/26-multi-tenant-isolation]]
- `tenant tier` — niveau de service — [[03-applied/19-model-routing-fallback]] · [[05-ops-safety/24-cost-attribution]]
- `tensor parallelism` (TP) — split horizontal de matrices — [[01-architecture/06-distributed-training]]
- `termination condition` — fin de l'agent loop — [[03-applied/18-agent-guardrails]]
- `Tiktoken` — tokenizer OpenAI en Rust — [[01-architecture/04-tokenization]]
- `tiling` — découpage en blocs (FlashAttention) — [[01-architecture/03-flash-attention]]
- `token` — unité de manipulation du modèle — [[01-architecture/04-tokenization]]
- `token budget` — max tokens session — [[03-applied/18-agent-guardrails]]
- `tokenizer` — encode/decode texte ↔ tokens — [[01-architecture/04-tokenization]]
- `tool budget` — max calls par tool — [[03-applied/18-agent-guardrails]]
- `tool contract` — schema + description — [[03-applied/17-function-calling-reliability]]
- `tool registry` — catalogue des tools — [[03-applied/13-harness-engineering]]
- `top-k gating` / `top-k routing` — sélection MoE — [[01-architecture/05-mixture-of-experts]]
- `TPOT` — Time Per Output Token — [[02-inference/09-prefill-vs-decode]]
- `trace` — request end-to-end — [[05-ops-safety/23-llm-observability]]
- `Tree-of-Thought` — pattern branches parallèles — [[03-applied/13-harness-engineering]]
- `trust boundary` — niveau de trust des données — [[05-ops-safety/25-safety-engineering]]
- `TTFT` — Time To First Token — [[02-inference/09-prefill-vs-decode]]
- `TTL` — Time To Live (cache) — [[03-applied/15-prompt-vs-semantic-caching]]

## U

- `Unigram LM` — algorithme tokenization probabiliste — [[01-architecture/04-tokenization]]
- `unit economics` — cost/LTV — [[05-ops-safety/24-cost-attribution]]
- `untrusted input` — contenu user/tool à filtrer — [[05-ops-safety/25-safety-engineering]]

## V

- `vocabulary` — ensemble des tokens — [[01-architecture/04-tokenization]]
- `VRAM` — GPU memory — [[02-inference/08-kv-cache-management]]
- `vLLM` — serving engine canonique — [[02-inference/10-continuous-batching-paged-attention]]

## W

- `W8A8` — Weight 8-bit, Activation 8-bit — [[02-inference/12-quantization-deep-dive]]
- `W4A16` — Weight 4-bit, Activation 16-bit — [[02-inference/12-quantization-deep-dive]]
- `wallclock budget` — max temps session — [[03-applied/18-agent-guardrails]]
- `weight-only quantization` — quant weights seuls — [[02-inference/12-quantization-deep-dive]]
- `WordPiece` — algorithme tokenization BERT — [[01-architecture/04-tokenization]]

## X

- `XGrammar` — lib constrained decoding rapide — [[03-applied/16-structured-outputs]]

## Y

- `YaRN` — RoPE scaling avec attention temperature — [[01-architecture/02-position-encodings]]

## Z

- `ZeRO` (1/2/3) — sharding strategies — [[01-architecture/06-distributed-training]]
- `zero-shot` — pas d'exemples dans le prompt — [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]]
