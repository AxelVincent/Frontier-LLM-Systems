---
title: "34. Reasoning models et test-time compute"
description: "o1/o3, DeepSeek R1, Magistral, QwQ : le paradigme reasoning, RL on traces, test-time compute scaling, et l'inference scaling law."
tags:
  - meta
aliases:
  - 34-reasoning-models
---

> [!info] Prérequis
> [[01-architecture/07-post-training-alignment|07. Post-training et alignment]] — RLHF, DPO, PPO sont les fondations. Cette note ajoute le RL spécifique au reasoning (GRPO, RL pur sur traces).

> [!tip] Notes liées
> [[02-inference/09-prefill-vs-decode]] · [[06-meta/28-tradeoffs]] · [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]] · [[04-retrieval-quality/22-evals]] · [[03-applied/18-agent-guardrails]]

## Le concept

À partir de fin 2024, une nouvelle famille de modèles émerge : les **reasoning models**. Au lieu de produire une réponse immédiatement, ils génèrent d'abord une **chaîne de raisonnement** (chain-of-thought, CoT) interne — souvent plusieurs milliers à dizaines de milliers de tokens — avant de répondre. Le pari : *trade compute time for intelligence*. C'est le principe de **test-time compute scaling**, aussi appelé **inference scaling law**.

Le paradigme rompt avec la scaling law classique (capacité ∝ taille + data + training compute). Le **moment** où l'on dépense le compute change : plus seulement au training, mais aussi à l'inférence par requête.

> [!example] Intuition — pourquoi ça marche
> Sur un problème de math, un modèle standard répond directement. Un reasoning model explore : "Soit x... essayons cette identité... ça ne marche pas, essayons autrement... vérifions en injectant 0 et 1... OK donc la réponse est..."
>
> Le modèle apprend à *vérifier*, *reconsidérer*, *changer de stratégie*. Ce n'est pas du prompting CoT — c'est du comportement intériorisé par RL.

## Chronologie 2024-2026

| Date | Modèle | Lab | Notes |
|---|---|---|---|
| Sept 2024 | **o1-preview / o1-mini** | OpenAI | Premier reasoning model commercial, CoT caché, prix premium |
| Nov 2024 | **QwQ-32B-Preview** | Alibaba (Qwen) | Premier reasoning OSS frontier, Apache 2.0, bat o1-preview sur AIME / MATH |
| Déc 2024 | **o1** (release full) | OpenAI | Stabilisation, intégration ChatGPT Pro |
| Janv 2025 | **DeepSeek R1** | DeepSeek | MIT, 671B MoE / 37B actifs, **RL pur sans SFT** sur les traces, publie GRPO. Choc industrie |
| Q1 2025 | **o3 / o3-mini** | OpenAI | 88% ARC-AGI via test-time scaling massif, popularise "System 2" |
| Avr 2025 | **Qwen3** (mode "thinking") | Alibaba | Hybrid reasoning, switchable mode |
| Juin 2025 | **Magistral Small / Medium** | Mistral | Apache 2.0 sur Small 24B, 73.6% AIME 2024 Medium, multilingue |
| 2025-2026 | **Claude Sonnet/Opus avec extended thinking** | Anthropic | Mode "extended thinking" exposable côté client, transparent |
| Mars 2026 | **Mistral Small 4** | Mistral | Unifie Magistral (reasoning), Pixtral (vision), Devstral (code) |

L'évolution est rapide. En 18 mois, le reasoning passe de "produit OpenAI premium" à standard industriel disponible OSS frontier.

## Le pipeline d'entraînement reasoning

Pas un seul pipeline canonique encore (le domaine bouge), mais des patterns récurrents.

### Pattern 1 : RL pur (DeepSeek-R1-Zero)

DeepSeek a démontré que le SFT initial peut être **complètement sauté**. À partir d'un base model, on applique du RL sur des problèmes vérifiables (math, code, logique avec ground truth) :

1. Génère N traces de raisonnement pour un problème.
2. Vérifie automatiquement chaque trace (math : check final answer ; code : run tests ; logique : ground truth).
3. Compute reward (correct = 1, incorrect = 0 ; éventuellement reward intermédiaire pour format).
4. Mise à jour de la policy via **GRPO**.

Émergence observée : self-verification, branching, retracking, "aha moments" où le modèle change de stratégie. Comportements *non programmés explicitement*.

### Pattern 2 : SFT cold-start + RL (DeepSeek-R1, OpenAI o-series)

Variante plus stable :
1. **SFT cold-start** sur ~quelques milliers de traces curated (human-written ou synthetic high-quality).
2. **RL** comme Pattern 1.
3. **SFT secondaire** sur les traces RL filtrées.
4. **RLHF** sur préférences humaines pour alignment et politesse.

Plus complexe mais plus contrôlable que RL pur.

### GRPO (Group Relative Policy Optimization)

Innovation algorithmique de DeepSeek (DeepSeekMath 2024). Variante de PPO qui élimine le **value model** (critic).

```
Pour un prompt p :
1. Génère G samples y_1, ..., y_G depuis la policy.
2. Compute reward r_i pour chaque sample.
3. Advantage relative : A_i = (r_i - mean(r)) / std(r).
4. Mise à jour policy avec advantage A_i comme target PPO.
```

Avantages vs PPO classique :
- Pas de value model → 50% mémoire en moins, training plus rapide.
- Variance réduite (normalisation intra-groupe).
- Pas de generalized advantage estimation à debug.

GRPO est devenu la baseline de fait pour le RL sur reasoning depuis R1.

## Test-time compute scaling

Le mécanisme d'inférence change.

### Standard model
```
prompt → 1 forward pass → response (qq centaines de tokens)
```

### Reasoning model
```
prompt → forward avec long CoT (1 000 - 100 000 tokens internes) → response
```

Le CoT peut être :
- **Caché** (o1, o3) : le client ne voit pas la trace, paie quand même les tokens.
- **Transparent** (Magistral, R1, Claude extended thinking) : la trace est visible.
- **Hybride** (Qwen3) : mode switchable.

### Inference scaling law

Empiriquement, la qualité scale avec le compute test-time (longueur autorisée du CoT, nombre de samples avec majority voting, etc.). Sur ARC-AGI :
- o1 standard : ~30%.
- o1 à compute test-time élevé : 75%.
- o3 high : 88%.

C'est une nouvelle dimension orthogonale au scaling training : on peut "acheter de l'intelligence à la pompe" en allouant plus de compute à la requête. Voir [[06-meta/28-tradeoffs]] pour les nouveaux tradeoffs que ça introduit.

## Études de cas comparées (2025-2026)

### OpenAI o1 / o3

- CoT **caché** côté client (visible seulement en summary).
- Pricing premium (o1 ~$15/M input, ~$60/M output ; o3 encore plus).
- Capability frontier sur ARC-AGI, FrontierMath, code competition.
- Aucune API FT, aucune transparence sur la trace.
- Position : **closed pur, capability max, opacité maximale**.

### DeepSeek R1

- **MIT**, poids ouverts, papier publié avec recipe GRPO complète.
- 671B MoE / 37B actifs, frontier OSS reasoning.
- Trace transparente.
- Choc janv. 2025 : démontré qu'on pouvait égaler o1 en open weight pour fraction du coût training.
- Position : **OSS frontier, transparence totale, pression prix sur OpenAI**.

### Mistral Magistral

- **Magistral Small 24B Apache 2.0** + **Magistral Medium** proprietary.
- 73.6% AIME 2024 (Medium), 70.7% (Small).
- Trace transparente *dans la langue du user* (FR, EN, IT, AR, RU, ZH) — différenciation explicite.
- Pricing Medium ~10× moins cher que o1 sur Le Chat.
- Position : **OSS multilingue + propriétaire enterprise, accessible**.

### Qwen QwQ / Qwen3 thinking

- **QwQ-32B Apache 2.0** : 79.5 AIME 24, 63.4 LiveCodeBench.
- **Qwen3** : mode reasoning switchable, intégré.
- Distillations vers tailles plus petites (DeepSeek-R1-Distill-Qwen-32B, etc.).
- Position : **OSS frontier multilingue Asie**.

### Anthropic extended thinking

- Claude Sonnet / Opus avec **extended thinking mode**.
- Trace transparente, contrôlable côté client (budget tokens, mode on/off).
- Pas un modèle séparé, mais une capability du modèle principal.
- Position : **closed + transparence client + safety**.

### Lecture des patterns

| Modèle | Trace | Licence | AIME 2024 | Pricing relatif |
|---|---|---|---|---|
| OpenAI o3 | Cachée | Closed | ~95%+ | $$$$ |
| OpenAI o1 | Cachée (summary) | Closed | ~83% | $$$ |
| DeepSeek R1 | Transparente | MIT | ~80% | $ (API) ou self-host |
| Mistral Magistral Medium | Transparente | Proprietary | 73.6% (90% maj@64) | $$ |
| Qwen QwQ-32B | Transparente | Apache 2.0 | 79.5 | self-host ou Alibaba |
| Claude extended thinking | Transparente | Closed | comparable o1 | $$$ |
| Magistral Small 24B | Transparente | Apache 2.0 | 70.7 | self-host |

## Implications opérationnelles

Le reasoning model casse plusieurs hypothèses du serving classique.

### Latency

[[02-inference/09-prefill-vs-decode|TPOT]] reste le même, mais le **nombre de tokens output explose** (10k-100k pour un raisonnement long contre quelques centaines normalement). Conséquence : end-to-end latency 10-100× plus longue. Streaming partiel obligatoire pour UX correcte.

### Cost

À tokens-par-output, le coût par requête monte fortement. Reasoning sur o3 peut coûter plusieurs dollars une seule requête. Pour DeepSeek R1 self-hosted, c'est juste du compute GPU mais demande beaucoup plus de GPU-hours par requête.

### KV cache pressure

Le CoT long sature les [[02-inference/08-kv-cache-management|KV cache budgets]]. Sizing serving à refaire : batch sizes plus petits, prefix caching agressif sur la query (avant le CoT).

### Quand utiliser le reasoning

| Use case | Reasoning utile ? | Alternative |
|---|---|---|
| FAQ simple | Non | Mistral Small / Llama 8B standard |
| Math, code competition, science | Oui | R1, Magistral, o3, QwQ |
| Agent multi-step avec planning | Oui partiellement | Standard + planner explicite |
| RAG sur knowledge base | Marginal | Standard + bon retrieval |
| Customer support classification | Non | Petit modèle FT |
| Audit / compliance reasoning explicite | Oui (trace transparente) | Magistral, R1, Claude extended |

Routing intelligent ([[03-applied/19-model-routing-fallback]]) : envoyer au reasoning model uniquement les requêtes qui le justifient, et garder le standard pour la majorité.

### Eval spécifique

Les benchmarks reasoning canoniques (à compléter par eval métier) :
- **AIME 2024 / 2025** — olympiade math US, problèmes courts.
- **MATH** — benchmark mathématique large.
- **GPQA Diamond** — questions scientifiques niveau PhD.
- **LiveCodeBench** — code problems récents, anti-leakage.
- **ARC-AGI** — abstraction et raisonnement, le frontier.
- **FrontierMath** — problèmes math research-level, fait pour casser les modèles.

## Pièges courants

- **Utiliser reasoning pour tout** — overkill et coûteux. Routing par classifier.
- **Couper le CoT** au max_tokens trop bas — réponse tronquée sans conclusion.
- **Streaming brut sans UX** — user voit défiler une trace incompréhensible.
- **Tarification non comprise** — coût explosif sans monitoring per-feature ([[05-ops-safety/24-cost-attribution|cf. 24]]).
- **Reasoning + tool use mal couplé** — le modèle réfléchit dans son CoT mais oublie d'appeler le tool, ou réinvente le résultat.
- **Distillation reasoning sans trace** — perdre le mécanisme en distillant uniquement les réponses finales.

## Vocabulaire clé

`reasoning model`, `chain-of-thought` (CoT), `test-time compute scaling`, `inference scaling law`, `System 2`, `GRPO`, `Group Relative Policy Optimization`, `RL pur`, `cold-start SFT`, `aha moment`, `self-verification`, `extended thinking`, `thinking mode`, `o1`, `o3`, `DeepSeek R1`, `R1-Zero`, `Magistral`, `QwQ`, `AIME`, `MATH`, `GPQA`, `LiveCodeBench`, `ARC-AGI`, `FrontierMath`, `majority voting`, `best-of-N`.

## Synthèse

Les reasoning models (o1/o3, DeepSeek R1, Magistral, QwQ, Claude extended thinking) ouvrent une nouvelle dimension de scaling : **test-time compute scaling**. Le modèle dépense du compute à l'inférence en générant un long chain-of-thought avant de répondre, ce qui scale empiriquement avec la qualité (88% ARC-AGI pour o3 vs 30% modèles standards). Pipeline d'entraînement : SFT cold-start + RL sur problèmes vérifiables (math, code) avec **GRPO** (innovation DeepSeek, élimine le value model de PPO). DeepSeek R1 a démontré que le RL pur sans SFT peut produire des comportements émergents (self-verification, backtracking, aha moments). En 2025-2026 : OpenAI o3 frontier closed, DeepSeek R1 frontier OSS (MIT), Mistral Magistral OSS multilingue + propriétaire, Qwen QwQ/Qwen3 OSS Asie, Claude extended thinking closed transparent. Implications opérationnelles fortes : latency 10-100× plus longue (CoT verbeux), cost par requête en explosion, pression sur [[02-inference/08-kv-cache-management|KV cache]]. Pattern serving : router reasoning uniquement pour les requêtes qui le justifient (math, code, agent planning, compliance), standard pour le reste. Pièges : utiliser reasoning partout, max_tokens trop bas, tarification non monitorée, reasoning + tool use mal couplé.
