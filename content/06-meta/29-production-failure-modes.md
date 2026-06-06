---
title: "29. Production failure modes : le bestiaire"
description: "Le catalogue des défaillances observées en production LLM, classées par origine et symptôme."
tags:
  - meta
aliases:
  - 22-production-failure-modes
  - 29-production-failure-modes
---

> [!tip] Notes liées
> [[03-applied/16-structured-outputs]] · [[03-applied/17-function-calling-reliability]] · [[03-applied/18-agent-guardrails]] · [[04-retrieval-quality/20-rag-architecture]] · [[05-ops-safety/23-llm-observability]] · [[05-ops-safety/25-safety-engineering]] · [[05-ops-safety/26-multi-tenant-isolation]]

## Le bestiaire

Catalogue des défaillances réelles observées en production. Connaître leurs noms canoniques et leurs mitigations est la signature d'un practitioner expérimenté.

## 1. Hallucinated tool calls

**Symptôme** : le modèle appelle un tool inexistant, ou avec des args invalides, ou choisit le mauvais tool.

**Causes** :
- Trop de tools dans le registry (>20-30 = dégradation).
- Tool descriptions ambiguës.
- [[06-meta/27-ft-vs-icl-vs-rag-vs-distill|Few-shot examples]] mal-alignés avec les real-world inputs.

**Mitigations** :
- Strict schema validation côté harness (refus et retry). Voir [[03-applied/17-function-calling-reliability]].
- Tool descriptions explicites avec when-to-use / when-NOT-to-use.
- Limitation du nombre de tools exposés par context (sélection dynamique des tools pertinents par query).
- Eval set d'adversarial cases qui tentent d'induire le mauvais tool. Voir [[04-retrieval-quality/22-evals]].

## 2. Malformed JSON

**Symptôme** : réponse non parseable comme JSON.

**Causes** :
- Pas de [[03-applied/16-structured-outputs|structured output mode]].
- max_tokens atteint en milieu de génération.
- Le modèle entoure le JSON de markdown blocks.
- Caractères mal échappés dans des strings.

**Mitigations** :
- [[03-applied/16-structured-outputs|Constrained decoding]] / [[03-applied/16-structured-outputs|JSON mode]]. Voir [[03-applied/16-structured-outputs]].
- Parser tolérant (json5, dirtyjson).
- max_tokens bumpé.
- Retry avec error message en input.

## 3. Stale retrieval

**Symptôme** : le RAG renvoie des informations obsolètes.

**Causes** :
- Re-index pipeline cassé.
- [[03-applied/15-prompt-vs-semantic-caching|TTL]] trop long sur les [[04-retrieval-quality/20-rag-architecture|embeddings]].
- Doc mis à jour mais ancien chunk non invalidé.
- Cached responses ([[03-applied/15-prompt-vs-semantic-caching|semantic cache]]) qui survivent au changement de fact.

**Mitigations** :
- Pipeline de re-indexing surveillé (alerte sur lag).
- Versioning des chunks avec metadata `updated_at`.
- Filtrage par `updated_at > X` au retrieval pour les data sensibles à la fraîcheur.
- Invalidation event-driven (CDC sur la source).

## 4. Runaway agents

**Symptôme** : agent qui boucle sans terminer et consomme tokens et budget sans s'arrêter.

**Causes** :
- Pas de [[03-applied/18-agent-guardrails|loop budget]].
- Pas de [[03-applied/18-agent-guardrails|stuck detection]].
- Modèle qui ne sait pas comment "finir".

**Mitigations** :
- Loop budget hard (max 20 iter). Voir [[03-applied/18-agent-guardrails]].
- Stuck detection sur hash des K dernières actions.
- [[03-applied/18-agent-guardrails|Wallclock budget]] + [[03-applied/18-agent-guardrails|cost budget]] kill switch.
- Tool `submit_final_answer` ou `done` explicite.

## 5. Silent eval regressions

**Symptôme** : un changement de prompt / modèle / retrieval introduit une régression de qualité non détectée parce que le [[04-retrieval-quality/22-evals|golden set]] ne couvre pas le cas.

**Causes** :
- Golden set trop petit.
- Pas d'adversarial set.
- Pas de CI eval.
- Coverage gaps (nouveaux features sans eval ajoutée).

**Mitigations** :
- CI qui run le golden set sur chaque PR. Voir [[04-retrieval-quality/22-evals]].
- Continuous eval sur sample du traffic prod (1% sampling rate). Voir [[05-ops-safety/23-llm-observability]].
- Golden set qui croît à chaque incident.
- Coverage tracking : quels features ont une eval ?

## 6. Cache poisoning

**Symptôme** : un user reçoit une réponse cached d'un autre user (semantic cache) ou le cache contient des données malveillantes injectées.

**Causes** :
- Cache key sans [[05-ops-safety/26-multi-tenant-isolation|tenant_id]] / user_id.
- Pas de validation des inputs avant cache write.

**Mitigations** :
- Cache key incluant tenant + user pour data sensible. Voir [[05-ops-safety/26-multi-tenant-isolation]].
- Validate output before caching ([[05-ops-safety/25-safety-engineering|PII check]], schema check).
- TTL court sur les caches user-facing.

## 7. Prompt drift

**Symptôme** : la performance se dégrade lentement au cours du temps sans changement de code.

**Causes** :
- Le provider a updated le modèle backend sans changement de version (cas des auto-updated models).
- Distribution des inputs change ([[05-ops-safety/23-llm-observability|concept drift]]).
- Le système consomme ses propres outputs (auto-réinjection).

**Mitigations** :
- Pin version explicite du modèle (mistral-large-2411 vs mistral-large).
- Eval continue sur sample.
- [[05-ops-safety/23-llm-observability|Drift detection]] (embedding-based, statistical).

## 8. Cost spikes

**Symptôme** : facture mensuelle ×3 d'un coup.

**Causes** :
- Bug dans un agent qui cause un runaway.
- New feature shippé sans cost monitoring.
- Tool definition qui explose en [[01-architecture/04-tokenization|tokens]] (long descriptions à chaque call).
- User abuse (single user qui spam).
- Prompt caching breakpoint qui change → cache miss systématique.

**Mitigations** :
- Cost monitoring per feature, per tenant, per user. Voir [[05-ops-safety/24-cost-attribution]].
- Alertes anomaly (cost burn rate > 2x baseline).
- [[03-applied/19-model-routing-fallback|Rate limits]] per user et per workflow.
- [[03-applied/18-agent-guardrails|Budget enforcement]].

## 9. Latency spikes

**Symptôme** : [[05-ops-safety/23-llm-observability|p99]] explose, certaines requests timeout.

**Causes** :
- Provider degradation.
- Prompt length spike (un user envoie 100k tokens).
- [[02-inference/08-kv-cache-management|KV cache]] pression (server saturé). Voir [[02-inference/08-kv-cache-management]].
- Cold start sur autoscaling.
- Network issue.

**Mitigations** :
- [[03-applied/19-model-routing-fallback|Hedging]].
- [[03-applied/19-model-routing-fallback|Circuit breaker]].
- max prompt length enforcement (refus ou troncature).
- Provisioned capacity en peak hours.
- Multi-region.

## 10. Tool side-effect divergence

**Symptôme** : l'agent rapporte avoir effectué X, mais X n'a pas eu lieu (ou inversement).

**Causes** :
- Tool exec a échoué silencieusement, l'agent a interprété le retour vide comme success.
- Idempotency absente : tool exec dédupliqué côté DB mais agent croit avoir agi.
- Partial failure non géré.

**Mitigations** :
- Tool exec retournant toujours un status explicite (success/failure/partial).
- [[03-applied/17-function-calling-reliability|Idempotency keys]].
- Compensating actions sur partial failures.
- Reconciliation jobs offline.

## 11. [[05-ops-safety/25-safety-engineering|PII]] leakage

**Symptôme** : la réponse à l'user A contient des PII de B.

**Causes** :
- Cache cross-tenant.
- RAG retrieve cross-tenant.
- Logs sans masking exposés.
- Fine-tuned model qui régurgite des données vues en training.

**Mitigations** :
- Tenant isolation stricte sur tous les paths. Voir [[05-ops-safety/26-multi-tenant-isolation]].
- PII detection + masking dans les logs.
- Differential privacy ou LoRA per tenant pour fine-tuning.
- Audit logs scrutés.

## 12. [[05-ops-safety/25-safety-engineering|Jailbreak]] / [[05-ops-safety/25-safety-engineering|prompt injection]] success

**Symptôme** : le modèle exécute une action qu'il ne devrait pas (révéler system prompt, faire une action interdite, dire des choses inappropriées).

**Causes** :
- Pas de [[05-ops-safety/25-safety-engineering|input filtering]].
- Tool permissions trop laxistes.
- Système qui consomme du tool output non validé.

**Mitigations** :
- Input classifier.
- [[05-ops-safety/25-safety-engineering|Output filtering]].
- Strict tool permissions au niveau code. Voir [[05-ops-safety/25-safety-engineering]].
- [[05-ops-safety/25-safety-engineering|Trust boundary]] modeling.
- [[04-retrieval-quality/22-evals|Red team]] continue.

## Patterns transversaux

- **Tout failure mode a un signal observability associé**. Sans observation, le failure se reproduit.
- **Beaucoup de failure modes sont silencieux**. Le bug n'est pas une stack trace, mais une métrique qui drift.
- **Les défenses se composent**. Une seule défense est bypassable. Trois en couches couvrent 99%.
- **La paranoïa universelle n'est pas tenable**. On priorise par impact × fréquence. Cost spike > latency spike > silent regression > exotic edge case.

## Vocabulaire clé

`hallucinated tool call`, `malformed JSON`, `stale retrieval`, `runaway agent`, `silent eval regression`, `cache poisoning`, `prompt drift`, `cost spike`, `latency spike`, `partial failure`, `compensating action`, `PII leakage`, `jailbreak`, `incident response`, `MTTR`, `MTTD`, `RCA`, `postmortem`.

## Synthèse

Catalogue des failure modes production. Hallucinated tool calls — mitigation : strict schema validation et limitation du nombre de tools exposés. Malformed JSON — constrained decoding et repair loop. Stale retrieval — re-index pipeline monitored et invalidation event-driven. Runaway agent — loop budget, stuck detection, cost kill switch. Silent eval regressions — CI eval et continuous eval sur sample du traffic. Cache poisoning — cache keys avec tenant/user. Prompt drift — pin version du modèle et drift detection. Cost spikes — monitoring per feature/tenant + budget enforcement. Latency spikes — hedging, circuit breaker, max prompt length. Tool side-effect divergence — idempotency et status explicite. PII leakage — tenant isolation et logs masking. Jailbreak — input filtering, strict tool permissions, trust boundary modeling. Pattern central : tout failure mode a un signal observability associé, beaucoup sont silencieux, et les défenses se composent en couches.
