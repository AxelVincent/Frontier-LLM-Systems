---
title: "Engineering autour du modèle"
description: "Le harness applicatif : event loop, context engineering, caching, structured outputs, function calling, guardrails, routing."
tags:
  - cluster-index
---

Sept notes sur ce qui entoure le modèle quand on build un produit LLM. C'est ici que se joue l'essentiel de la qualité perçue — pas dans le system prompt.

## Notes

13. [[03-applied/13-harness-engineering]] — Le système qui entoure le modèle
14. [[03-applied/14-context-engineering]] — Sélectionner ce qui rentre dans le contexte
15. [[03-applied/15-prompt-vs-semantic-caching]] — Deux types de cache distincts
16. [[03-applied/16-structured-outputs]] — Schemas, repair loops, fallback
17. [[03-applied/17-function-calling-reliability]] — Tool contracts, idempotency
18. [[03-applied/18-agent-guardrails]] — Budgets, termination, stuck detection
19. [[03-applied/19-model-routing-fallback]] — Router une gamme de modèles
