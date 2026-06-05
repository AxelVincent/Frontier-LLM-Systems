---
title: "Inference et serving"
description: "Comment un LLM est exécuté à scale : KV cache, deux régimes hardware, continuous batching, speculative decoding, quantization."
tags:
  - cluster-index
---

Cinq notes sur l'exécution d'un LLM en production. Présuppose une connaissance opérationnelle de l'attention et du KV cache (cf. [[01-architecture/index|Architecture des modèles]]).

## Notes

8. [[02-inference/08-kv-cache-management]] — Mémoire, fragmentation, eviction
9. [[02-inference/09-prefill-vs-decode]] — Compute-bound vs memory-bound
10. [[02-inference/10-continuous-batching-paged-attention]] — Throughput optimization
11. [[02-inference/11-speculative-quant-distill]] — Trois familles d'accélération
12. [[02-inference/12-quantization-deep-dive]] — INT8, INT4, FP8, GPTQ, AWQ
