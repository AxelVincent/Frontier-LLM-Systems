---
title: "30. Open source vs closed source"
description: "Spectre des modèles selon l'accès aux poids, licences, coût total, et le pari hybride de Mistral."
tags:
  - meta
aliases:
  - 30-open-vs-closed-source
---

> [!info] Prérequis
> [[06-meta/27-ft-vs-icl-vs-rag-vs-distill|27. FT vs ICL vs RAG vs distillation]] · [[06-meta/28-tradeoffs|28. Tradeoffs]] — la décision OSS vs fermé conditionne quelles techniques restent accessibles.

> [!tip] Notes liées
> [[06-meta/31-on-prem-vs-cloud]] · [[06-meta/32-fine-tuning-en-pratique]] · [[01-architecture/07-post-training-alignment]] · [[03-applied/19-model-routing-fallback]]

## Le concept

La dichotomie "open source vs closed source" est en réalité un **spectre d'accès aux poids et aux droits d'usage**. La vraie question n'est pas "le code est-il public" (il l'est rarement intégralement, même chez les acteurs OSS), mais : **ai-je les poids, sous quelle licence, et avec quels droits de modification, redistribution et usage commercial ?**

## Le spectre réel

```
fermé total ←——————————————————————————————→ ouvert permissif

GPT-4o      Claude       Gemini     Mistral     Llama 3    Mistral 7B
OpenAI      Anthropic    Google     Large       Meta       Mixtral
                                    (paid)      (Community  Qwen 2.5
                                                license)    DeepSeek
                                                            (Apache 2.0)
```

Quatre niveaux pratiques :

1. **API-only fermé** — poids inaccessibles, fine-tuning impossible ou via API contrainte (Claude, Gemini, GPT-4o).
2. **API + fine-tuning managé** — poids inaccessibles mais le provider expose un FT API (OpenAI sur GPT-4o-mini et GPT-3.5, Gemini sur certains modèles).
3. **Poids ouverts avec licence restrictive** — téléchargeables, usage limité (Llama Community License : gratuit jusqu'à 700M MAU ; Mistral Large/Medium sous licence commerciale).
4. **Poids ouverts permissifs** — Apache 2.0 ou MIT : redistribution, modification, usage commercial sans restriction (Mistral 7B, Mixtral 8x7B, Qwen 2.5, DeepSeek, Gemma 2 avec quelques limites).

## Closed source

**Exemples** : GPT-4o, Claude Sonnet/Opus, Gemini Pro.

**Avantages** :
- Capability frontier — gap réel sur reasoning long, tool use complexe, multimodalité.
- Aucune infra à gérer.
- Mises à jour automatiques (qui sont aussi un risque, cf. `prompt drift` dans [[06-meta/29-production-failure-modes]]).
- Safety tuning massif déjà fait.

**Inconvénients** :
- Lock-in : changer de provider = re-tuner prompts, re-évaluer, re-instrumenter.
- Pas de vraie [[01-architecture/07-post-training-alignment|customization]] des weights.
- Pas d'on-prem ([[06-meta/31-on-prem-vs-cloud|cf. 31]]) — data quitte le périmètre.
- Pricing imposé, parfois revu unilatéralement.
- Pas d'inspection des biais ou des refus.

## Open weights

**Exemples** : Llama 3.x, Mistral 7B / Mixtral, Qwen 2.5, DeepSeek-V3, Gemma 2.

**Avantages** :
- [[06-meta/32-fine-tuning-en-pratique|Fine-tuning]] complet possible (LoRA, full FT, DPO custom).
- [[06-meta/31-on-prem-vs-cloud|On-prem]] viable — souveraineté, data residency.
- Coût marginal proche de zéro à très haut throughput (CAPEX amorti).
- Inspectable : biais, refus, attention patterns observables.
- [[02-inference/12-quantization-deep-dive|Quantization]] et [[02-inference/11-speculative-quant-distill|distillation]] possibles sans accord du provider.

**Inconvénients** :
- Capability gap sur les tâches frontier (en réduction rapide depuis 2024).
- Ops cost : GPU infra, monitoring, autoscaling à gérer.
- Safety tuning à faire ou compléter soi-même.
- Pas de mises à jour automatiques (avantage *et* inconvénient).

## Licences en pratique

| Licence | Modèles typiques | Usage commercial | Modification | Redistribution |
|---|---|---|---|---|
| Apache 2.0 / MIT | Mistral 7B, Mixtral, Qwen 2.5, DeepSeek | Libre | Libre | Libre |
| Llama Community License | Llama 3.x | Libre jusqu'à 700M MAU | Libre | Avec attribution |
| Gemma Terms of Use | Gemma 2 | Libre avec restrictions d'usage | Libre | Avec terms |
| Mistral Commercial License | Mistral Large / Medium | Payant, contrat | Selon contrat | Interdit |
| Closed API ToS | GPT, Claude, Gemini | Pay-per-token | N/A | N/A |

La lecture des licences avant industrialisation est non-négociable. La clause à surveiller : redistribution des poids fine-tunés (souvent interdite ou conditionnée), et clause "outputs ne peuvent pas servir à entraîner un modèle concurrent" (présente chez OpenAI, Anthropic, Google).

## Études de cas comparées (2025-2026)

Chaque acteur frontier occupe une position distincte sur le spectre. Les comparer permet de voir les modèles économiques sous-jacents.

### Meta / Llama — open-weight quasi-permissif

- **Llama 3.x, Llama 4** sous **Llama Community License** : usage commercial libre jusqu'à 700M MAU, redistribution avec attribution, restrictions sur usages mil/AML.
- Revenue model indirect : Meta n'a pas de produit LLM commercial direct ; les poids ouverts cristallisent l'écosystème autour de l'infra Meta (PyTorch, vLLM contributions, recommandations), réduisent la dépendance à OpenAI/Google côté Meta-products, et appliquent une pression deflationniste sur les closed providers.
- Outillage officiel : `torchtune`, recipes Hugging Face. Llama 4 (2025) marque le passage au multimodal natif et au reasoning.
- Position : **le standard de fait OSS mondial**.

### DeepSeek — frontier OSS quasi-pur

- **DeepSeek-V3, DeepSeek-R1** sous **MIT license** : permissif au maximum, y compris pour la concurrence directe.
- DeepSeek-R1 (janv. 2025) : premier reasoning model frontier open-weight, RL pur sans SFT pour les traces de raisonnement, 671B MoE / 37B actifs. Voir [[06-meta/34-reasoning-models]].
- Revenue model : API à prix cassé sur DeepSeek.com (~10-20× moins cher qu'OpenAI), monétise les services adjacents.
- Position : **le pari "frontier OSS, pression prix"**.

### Mistral — hybride Apache 2.0 + propriétaire

- **Apache 2.0** sur Mistral Small / Mixtral / Ministral / Magistral Small / Voxtral Small — adoption communautaire et fine-tuning libre.
- **Propriétaire** sur Mistral Large 3 / Magistral Medium / Voxtral TTS — capability frontier monétisée.
- **La Plateforme** (managed cloud API), **Mistral AI Studio** (hybrid/dedicated/self-hosted production), **Mistral Compute** (cloud GPU dédié), **Mistral Forge** (training enterprise sur données propriétaires).
- Revenue model : "your data, your model, your infra" — déploiement souverain UE comme proposition différenciante (BNP Paribas, Schneider Electric, Thales, Armées françaises).
- **Sept 2025** : Series C €1.7B avec ASML lead (€1.3B, ~11% stake), valorisation €11.7B.
- Position : **hybride avec ancrage EU et souveraineté**.

### OpenAI — closed API premium

- **GPT-4o, o-series (o1, o3)** : poids inaccessibles, fine-tuning API limité aux modèles autorisés (4o-mini, certains 3.5).
- Revenue model : pay-per-token + ChatGPT subscriptions + enterprise contracts (Azure OpenAI co-distribution).
- Capability frontier sur reasoning (o3 a posé l'ARC-AGI à 88%), agentic, multimodal.
- Position : **closed pur, capability max, lock-in maximal**.

### Anthropic — closed avec accent safety

- **Claude Sonnet / Opus** : poids inaccessibles, pas de fine-tuning API en accès général.
- Revenue model : API + enterprise contracts (AWS Bedrock co-distribution, Vertex AI), tier Claude Code.
- Différenciation : Responsible Scaling Policy publique, Constitutional AI, longest deep work (extended thinking).
- Position : **closed orienté safety/enterprise**.

### Google DeepMind — mix Gemma OSS + Gemini fermé

- **Gemma 2 / 3** sous Gemma Terms of Use (open avec restrictions d'usage).
- **Gemini 2 / 3 Pro/Ultra** fermés via Vertex AI / Gemini API.
- Revenue model : intégration Google Cloud + Workspace + Search.
- Position : **hybride "Gemma pour pénétration, Gemini pour monétisation"**.

### Qwen (Alibaba) — open frontier multilingue

- **Qwen 2.5, Qwen 3, QwQ** sous Apache 2.0 (la plupart des tailles).
- Reasoning model QwQ comparable à o1 sur benchmarks math/code.
- Revenue model : Alibaba Cloud, dominance écosystème Chine.
- Position : **frontier OSS multilingue, écosystème non-occidental**.

### Lecture des patterns

| Lab | Stratégie | Levier de revenu |
|---|---|---|
| Meta | OSS pour casser les rentes des closed | Indirect (écosystème PyTorch, pression deflationniste) |
| DeepSeek | OSS frontier + prix cassé sur l'API | Volume API à très bas prix |
| Mistral | Hybride OSS + propriétaire + souveraineté EU | Mix La Plateforme + propriétaire + contrats enterprise |
| OpenAI | Closed pur, capability frontier | API premium + ChatGPT + Azure |
| Anthropic | Closed + safety + dev tooling | API + Bedrock + Claude Code |
| Google | Mix Gemma OSS + Gemini fermé | Cloud + Workspace + Search |
| Qwen | OSS frontier multilingue | Alibaba Cloud Chine |

Aucune position n'est "la bonne" — chacune correspond à une thèse stratégique cohérente. Le choix client se fait selon les contraintes : souveraineté (Mistral, DeepSeek si pas de friction Chine, Llama on-prem), prix (DeepSeek API, Qwen), capability frontier closed (OpenAI o3, Anthropic Opus), écosystème (Llama si bibliothèques tierces, Gemini si Google Workspace).

## Coût total

Le coût n'est pas comparable token-par-token. Il faut intégrer.

**Closed (API)** :
- Pricing token-based, OPEX pur.
- Pas de CAPEX, pas d'ops cost direct.
- Surcoût caché : observability, logging, vendor management.

**Open (self-hosted)** :
- CAPEX GPU (8x H100 ≈ $300k/an amorti sur 3 ans avec colocation et énergie).
- Ops team (1-2 ETP minimum pour un serving stack production).
- Coût marginal par token ≈ électricité + amortissement.

**Break-even indicatif** (à 2025) pour un workload Mistral Large équivalent :
- < 1M tokens/jour : closed wins largement.
- 1M-10M tokens/jour : zone grise, dépend du provider et du tarif négocié.
- > 10M tokens/jour soutenu : open self-hosted devient économiquement supérieur, et l'avantage croît avec le volume.

Mais le calcul économique n'est qu'un axe. Souveraineté, [[05-ops-safety/26-multi-tenant-isolation|data isolation]] et latency peuvent justifier l'open weight bien en dessous du break-even.

## Quand chacun est le bon outil

| Scénario | Choix typique | Pourquoi |
|---|---|---|
| Prototype rapide, < 100 users | Closed API (n'importe lequel) | Time-to-market, zéro ops |
| SaaS scale-up, multi-tenant standard | Closed + routing ([[03-applied/19-model-routing-fallback]]) | Pas le moment de gérer GPU ops |
| Vertical régulé (legal, santé EU, finance) | Open weight on-prem (Llama, Mistral) | Data ne peut pas sortir |
| Domain-specific avec dataset propriétaire | Open weight + [[06-meta/32-fine-tuning-en-pratique|FT]] | Customization profonde requise |
| Volume soutenu > 10M tokens/jour | Open weight self-hosted ou DeepSeek API | Break-even économique |
| Edge / on-device | Open weight quantized (Llama 3.2 1B, Phi, Gemma) | Closed n'expose pas le modèle |
| Reasoning frontier (math, code, agentic) | o3 / Claude extended thinking / R1 / Magistral | Capability ou cost selon contrainte |
| Multimodal vision+audio | GPT-4o, Gemini 2, Pixtral+Voxtral, Llama 4 | Selon couverture modale et latency |

## Risques moins évidents

**Side du closed** :
- Deprecation forcée des anciennes versions (OpenAI a déprécié GPT-3 davinci en mois).
- Changement de pricing.
- Refus de catégories d'usage sans warning (compliance, enforcement).
- Risque de censure ou de refus accru au fil des mises à jour.

**Side de l'open** :
- Sécurité supply chain : modèle téléchargé depuis Hugging Face avec poids modifiés malveillamment (rare mais déjà documenté).
- Pas de moderation embedded : à intégrer côté [[05-ops-safety/25-safety-engineering|harness]].
- Compétence ops requise.
- Risque de cesser le maintien : Llama 4 sort, l'écosystème migre, on porte une dette sur Llama 3.

## Pattern hybride en production

Beaucoup de prod 2025-2026 combinent :
- **Closed pour la capability frontier** (Claude Opus / GPT-4o / o3 sur les requêtes complexes ou reasoning).
- **Open self-hosted pour le volume** (Llama 3.x, Mistral Small/Magistral Small, Qwen, DeepSeek-V3 sur les requêtes courantes).
- [[03-applied/19-model-routing-fallback|Router]] qui dispatche selon classifier.

Permet de capter le meilleur des deux : capability max où nécessaire, cost optimal sur la majorité du traffic.

## Vocabulaire clé

`open weights`, `closed source`, `Apache 2.0`, `MIT license`, `Llama Community License`, `commercial license`, `vendor lock-in`, `capability frontier`, `data residency`, `sovereign AI`, `self-hosted`, `managed API`, `break-even`, `CAPEX vs OPEX`, `supply chain attack`, `model deprecation`, `pricing risk`, `hybrid deployment`.

## Synthèse

La dichotomie open vs closed est un spectre — du closed API total (Claude, GPT-4o, o3) au permissif Apache 2.0 / MIT (Mistral Small, Qwen, DeepSeek), en passant par les licences restrictives (Llama Community, Mistral commercial). Closed donne capability frontier et zéro ops mais lock-in et data hors périmètre. Open donne [[06-meta/32-fine-tuning-en-pratique|fine-tuning]] complet, [[06-meta/31-on-prem-vs-cloud|on-prem]] viable et coût marginal proche de zéro à scale, mais demande compétence ops. Break-even indicatif autour de 10M tokens/jour pour le self-hosted. Chaque lab incarne une thèse stratégique : Meta/Llama = OSS pour casser les rentes closed, DeepSeek = frontier OSS avec API à prix cassé, Mistral = hybride avec ancrage souveraineté EU, OpenAI = closed pur capability max, Anthropic = closed safety/enterprise, Google = Gemma OSS + Gemini fermé, Qwen = frontier OSS multilingue Asie. Aucune position n'est "la bonne" — chaque choix client se résout selon la contrainte dominante : souveraineté, prix, capability frontier, écosystème ou réglementation. En production, pattern dominant : hybride avec [[03-applied/19-model-routing-fallback|router]] qui envoie le volume simple sur open weight self-hosted et la complexité frontier (reasoning, multimodal) sur closed API.
