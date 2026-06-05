---
title: "Architecture des modèles"
description: "Les fondations : Transformer, attention, position encoding, tokenization, MoE, training distribué, post-training."
tags:
  - cluster-index
---

Les sept notes qui posent les fondations conceptuelles d'un LLM frontier. À lire en séquence pour construire le mental model du modèle lui-même, avant de passer à son serving ([[02-inference/index|Inference]]) ou à son intégration applicative ([[03-applied/index|Applied]]).

## Notes

1. [[01-architecture/01-transformer-architecture]] — Self-attention, MHA/MQA/GQA, FFN, normalisations
2. [[01-architecture/02-position-encodings]] — RoPE, ALiBi, YaRN, sliding window
3. [[01-architecture/03-flash-attention]] — Tiling, online softmax, hiérarchie mémoire GPU
4. [[01-architecture/04-tokenization]] — BPE, SentencePiece, Tiktoken, multilingue
5. [[01-architecture/05-mixture-of-experts]] — Routing, expert capacity, auxiliary-loss-free balancing
6. [[01-architecture/06-distributed-training]] — DP, ZeRO, FSDP, TP, PP, mixed precision
7. [[01-architecture/07-post-training-alignment]] — SFT, RLHF, DPO, Constitutional AI
