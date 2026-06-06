---
title: "16. Structured outputs"
description: "Schemas, constrained decoding, repair loops, fallback chains : faire produire du JSON valide à un LLM."
tags:
  - applied
aliases:
  - 09-structured-outputs
  - 16-structured-outputs
---

> [!tip] Notes liées
> [[03-applied/17-function-calling-reliability]] · [[03-applied/19-model-routing-fallback]] · [[06-meta/29-production-failure-modes]] · [[03-applied/13-harness-engineering]]

## Le problème

Le modèle est sollicité pour produire du JSON conforme à un schéma. Le modèle est probabiliste, pas un parser. Risques :

- JSON malformé (virgules en trop, guillemets manquants).
- Schema mismatch (champ manquant, type incorrect, enum hors-vocabulaire).
- [[01-architecture/07-post-training-alignment|Hallucination]] de champs non-demandés.
- Truncation au milieu d'un objet (max_tokens atteint).
- Sortie en français au lieu d'anglais (ou inverse).

## Les approches (de la plus faible à la plus robuste)

**1. Prompt-only**
- "Réponds en JSON avec ces champs : ...". Fonctionne 90-95% du temps sur GPT-4o, Claude, Mistral Large.
- 5-10% d'échecs : à gérer dans le fallback chain.

**2. JSON mode (mode flag)**
- Syntaxe JSON garantie.
- **Pas** de garantie sur le schéma.

**3. Structured output / [[03-applied/17-function-calling-reliability|function calling]] avec schema**
- OpenAI structured outputs (response_format: json_schema, strict: true) : garantit syntaxe + schema.
- Anthropic tool use : définition d'un schema rempli par le modèle. Mêmes garanties.
- Mistral function calling : équivalent.
- **Technique sous-jacente** : **constrained decoding** (alias guided decoding). À chaque step, le sampler n'autorise que les [[01-architecture/04-tokenization|tokens]] qui maintiennent le préfixe dans un état valide selon une grammaire (compilée en finite-state machine ou regex). Outils : outlines, lm-format-enforcer, XGrammar, guidance.

> [!example] Intuition — contrainte au niveau du sampler
> Le sampling standard tire un token dans la distribution `softmax(logits)` sur tout le [[01-architecture/04-tokenization|vocabulaire]]. En constrained decoding, la grammaire (compilée en FSM ou regex) calcule à chaque step le **set de tokens valides** étant donné le préfixe déjà émis, et on masque les logits hors de ce set avant le [[01-architecture/01-transformer-architecture|softmax]]. Le modèle reste libre de choisir, mais uniquement parmi des continuations syntaxiquement valides. C'est ce qui rend `strict: true` réellement strict — la contrainte n'est plus déclarative, elle est appliquée mécaniquement.

**4. Constrained decoding custom**
- Sur un modèle self-hosted, on peut imposer sa propre grammaire (BNF, regex, JSON schema custom).
- Outils : `outlines`, `lm-format-enforcer`, `XGrammar` (rapide, intégré vLLM/SGLang).
- Applicable à d'autres formats que JSON : XML, YAML, code, DSL custom.

## Modes de défaillance subtils

Même avec constrained decoding strict :

- **Champs vides mais valides** : `{"answer": ""}` passe le schema, l'application le rejette.
- **Hallucination dans des champs string libres** : le schema oblige `summary: string`, le contenu est inventé.
- **Enum hallucination "presque" valide** : valeurs attendues `"high" | "medium" | "low"`, valeur reçue `"medium-high"` rejetée selon la rigueur du sampler.
- **Numbers as strings** : `"price": "29.99"` au lieu de `"price": 29.99`. Acceptation variable selon le schema.
- **Truncation silencieuse** : max_tokens atteint en milieu de génération, JSON tronqué. Le constrained decoding peut fermer les brackets mais le contenu reste incomplet.

## Repair loops

En cas d'échec de la sortie, plusieurs niveaux de remédiation :

**Niveau 1 : reformatting interne**
- JSON malformé reçu : essayer un parser tolérant (json5, dirtyjson) avant de re-call le modèle.
- Coût : ~0. Gain : 30-50% des cas.

**Niveau 2 : re-call avec error message**
- Renvoi au modèle : "Ton output a échoué la validation pour {raison}. Refais."
- Coût : 1 call supplémentaire. Gain : 70-90% du reste.
- Risque : boucle infinie. Limiter à 2-3 retries maximum.

**Niveau 3 : re-call avec schema reminder + exemples**
- Si le retry simple échoue, prompt enrichi avec un exemple correct.
- Coût : 1 call avec prompt plus long.

**Niveau 4 : fallback chain de modèles**
- Si Mistral Small échoue 3 fois, passer à Mistral Large.
- Si Mistral Large échoue, fallback Claude Sonnet.
- Si tout échoue, retour d'une réponse "safe" hardcodée + log d'incident.
- Voir [[03-applied/19-model-routing-fallback]].

**Niveau 5 : dégrader le contrat**
- En l'absence de sortie strictement typée, accepter une réponse string libre post-process en best-effort.
- Trade-off : sacrifier la garantie pour une graceful degradation.

## Patterns d'architecture

```
schema_validation_failed
  → try parse_tolerant
    → success: log warning + return
    → fail: try retry_with_error_message (max 2)
      → success: return
      → fail: try fallback_to_larger_model (max 1)
        → success: return
        → fail: try fallback_to_safe_response + alert
```

## Métriques

- `schema_pass_rate` per call type (target >99% sur les flows critiques).
- `repair_loop_depth_p50/p99` (combien de retries en moyenne).
- `fallback_to_larger_model_rate` (signal de drift du petit modèle).
- `total_cost_per_successful_output` (incluant les retries).

## Vocabulaire clé

`structured outputs`, `JSON mode`, `JSON schema`, `constrained decoding`, `guided decoding`, `finite-state machine`, `grammar-constrained sampling`, `outlines`, `XGrammar`, `lm-format-enforcer`, `repair loop`, `fallback chain`, `graceful degradation`, `schema pass rate`.

## Synthèse

L'approche moderne pour les structured outputs est le constrained decoding : à chaque step, le sampler restreint les tokens autorisés à ceux qui maintiennent le préfixe dans un état valide selon une grammaire ou un JSON schema. OpenAI structured outputs, Anthropic tool use et Mistral function calling reposent sur ce mécanisme. Outils sous-jacents : outlines, XGrammar, lm-format-enforcer. La garantie porte sur la syntaxe, pas sur le contenu. En production, on associe systématiquement un repair loop : parse-tolerant d'abord, puis retry avec error message en input, puis fallback à un modèle plus gros, puis fallback à une réponse safe. La profondeur des retries doit être bornée pour éviter les boucles infinies. Métrique clé : schema_pass_rate par call type, target >99% sur les critical paths.
