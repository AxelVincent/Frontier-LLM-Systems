---
title: "18. Agent guardrails"
description: "Loop budgets, tool budgets, stuck detection, approval gates : empêcher un agent de tourner ou casser des choses."
tags:
  - applied
aliases:
  - 11-agent-guardrails
  - 18-agent-guardrails
---

> [!tip] Notes liées
> [[03-applied/17-function-calling-reliability]] · [[05-ops-safety/24-cost-attribution]] · [[06-meta/29-production-failure-modes]] · [[03-applied/13-harness-engineering]]

## Le problème

Un agent loop sans garde-fous présente plusieurs risques :

- **Boucle infinie** : le modèle ne décide jamais de l'arrêt et appelle des tools en boucle.
- **Cost explosion** : 500 appels modèle par session au lieu de 5.
- **Side effect explosion** : 1000 emails envoyés, base de données saturée.
- **Stuck on a sub-problem** : l'agent essaie 50 fois le même tool qui échoue.
- **Catastrophic action** : l'agent exécute une commande destructive qui matche localement son objectif.

C'est au harness de poser des **budgets** et des **termination conditions**.

## Les budgets

**Loop budget (max iterations)**
- "Max 20 tool calls par session."
- Au-delà, terminer avec un message "I couldn't complete this in the allotted iterations."

**Tool budget (per tool, per session)**
- "Max 5 calls à `web_search` par session."
- Évite l'agent qui search en boucle sans converger.

**Token budget**
- "Max 100k tokens consommés par session."
- Au-delà, compaction forcée ou termination.

**Wall-clock budget**
- "Max 5 minutes par session."
- Pour l'UX et pour borner les coûts d'infrastructure.

**Cost budget (dollar)**
- "Max $0.50 par session pour les users free."
- Conversion tokens × prix → kill switch quand dépassé. Voir [[05-ops-safety/24-cost-attribution]].

**Side-effect budget**
- "Max 10 writes externes (emails, paiements, DB writes) par session."
- Le plus important pour limiter les dégâts.

## Termination conditions

L'agent doit s'arrêter dans les cas suivants :

**1. Le modèle signale "stop"**
- Pas de tool call dans la réponse → fin.
- Tool call explicite `submit_final_answer` ou `finish_task`.

**2. Budget dépassé**
- Loop / tool / token / wallclock / cost.

**3. Erreur non-recoverable**
- Tool catastrophe (auth perdue, permission révoquée).
- Modèle qui hallucine en boucle.

**4. Stuck detection**
- Même tool call répété N fois avec mêmes args → stuck.
- Hash des K dernières actions pour détecter des cycles.
- Termination avec "I appear to be stuck on X".

**5. User intervention**
- L'utilisateur envoie un nouveau message → l'ancien loop s'arrête.

## Guardrails au-delà des budgets

**Input filtering**
- Refus des tasks malveillantes (prompt injection, demande d'action illégale). Voir [[05-ops-safety/25-safety-engineering]].
- Classification du user input avant l'entrée dans la loop.

**Output filtering**
- Avant de renvoyer la réponse à l'utilisateur : check PII leakage, content moderation, format compliance.

**Tool sandboxing**
- Chaque tool call exécuté dans un sandbox isolé (par session, par tenant).
- Permission boundary stricte (un tool ne voit que les données du tenant courant). Voir [[05-ops-safety/26-multi-tenant-isolation]].

**Reflection / self-critique**
- Avant action critique : prompt secondaire demandant au modèle "are you sure ? Why ?".
- Coût : 1 call supplémentaire. Gain : 30-50% de réduction des bad actions.

**Approval gates**
- Pour actions critiques (delete, send payment, send email à >N personnes), exiger une confirmation user explicite avant exécution.
- Pattern Claude Code : edit/write/bash require approval selon permission mode.

## Patterns concrets

**Hard limits**
```typescript
const HARD_LIMITS = {
  max_iterations: 20,
  max_tokens: 100_000,
  max_wallclock_ms: 300_000,
  max_cost_usd: 0.50,
  max_tool_calls_per_tool: { web_search: 5, send_email: 3 },
  max_side_effects: 10,
};
```

**Stuck detection**
```typescript
function isStuck(history: ToolCall[], window = 5): boolean {
  if (history.length < window) return false;
  const recent = history.slice(-window);
  const hashes = recent.map(c => `${c.name}:${JSON.stringify(c.args)}`);
  return new Set(hashes).size === 1;
}
```

**Cost tracking**
```typescript
function trackCost(usage: TokenUsage, model: string): number {
  const price = PRICES[model];
  return usage.input_tokens * price.input + usage.output_tokens * price.output;
}
```

## Failure modes des guardrails eux-mêmes

- **Trop strict** : l'agent termine prématurément sur des tasks légitimes.
- **Trop permissif** : runaway agent.
- **Stuck detection défaillante** : l'agent répète avec des args très légèrement différents pour passer le check.
- **Termination non-graceful** : l'agent stoppe au milieu d'une action critique, partial state.

## Vocabulaire clé

`agent loop`, `loop budget`, `tool budget`, `token budget`, `wallclock budget`, `cost budget`, `termination condition`, `stuck detection`, `runaway agent`, `approval gate`, `sandboxing`, `permission boundary`, `reflection`, `self-critique`, `hard limit`.

## Synthèse

Un agent sans guardrails est un risque opérationnel. On définit des budgets : max iterations (typiquement 20), max tool calls par tool, max tokens, max wallclock, max cost en dollar, et surtout max side effects pour borner les dégâts en cas de runaway. Termination conditions multiples : absence de tool call dans la réponse, budget dépassé, stuck détecté via hash des K dernières actions, erreur non-recoverable, ou intervention utilisateur. Pour les actions critiques : approval gate, étape de self-critique avant action, et sandboxing par tenant pour la permission boundary. Le piège subtil : la stuck detection peut être contournée si l'agent répète une action avec des args très légèrement modifiés.
