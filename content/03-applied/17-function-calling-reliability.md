---
title: "17. Function calling reliability et idempotency"
description: "Tool contracts, validation, idempotency keys, retry semantics : function calling de niveau production."
tags:
  - applied
aliases:
  - 10-function-calling-reliability
  - 17-function-calling-reliability
---

> [!tip] Notes liées
> [[03-applied/16-structured-outputs]] · [[03-applied/18-agent-guardrails]] · [[05-ops-safety/25-safety-engineering]] · [[05-ops-safety/26-multi-tenant-isolation]] · [[03-applied/13-harness-engineering]]

## Le problème

Le modèle reçoit une liste d'outils avec leurs schemas. Il choisit lequel appeler et avec quels arguments. En théorie, le flux est propre. En pratique :

- **Wrong tool** : le modèle choisit `delete_user` au lieu de `archive_user`.
- **[[06-meta/29-production-failure-modes|Hallucinated tool]]** : le modèle invente un tool inexistant (`send_carrier_pigeon`).
- **Wrong args** : types corrects mais valeurs incorrectes (user_id du mauvais user).
- **Hallucinated args** : champs absents du schema.
- **Misformatted args** : dates au mauvais format, enums presque-corrects.
- **Tool selected but never called** : le modèle annonce "I'll call X" en texte mais ne déclenche pas l'appel.
- **Tool result mishandled** : la réponse du tool est mal interprétée par le modèle.
- **Idempotency violations** : deux appels identiques produisent des effets de bord dupliqués (paiement débité deux fois).

## Tool contract design

Un bon contrat de tool comporte :

**1. Nom explicite et single-purpose**
- À éviter : `process_user` (ambigu).
- À préférer : `archive_user_by_id` ou `send_password_reset_email`.

**2. Description avec contexte d'usage**
```json
{
  "name": "archive_user_by_id",
  "description": "Archives a user. Reversible by an admin within 30 days. Use when the user requests account deletion. DO NOT use for spam/fraud — use ban_user instead.",
  "parameters": { ... }
}
```

**3. Args strictement typés et validés**
- Pas de `metadata: object` fourre-tout.
- Enums explicites.
- Patterns regex pour les IDs.
- Format de date ISO 8601 spécifié.

**4. Description de chaque param incluant les contraintes**
- "user_id: UUID v4 of the user to archive. Must belong to the current tenant."

**5. Limites explicites en description**
- "Max 100 items per call. For larger sets, paginate."

## Validation côté [[03-applied/13-harness-engineering|harness]] (essentielle)

Les arguments du modèle ne doivent jamais être considérés comme de confiance. Toujours valider côté [[03-applied/13-harness-engineering|harness]] avant exécution :

```typescript
async function executeTool(call: ToolCall, ctx: Context) {
  const tool = registry.get(call.name);
  if (!tool) {
    return { error: `Unknown tool: ${call.name}` };
  }
  const validation = tool.schema.safeParse(call.arguments);
  if (!validation.success) {
    return { error: `Invalid arguments: ${validation.error.message}` };
  }
  // Permission check
  if (!tool.permissions.allows(ctx.user, validation.data)) {
    return { error: "Permission denied" };
  }
  // Idempotency
  const key = idempotencyKey(call);
  if (await idemStore.exists(key)) {
    return await idemStore.get(key);
  }
  const result = await tool.execute(validation.data, ctx);
  await idemStore.set(key, result);
  return result;
}
```

## Idempotency

Critique pour les tools avec side effects (write to DB, send email, charge payment).

- **Idempotency key** : hash de (tool_name + canonicalized_args + tenant + session_id). Une réception du même key dans une fenêtre de [[03-applied/15-prompt-vs-semantic-caching|TTL]] retourne le résultat caché au lieu de réexécuter.
- **Pourquoi** : l'[[03-applied/13-harness-engineering|agent loop]] peut décider de retry, le modèle peut générer le même call deux fois, un network retry peut dupliquer.
- **Sans idempotency** : doublons de paiement, doublons d'email, état corrompu.

## Argument validation approfondie

Au-delà du schema match :

- **Cross-field validation** : si `type=transfer`, alors `target_account` requis.
- **Business invariants** : `amount > 0`, `start_date < end_date`.
- **Permission scoping** : l'utilisateur a-t-il le droit d'agir sur cette ressource ?
- **Tenant scoping** : la ressource appartient-elle au tenant courant ? Voir [[05-ops-safety/26-multi-tenant-isolation]].
- **[[03-applied/19-model-routing-fallback|Rate limiting]] per tool** : certains tools coûteux (send_sms, gpt-4-api-call) doivent avoir des budgets par session/user.

## Patterns de défaillance subtils

- **Re-entrant tool calls** : tool A appelle tool B qui appelle tool A. Détecter les boucles.
- **Stale snapshots** : le modèle voit l'état initial, agit dessus, mais l'état a changé entre temps (autre process). Validation via version/etag.
- **Partial failures** : un tool exécute 3 actions, 2 réussissent, 1 échoue. Recovery : transactional ou compensating actions.
- **Tool result too long** : la réponse du tool fait 50k tokens, sature le contexte. Summarize/truncate.

## Métriques

- `tool_call_success_rate` per tool.
- `tool_call_arg_validation_failure_rate` per tool (un drift signale un désalignement modèle/schema).
- `tool_call_permission_denied_rate` (un drift signale des hallucinations d'actions).
- `tool_call_idempotency_hit_rate` (volume de duplicate calls).
- `tool_call_latency_p50/p99` per tool.

## Vocabulaire clé

`tool contract`, `function calling`, `tool schema`, `argument validation`, `permission boundary`, `idempotency key`, `idempotency store`, `re-entrant call`, `compensating action`, `tool registry`, `tenant scoping`, `tool call hallucination`.

## Synthèse

La function calling reliability ne se réduit pas aux schemas. Le contrat de tool doit être single-purpose, avec une description claire incluant les contextes d'usage et de non-usage, des params strictement typés (enums, regex), et des limites explicites. Côté harness, les arguments ne doivent jamais être considérés comme de confiance : validation du schema, des business invariants, des permissions, du scope tenant, et application d'une idempotency key sur tous les tools avec side effects pour éviter les doublons sur retry. Patterns subtils : re-entrant calls, stale snapshots, partial failures. Métrique clé : `tool_call_success_rate` par tool — un drift dans les validation failures signale un désalignement entre le modèle et le contrat.
