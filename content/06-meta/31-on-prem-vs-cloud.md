---
title: "31. On-prem vs cloud"
description: "Quatre niveaux de déploiement — API provider, managed cloud, self-managed cloud, on-prem strict — et leurs drivers réels."
tags:
  - meta
aliases:
  - 31-on-prem-vs-cloud
---

> [!info] Prérequis
> [[06-meta/30-open-vs-closed-source|30. Open vs closed source]] — le choix du modèle conditionne les options de déploiement : closed = API obligatoire, open weights débloque tout le reste.

> [!tip] Notes liées
> [[06-meta/32-fine-tuning-en-pratique]] · [[02-inference/10-continuous-batching-paged-attention]] · [[05-ops-safety/26-multi-tenant-isolation]] · [[05-ops-safety/24-cost-attribution]]

## Le concept

"On-prem vs cloud" est une simplification. Le vrai axe est : **qui contrôle le serving runtime et où la data transite-t-elle ?** Quatre niveaux pratiques, classés du moins au plus de contrôle.

## Les quatre niveaux

```
moins de contrôle ←——————————————————————→ plus de contrôle
moins de ops      ←——————————————————————→ plus de ops

1. Provider API     2. Managed cloud    3. Self-managed     4. On-prem strict
   (OpenAI,            (Bedrock,           cloud               (datacenter
   Anthropic,          Azure OpenAI,       (vLLM sur EC2,      propre,
   Mistral API)        Vertex AI,          GKE, etc.)          sovereign
                       La Plateforme)                          cloud)
```

### 1. Provider API

Le provider expose un endpoint, on envoie tokens et reçoit tokens.

- **Data flow** : prompt sort du périmètre client, atterrit chez le provider.
- **Compute** : géré par le provider.
- **Versions modèle** : par le provider (risque `prompt drift`, [[06-meta/29-production-failure-modes|cf. 29]]).
- **Customization** : prompt eng + éventuel FT API.
- **SLA** : ceux du provider, généralement 99.9%.

### 2. Managed cloud (LLM-as-a-service hyperscaler)

Le modèle tourne dans le cloud d'un hyperscaler, dans le compte cloud client (ou en VPC).

Exemples : **AWS Bedrock**, **Azure OpenAI Service**, **GCP Vertex AI**, **Mistral La Plateforme**.

- **Data flow** : data reste dans la région cloud choisie, sous accord cloud (BAA, DPA).
- **Compute** : géré par l'hyperscaler.
- **Data residency** : contrôlable (UE-only, US-only, etc.).
- **Pricing** : par token, parfois avec provisioned throughput pour stabilité.
- **Cas d'usage** : compromis entre simplicité et compliance (RGPD, HIPAA possibles).

### 3. Self-managed cloud (DIY serving)

Les poids open weight sont téléchargés et le serving stack ([[02-inference/10-continuous-batching-paged-attention|vLLM]], TGI, SGLang, TensorRT-LLM) est déployé sur des GPU loués au cloud (EC2 p5, GKE A3, Azure ND H100).

- **Data flow** : data reste dans le compte client cloud.
- **Compute** : GPU loués mais opérés par le client (config, scaling, monitoring).
- **Customization** : totale ([[02-inference/12-quantization-deep-dive|quantization]] custom, [[06-meta/32-fine-tuning-en-pratique|FT]] adapter switching, [[02-inference/11-speculative-quant-distill|speculative decoding]]).
- **Coût** : $-$$ selon GPU et utilisation. Réservé sur 1-3 ans = -50-70% vs on-demand.
- **Compétence requise** : équipe ML platform / serving.

### 4. On-prem strict

GPUs dans des racks possédés ou loués en colocation. Datacenter physique sous contrôle direct.

- **Data flow** : ne sort jamais du périmètre physique. Air-gap possible.
- **Compute** : CAPEX hardware, énergie, refroidissement, replacements.
- **Cas d'usage** : régulation extrême (secret défense, HDS niveau hébergeur, banques avec contraintes IT internes), souveraineté complète, ou volume tel que le CAPEX bat le cloud.
- **Compétence requise** : équipe infra hardware + serving.

Variante : **sovereign cloud** (OVH, Scaleway, Outscale en France ; T-Systems en DE) — cloud public mais opéré par un acteur soumis à la juridiction locale uniquement.

## La hardware question

Pour les niveaux 3 et 4, la question matérielle conditionne tout.

| Modèle | Précision | Mémoire requise | Hardware minimal | Notes |
|---|---|---|---|---|
| Llama 3.1 8B | BF16 | ~16 GB | 1× A100 40GB | Aisé |
| Llama 3.1 8B | INT8 | ~8 GB | 1× L40S, A10 | Edge possible |
| Mistral Small 22B | BF16 | ~44 GB | 1× H100 80GB | OK |
| Mixtral 8×7B | BF16 | ~96 GB | 2× H100 80GB | Active params 12.9B |
| Llama 3.3 70B | BF16 | ~140 GB | 2× H100 80GB | Standard prod |
| Llama 3.3 70B | [[02-inference/12-quantization-deep-dive\|FP8]] | ~70 GB | 1× H100 80GB | Recommandé prod |
| Llama 3.1 405B | BF16 | ~810 GB | 8× H100 + TP | Frontier OSS |
| Llama 3.1 405B | FP8 | ~405 GB | 4× H100 + TP | Recommandé |

Coût indicatif H100 80GB SXM (2025) : ~$3-4/h on-demand sur AWS/Azure ; ~$25k-35k à l'achat. Un nœud 8× H100 = ~$250-300k CAPEX, ~$30/h amorti vs ~$30/h on-demand cloud — le break-even est ~3 ans d'utilisation pleine.

## Drivers du choix

Le choix n'est presque jamais "ce qui coûte le moins". Cinq drivers réels :

### Souveraineté et régulation

- **HDS niveau hébergeur** (santé France) : provider doit être certifié HDS — élimine OpenAI direct, garde Azure OpenAI EU et Mistral La Plateforme.
- **Secret défense / OIV** : exige souvent du français/européen avec accord ANSSI — pousse vers on-prem ou sovereign cloud.
- **HIPAA** (santé US) : BAA disponible chez Anthropic, OpenAI (via Azure), AWS Bedrock.
- **Financial regulation** (RGPD strict, banking secrecy) : data residency UE non négociable — élimine API US, garde Azure OpenAI EU, Vertex AI EU, Mistral.

### Data residency

Pas le même que souveraineté : "ma data peut-elle physiquement quitter le pays / le continent ?" Réponse souvent contractuelle (DPA cloud) mais doit être vérifiable.

### Latency

- Edge : modèle [[02-inference/12-quantization-deep-dive|quantized]] embarqué (Llama 3.2 1B, Phi-3 mini).
- Batch local : on-prem peut éliminer le réseau (~50-200ms gagnés).
- Real-time multi-region : provider API gère mais self-managed cloud peut faire mieux avec co-location.

### Cost à scale

Le break-even cloud-to-on-prem dépend du modèle. Indicatif :
- < 10M tokens/jour : API ou managed cloud dominent.
- 10M-100M tokens/jour : self-managed cloud avec GPU réservés.
- > 100M tokens/jour soutenu : on-prem rentable, surtout si déjà colocation.

### Compétence ops disponible

C'est le driver souvent sous-estimé. Self-managed cloud (niveau 3) demande :
- Ingénieurs platform familiers avec GPU scheduling (Kubernetes + GPU operator, ou Slurm).
- Familiarité avec [[02-inference/10-continuous-batching-paged-attention|vLLM]] ou équivalent — paramétrage, monitoring, tuning.
- [[05-ops-safety/23-llm-observability|Observability]] dédiée (GPU utilization, batch size, throughput).
- Capacité à debugger CUDA OOM, NCCL errors, network IB.

Sans cette compétence, niveau 3 est piégé : on tombe en panne et le provider ne répond pas. Niveau 2 (managed cloud) est souvent le sweet spot pratique.

## Études de cas comparées (2025-2026)

Quatre archétypes de déploiement réels, avec des labs différents en position de force.

### Llama on-prem — le standard mondial OSS

Llama 3.x est le modèle on-prem de fait : présent sur AWS Outposts, Azure Stack, GCP Anthos, OpenShift, et la majorité des stacks self-hosted Hugging Face. L'écosystème (vLLM, TGI, SGLang, TensorRT-LLM, llama.cpp) le supporte en premier. Les industriels US/Asie qui doivent garder leurs données on-prem (banques, défense, santé) tournent à 80% sur Llama.

### Mistral on-prem — l'option souveraine EU

Mistral cible explicitement les verticals régulés EU. Cas concrets :
- **BNP Paribas** : déploiement on-prem pour KYC, fichiers incomplets 80% → 10%, traitement semaines → jours, plateforme LLM rolled out à 65 000 users.
- **Armées françaises** (janv. 2026) : framework agreement piloté par AMIAD, ~€300M/an, exclusivement sur infrastructure française.
- **Mistral AI Studio** (mars 2026) : production platform supportant hybrid / dedicated / self-hosted avec même durability et traceability.
- **Mistral Compute** : cloud GPU dédié EU, datacenter de Bruyères-le-Châtel (mid-2026), partenariat EcoDataCenter Suède (€1.2B, 2027), cible 200 MW Europe fin 2027.

### Azure OpenAI / AWS Bedrock / Vertex AI — managed cloud closed

Pour les clients qui veulent du **closed source avec data residency contrôlée**. Azure OpenAI propose des déploiements EU (Sweden Central, France Central) avec BAA HIPAA pour santé US. AWS Bedrock agrège Claude, Llama, Mistral, Nova sur des régions ciblées. Vertex AI permet Gemini + open-weight via Model Garden. Compromis : closed + compliance + data residency, sans gérer GPU.

### DeepSeek on-prem — le pari hard-mode

DeepSeek-V3 (671B MoE / 37B actifs) est techniquement déployable on-prem en MIT mais demande 8× H200 minimum pour servir confortablement. Adopté massivement en Chine (régulation locale qui exclut les modèles US) et chez les laboratoires de recherche occidentaux pour les coûts d'inférence très bas. La friction principale : pas de support enterprise structuré, écosystème en construction.

### Sovereign clouds EU

OVHcloud, Scaleway, Outscale (France), T-Systems / STACKIT (Allemagne), Aruba (Italie) : alternatives EU au cloud hyperscaler, opérées sous juridiction européenne uniquement. Souvent moins capacitaires que AWS/Azure/GCP, mais critiques pour les contraintes secret défense / OIV / HDS strictes. Hébergent Llama, Mistral, parfois Qwen.

### Lecture des patterns

| Cas client | Lab probable | Niveau déploiement |
|---|---|---|
| Banque EU régulée | Mistral, Llama | On-prem ou sovereign cloud |
| Banque US HIPAA / compliance forte | Claude via Bedrock, Azure OpenAI | Managed cloud avec BAA |
| Tech US scale-up | OpenAI / Anthropic API | Provider API |
| Recherche académique cost-sensitive | DeepSeek-V3, Qwen | Self-managed cloud ou on-prem |
| Défense FR | Mistral | On-prem strict (AMIAD) |
| SaaS multi-tenant | Mix routing (Llama self-hosted + Claude API) | Hybride |
| Multinationale Chine | Qwen, DeepSeek | Sovereign cloud Chine + on-prem |

Pas de "meilleur" lab universel. Chaque combinaison client-lab-déploiement répond à une contrainte dominante (souveraineté, prix, capability frontier, écosystème, latency).

## Table comparative

| Niveau | Setup time | Ops cost | Data control | Customization | Coût/Mtoken (modèle ~70-200B eq.) |
|---|---|---|---|---|---|
| 1. Provider API | minutes | ~0 | Faible | Prompt + FT API limité | $2-15 |
| 2. Managed cloud | jours | Faible | Bon (data residency) | Prompt + FT API | $3-20 |
| 3. Self-managed cloud | semaines | Élevé (ETP serving) | Très bon | Totale | $0.5-3 selon utilization |
| 4. On-prem | mois | Très élevé (ETP infra) | Maximal | Totale | $0.2-1 si utilization > 60% |

## Pièges courants

- **Niveau 3 sans compétence ops** — promesses non tenues, downtime non géré. Mieux de rester niveau 2.
- **On-prem sans utilization soutenue** — GPU à $30k qui tourne à 5% : pire qu'API.
- **Data residency contractuelle non vérifiée** — DPA signé mais sous-traitants non audités.
- **Pas de fallback cross-level** — niveau 4 down sans niveau 1 en backup = incident produit.
- **Lock-in à un format de quantization** — modèle quantized [[02-inference/12-quantization-deep-dive|AWQ]] sur une version de vLLM qui devient incompatible.

## Pattern hybride en production

Beaucoup d'architectures combinent niveaux :
- **Niveau 3 ou 4 pour le steady state** (Llama 3.x, Mistral Small, Qwen, ou DeepSeek-V3 self-hosted pour 80% du traffic).
- **Niveau 1 ou 2 en fallback** (Claude / GPT-4o / o3 pour les 20% complexes ou reasoning, et en disaster recovery si le serving stack tombe).
- [[03-applied/19-model-routing-fallback|Router]] qui dispatche.

Permet de capturer les économies à scale tout en gardant la fiabilité du closed API en filet.

## Vocabulaire clé

`provider API`, `managed cloud`, `self-managed cloud`, `on-prem`, `sovereign cloud`, `data residency`, `data sovereignty`, `BAA`, `DPA`, `HDS`, `HIPAA`, `RGPD`, `CAPEX vs OPEX`, `colocation`, `GPU operator`, `tensor parallelism`, `provisioned throughput`, `break-even`, `disaster recovery`, `fallback cross-level`.

## Synthèse

Le choix de déploiement est un spectre à quatre niveaux : provider API (OpenAI, Anthropic, Mistral API, DeepSeek) → managed cloud (Bedrock, Azure OpenAI, Vertex AI, La Plateforme) → self-managed cloud (vLLM sur EC2/GKE) → on-prem strict (datacenter propre, sovereign cloud EU). Plus on monte, plus on gagne en contrôle data et customization, plus on perd en simplicité ops. Drivers réels : souveraineté/régulation (HDS, secret défense, RGPD strict), data residency, latency, coût à scale, et compétence ops disponible — le dernier est souvent décisif. Break-even self-managed cloud vs API autour de 10M tokens/jour, on-prem vs cloud autour de 100M tokens/jour soutenu. Sur l'on-prem, **Llama est le standard mondial OSS**, **Mistral cible explicitement la souveraineté EU** (BNP, Schneider, Thales, Armées via AMIAD), **DeepSeek-V3** est le pari hard-mode (671B MoE, écosystème en construction), tandis que **Azure OpenAI / Bedrock / Vertex AI** offrent du closed source avec data residency contrôlée pour les clients qui ne veulent pas gérer GPU. En production, pattern hybride dominant : open weight self-hosted pour le steady state, closed API en fallback ou pour reasoning frontier, [[03-applied/19-model-routing-fallback|router]] entre les deux.
