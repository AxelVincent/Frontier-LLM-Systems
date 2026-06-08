---
title: "33. On-premise en pratique"
description: "Hardware (H100/H200/B200/GB200), réseau (InfiniBand vs RoCE), datacenter, stack software, sizing concret, air-gap, compliance, et coûts opérationnels réels."
tags:
  - meta
aliases:
  - 33-on-premise-en-pratique
---

> [!info] Prérequis
> [[06-meta/31-on-prem-vs-cloud|31. On-prem vs cloud]] — choix du *niveau* déploiement. Cette note traite du *comment* du niveau 4 (on-prem strict) et partiellement du niveau 3 (self-managed cloud).

> [!tip] Notes liées
> [[06-meta/32-fine-tuning-en-pratique]] · [[02-inference/10-continuous-batching-paged-attention]] · [[02-inference/08-kv-cache-management]] · [[02-inference/12-quantization-deep-dive]] · [[01-architecture/06-distributed-training]] · [[05-ops-safety/26-multi-tenant-isolation]]

## Le concept

[[06-meta/31-on-prem-vs-cloud|31]] décide *où* déployer (provider API / managed cloud / self-managed / on-prem). Cette note traite du *comment* concret de l'on-prem : hardware, network, software stack, sizing, compliance, coûts opérationnels. C'est la note opérationnelle pour quelqu'un qui s'apprête à monter une stack LLM dans son propre datacenter.

## Hardware : sourcing et générations

Le choix GPU conditionne tout le reste — densité énergétique, refroidissement, network, ROI.

### Nvidia (génération courante 2025-2026)

| Génération | Modèle | VRAM | Bande passante | TDP | Topologie typique |
|---|---|---|---|---|---|
| Hopper | H100 SXM 80 GB | 80 GB HBM3 | 3.35 TB/s | 700 W | 8× HGX, NVLink 4 (900 GB/s) |
| Hopper refresh | H200 SXM | 141 GB HBM3e | 4.89 TB/s | 700 W | 8× HGX, NVLink 4 |
| Blackwell | B200 SXM | 192 GB HBM3e | 8 TB/s | 1000 W | 8× HGX, NVLink 5 (1.8 TB/s) |
| Blackwell rack-scale | GB200 NVL72 | 72× B200 + 36 Grace CPU | NVLink 5 fabric | 120-130 kW/rack | Rack unifié |
| Blackwell Ultra | GB300 | 784 GB unified (HBM3e + LPDDR5X) | NVLink 5 | similaire | Successeur GB200 |

Lead times typiques (2025-2026) : 6-9 mois pour HGX, 9-12 mois pour GB200/GB300 selon priorité d'allocation. La pénurie d'allocation est un facteur structurant — les grandes commandes (Microsoft, Mistral via $830M debt Mar 2026 pour 13 800 GB300, Anthropic) consomment la production.

### Alternatives

- **AMD MI300X** : 192 GB HBM3, écosystème ROCm en progrès, supporté par vLLM et SGLang. Moins de friction qu'avant pour Llama / Mistral / Qwen.
- **AMD MI325X / MI350** : génération 2025-2026, alternative crédible si Nvidia indisponible.
- **AWS Trainium 2 / Inferentia 2** : accélérateurs maison AWS, intéressants si on est déjà 100% AWS et qu'on veut éviter la prime Nvidia.
- **Google TPU v5p / v6 Trillium** : pour les workloads Google Cloud.
- **Cerebras WSE-3** : wafer-scale, niche reasoning haute latence.
- **Groq LPU** : niche inférence ultra-low-latency (decode only).

Pour la majorité des cas on-prem 2025-2026, Nvidia HGX/GB reste le standard, surtout pour la compatibilité serving stack (vLLM, TensorRT-LLM, SGLang).

## Réseau : topologie et fabric

Le réseau intra-cluster est aussi critique que le GPU pour les workloads multi-node (training et inference de modèles > single-node).

### Intra-node (NVLink / NVSwitch)

- 8× GPU dans un HGX → NVSwitch full mesh, 900 GB/s (Hopper) ou 1.8 TB/s (Blackwell) par GPU.
- Permet [[01-architecture/06-distributed-training|tensor parallelism]] efficient à l'intérieur du node.
- GB200 NVL72 étend NVLink à 72 GPU dans un rack unique — ouvre des configurations impossibles auparavant (par exemple Llama 405B en TP72).

### Inter-node : InfiniBand vs RoCE

**InfiniBand NDR (400 Gb/s) / XDR (800 Gb/s)**
- Latence sub-microseconde, lossless natif, RDMA mature.
- Standard historique HPC, Nvidia (Mellanox).
- Coût supérieur, vendeur quasi-unique.
- Choix par défaut pour les clusters training frontier (10k+ GPU).

**RoCE v2 (RDMA over Converged Ethernet, 400 GbE / 800 GbE)**
- RDMA sur Ethernet standard, multi-vendeur (Arista, Broadcom, Cisco).
- Demande PFC (Priority Flow Control) et DCQCN (congestion control) pour lossless.
- 85-95% des perfs InfiniBand sur clusters bien tunés jusqu'à ~10k GPU.
- Coût matériel inférieur, écosystème plus large.
- Choix montant pour clusters inférence et training mid-scale (Meta utilise massivement RoCE, Microsoft pousse).

**Topologie** : folded Clos (spine-leaf) dans les deux cas, rail-optimized pour les workloads training (un rail par GPU dans le node pour minimiser les hops).

## Datacenter : contraintes physiques

Les GPU modernes cassent les hypothèses des datacenters traditionnels.

### Densité énergétique

| Génération | Puissance/rack typique | Datacenter standard |
|---|---|---|
| Datacenter classique | 10-20 kW/rack | OK air cooling |
| HGX H100 8× | 30-40 kW/rack | Refroidissement renforcé |
| HGX H200 / B200 | 50-80 kW/rack | Liquid cooling souvent nécessaire |
| GB200 NVL72 | 120-130 kW/rack | Liquid cooling obligatoire |
| GB300 / Blackwell Ultra rack | 130-150+ kW/rack | Liquid cooling obligatoire |

Un GB200 NVL72 = 6× à 13× la densité d'un rack datacenter classique. La majorité des datacenters legacy ne peuvent **physiquement** pas accueillir Blackwell sans rétrofit majeur.

### Refroidissement

- **Air cooling** : OK jusqu'à H100 dans la plupart des cas. CRAC/CRAH classiques.
- **Direct-to-chip liquid cooling** (D2C) : obligatoire pour B200 et au-delà. Coolant ~20 L/min/GPU, inlet <30°C.
- **Rear-door heat exchanger** : retrofit léger pour pousser un peu plus de densité dans des racks existants.
- **Immersion cooling** : niche, surtout edge/HPC. Pas mainstream.

GB200 NVL72 : >700 L/min de coolant par rack. Demande une infrastructure CDU (Coolant Distribution Unit) et plomberie redondante.

### Alimentation et redondance

- N+1 ou 2N sur l'énergie (PDU redondants).
- UPS dimensionnés pour la densité réelle, pas la moyenne.
- Bus bar overhead plutôt que cabling sous le faux-plancher.

## Stack software

### Orchestration

Deux mondes coexistent :

**Kubernetes + Nvidia GPU Operator** — pour les workloads inference et fine-tuning interactifs.
- GPU Operator gère drivers, MIG, monitoring DCGM, device plugin.
- vGPU si besoin de partitionnement (rare).
- Multus / SR-IOV pour exposer InfiniBand aux pods.

**Slurm / Bright Cluster Manager** — pour les workloads training batch HPC-style.
- Mature, scaling massif, intégration MPI/NCCL native.
- Job queues, fair-share, gang scheduling.
- Choix par défaut chez les labs (Meta, OpenAI training infra), grandes universités, supercomputers.

Stack mixte fréquente : Slurm pour le training, Kubernetes pour l'inference.

### Communication GPU

- **NCCL** : la bibliothèque collective standard (all-reduce, all-to-all, broadcast). Tuner `NCCL_IB_HCA`, `NCCL_NET_GDR_LEVEL` selon topologie.
- **GPUDirect RDMA** : skip CPU pour les transferts GPU → NIC → GPU. Indispensable pour la perf inter-node.
- **GPUDirect Storage** : skip CPU pour GPU ↔ NVMe. Utile pour le checkpoint loading.

### Serving runtime

- **vLLM** : default pour open weight (Llama, Mistral, Qwen, DeepSeek). [[02-inference/10-continuous-batching-paged-attention|continuous batching]], [[02-inference/08-kv-cache-management|PagedAttention]], multi-LoRA, tensor parallelism multi-node.
- **TensorRT-LLM** : optimisé Nvidia, performant mais build cycle plus rigide. Bon pour single-model dedicated.
- **SGLang** : alternative montante, RadixAttention pour [[02-inference/08-kv-cache-management|prefix sharing]] agressif.
- **TGI (Hugging Face)** : intégration HF mature, moins performant que vLLM/SGLang sur certains workloads.

### Quantization à l'inférence

- **FP8** sur H100/H200/B200 : ratio qualité/coût quasi-optimal en 2025-2026. Voir [[02-inference/12-quantization-deep-dive]].
- **W4A16** (AWQ, GPTQ) : pour single-GPU serving de gros modèles.
- **W8A8** (SmoothQuant) : pour rester sur INT8 mature.

## Sizing concret

Quelques cas typiques (en BF16/FP8, avec marge pour KV cache et batch).

| Modèle | Précision | Hardware minimal | Hardware confortable production |
|---|---|---|---|
| Llama 3.1 8B / Mistral Small | BF16 | 1× H100 80 GB | 1× H100 |
| Llama 3.1 8B / Mistral Small | FP8 | 1× L40S 48 GB | 1× H100 |
| Mistral Small 22B / Magistral Small 24B | BF16 | 1× H100 80 GB | 1× H100/H200 |
| Mixtral 8×7B | BF16 | 2× H100 | 2-4× H100 (batch) |
| Llama 3.3 70B | BF16 | 2× H100 | 4× H100 |
| Llama 3.3 70B | FP8 | 1× H100 | 2× H100 (batch) |
| Mistral Large 3 / Magistral Medium | BF16 | 4-8× H100 | 8× H100 |
| DeepSeek-V3 671B MoE / 37B actifs | FP8 | 8× H200 ou 8× B200 | 16× H100 ou 8× B200 |
| Llama 3.1 405B | FP8 | 4× H100 (TP4, batch limité) | 8× H100 (TP8) |
| Llama 3.1 405B | BF16 | 8× H100 TP + offload | 8× B200 |

Provisioning rule of thumb :
- **Headroom 30-50%** pour pics de traffic.
- **Charge cible** 50-70% utilization (au-delà, TPOT dégradé, peu de marge incident).
- **KV cache** consomme 20-40% du HBM pour batchs sérieux — toujours benchmarker en charge réelle.

## Air-gap et compliance

Le on-prem permet des modes opératoires impossibles en cloud.

### Air-gap

- Cluster sans accès Internet sortant.
- Téléchargement modèles via tier (DMZ avec audit), signature SHA256 vérifiée.
- Mises à jour stack via mirror interne.
- Indispensable pour secret défense, certains OIV, R&D pharma sensible.

### Certifications

| Référentiel | Domaine | Implications stack |
|---|---|---|
| HDS Hébergeur (France) | Données de santé | Certification de l'hébergeur, ségrégation physique, audit logs |
| ANSSI SecNumCloud | Cloud souverain qualifié | Juridique français/UE, contrôle d'accès, traçabilité |
| ISO 27001 / 27017 / 27018 | Information security | Base universelle |
| HIPAA (US) | Santé US | BAA, encryption at rest + in transit, audit |
| SOC 2 Type II | Audit US | Contrôles attestés sur 6+ mois |
| FedRAMP (US) | Gouvernement US | High pour secret défense |

L'on-prem ne *donne* pas la conformité automatiquement — il en facilite l'obtention en éliminant les sous-traitants externes.

### Audit et traçabilité

- Logs centralisés (SIEM type Splunk, ELK) avec rétention conforme au cadre légal.
- Tous les prompts/responses loggés (selon politique, parfois hashés ou tronqués pour PII).
- Audit logs immutables (WORM storage, append-only).
- Voir [[05-ops-safety/23-llm-observability]] pour le format des traces.

## Coûts opérationnels réels

Le coût on-prem n'est pas seulement le hardware. Cinq postes :

1. **Hardware amorti** : H100 SXM ~30 k\$ pièce, GB200 NVL72 rack ~3 M\$ (sources marché secondaire). Amortissement sur 3-4 ans.
2. **Énergie** : à €0.10-0.20/kWh UE, un rack GB200 à 130 kW = ~€150k-300k/an d'électricité seule.
3. **Refroidissement** : PUE moderne ~1.2-1.4 sur datacenter liquid-cooled, donc +20-40% sur la facture énergie.
4. **Replacements** : 3-5% des GPU/an en défaillance, plus pour les premières générations Blackwell (early adopter pain).
5. **Staff** : 2-5 ETP dédiés pour un cluster de production sérieux (platform, SRE, security). À €100k-150k/an chargé.

Ordre de grandeur : un nœud 8× H100 production-grade coûte ~$300k CAPEX + ~$50-100k/an OPEX. Un cluster 64 GPU = ~$2.5M CAPEX + ~$500k-1M/an OPEX. Break-even vs cloud à utilization > 60-70% soutenu.

## Make vs colocation vs sovereign cloud

Trois variantes d'on-prem, du plus contrôlé au moins.

### Make (own datacenter)

- Contrôle total physique + juridique.
- CAPEX foncier + bâtiment + énergie + cooling.
- Seulement justifié pour très grands acteurs (Meta, banques top-tier, opérateurs souverains).

### Colocation

- Rack/cage loué chez Equinix, Digital Realty, Telehouse, Iron Mountain, etc.
- Énergie, cooling, network fournis ; le client met son hardware.
- Standard pour la plupart des on-prem enterprise.
- Lead time : 3-6 mois pour de la capacité liquid-cooled adéquate.

### Sovereign cloud

- OVHcloud, Scaleway, Outscale (France), T-Systems / STACKIT (DE), Aruba (IT), 3DS Outscale.
- Cloud public mais opéré sous juridiction locale uniquement.
- Pas vraiment de l'on-prem mais souvent classé comme tel par les régulateurs.
- Compromis : moins capacitaire que AWS/Azure/GCP, mais critique pour HDS / SecNumCloud / contraintes souveraineté.
- Hébergent Llama, Mistral, parfois Qwen.

### Mistral Compute / partenaires GPU-as-a-Service spécialisés

- **Mistral Compute** : cloud GPU vertical, datacenters EU (Bruyères-le-Châtel mid-2026, EcoDataCenter Suède 2027). Cible 200 MW Europe fin 2027.
- **CoreWeave, Lambda Labs, Crusoe, Nscale, Together AI** : neocloud spécialisés GPU, prix compétitifs, moins de overhead enterprise.
- Niveau intermédiaire entre cloud hyperscaler et on-prem strict.

## Études de cas comparées (2025-2026)

### Llama on-prem — le standard mondial

Llama 3.x est *le* modèle on-prem de fait. Banques US, défense, santé tournent dessus. Stack standard : 8× H100 sous Kubernetes + vLLM, ou 16-64 GPU pour 405B en TP+PP. Écosystème mature : `torchtune`, `transformers`, intégration native dans tous les serving stacks.

### Mistral on-prem — la souveraineté EU concrète

- **BNP Paribas** : déploiement on-prem KYC, fichiers incomplets 80% → 10%, plateforme rolled out à 65k users.
- **Armées françaises** (janv. 2026) : framework agreement AMIAD, ~€300M/an, infra française exclusive.
- **Schneider Electric** (industriel), **Thales** (défense) — partenaires Mistral Compute.
- Stack : Mistral Small / Magistral Small Apache 2.0 sur 1-2× H100, ou Mistral Large 3 sur 8× H100. Outillage `mistral-finetune` + Mistral AI Studio pour le tier production.

### DeepSeek on-prem — le pari hard-mode

DeepSeek-V3 (671B MoE / 37B actifs) déployable on-prem en MIT mais demande 8× H200 ou 8× B200 minimum. Adopté massivement en Chine, et chez les labos occidentaux pour les coûts d'inférence très bas. Friction : pas de support enterprise structuré, écosystème en construction.

### Qwen on-prem — le standard chinois

Qwen 2.5 / Qwen 3 Apache 2.0 sur la majorité des tailles. Dominant chez les clients Chine sous régulation. Multilingue solide, écosystème Alibaba Cloud accessible mais on-prem aussi pratiqué.

### Anthropic / OpenAI on-prem — quasi-impossible

Les modèles closed ne sont pas téléchargeables. L'unique chemin "on-prem-like" : Azure OpenAI sur Azure Stack Hub ou AWS Bedrock avec dedicated capacity — ce n'est pas vraiment on-prem mais du managed cloud avec data residency. Anthropic n'expose pas d'option on-prem générale.

## Implications nouvelles 2026

Le paysage évolue rapidement, plusieurs forces conditionnent l'on-prem aujourd'hui.

### Reasoning models

[[06-meta/34-reasoning-models|Test-time compute scaling]] multiplie la demande GPU par requête (les chaînes de raisonnement génèrent 10× à 100× plus de tokens output). Conséquence on-prem : il faut soit accepter des tokens/s effectifs très bas, soit massivement sur-provisionner. Magistral, R1, QwQ on-prem sont possibles mais coûteux en compute.

### Multimodal

[[06-meta/35-multimodal|Vision et audio]] changent les contraintes I/O (bande passante storage, prétraitement). Pixtral / Llama 4 / Voxtral on-prem demandent une pipeline image/audio devant le model serving — souvent sur CPU/GPU séparés.

### MCP et agent protocols

[[06-meta/36-mcp-agent-protocols|MCP]] sert d'interface entre l'agent et les tool servers. Sur on-prem, les MCP servers doivent être déployés à côté du serving, avec auth interne (mTLS, OIDC) et isolation par tenant si multi-équipe.

### Migration entre générations Nvidia

Hopper → Blackwell n'est pas trivial : nouvelle plomberie liquid cooling, racks différents, NCCL tuning à refaire, support vLLM/TensorRT-LLM à suivre. Plan multi-année pour les grandes flottes.

## Pièges courants

- **Sous-utilisation** : GPU à $30k qui tourne à 5% est pire qu'API.
- **Couplage à une version de vLLM** : modèle quantized AWQ qui ne fonctionne plus après upgrade serving stack.
- **Mauvaise estimation KV cache** : OOM en charge alors que single-request passait.
- **Network sous-dimensionné** : tensor parallelism multi-node étranglé par 200 GbE au lieu de 400 GbE.
- **Cooling sous-dimensionné** : thermal throttling silencieux, perf -20% non détectée sans monitoring DCGM.
- **Pas de stratégie de fallback** : cluster down sans backup managed cloud = incident produit.
- **Ignorer le budget énergie** : facture électricité explose au prochain hausse OPEX EU.
- **Pas de versioning hardware** : 3 générations de GPU dans le même cluster sans NCCL tuning par groupe.
- **Compliance demandée après build** : retrofitting HDS / SecNumCloud après-coup est très coûteux.

## Vocabulaire clé

`HGX`, `DGX`, `NVL72`, `NVLink`, `NVSwitch`, `GPUDirect RDMA`, `GPUDirect Storage`, `NCCL`, `InfiniBand NDR/XDR`, `RoCE v2`, `PFC` (Priority Flow Control), `DCQCN`, `Clos topology`, `rail-optimized`, `liquid cooling`, `direct-to-chip` (D2C), `CDU` (Coolant Distribution Unit), `PUE` (Power Usage Effectiveness), `MIG` (Multi-Instance GPU), `DCGM`, `Slurm`, `Bright`, `GPU Operator`, `air-gap`, `HDS hébergeur`, `SecNumCloud`, `ISO 27001`, `SOC 2`, `FedRAMP`, `colocation`, `neocloud`, `Mistral Compute`, `CoreWeave`, `Lambda Labs`.

## Synthèse

L'on-prem en pratique = quatre piliers à dimensionner ensemble : hardware (Nvidia H100/H200/B200/GB200 domine, AMD MI300X et alternatives crédibles ; lead time 6-12 mois ; Blackwell nécessite liquid cooling), réseau (NVLink/NVSwitch intra-node, InfiniBand NDR ou RoCE v2 inter-node selon scale et budget), datacenter (50-130 kW/rack pour Blackwell, refroidissement liquide obligatoire au-delà de H200), software (Kubernetes + GPU Operator pour inference, Slurm pour training, vLLM/TensorRT-LLM/SGLang pour serving). Sizing : 1× H100 pour 7-22B en BF16, 2× H100 pour 70B FP8, 8× H100 ou 8× B200 pour 200-405B FP8, plus 30-50% headroom et budget KV cache. Air-gap et compliance (HDS, SecNumCloud, ISO 27001, HIPAA, SOC 2, FedRAMP) sont facilités par l'on-prem mais demandent du travail. Coûts réels = hardware amorti + énergie (€150-300k/an pour un rack GB200) + cooling (+20-40%) + replacements + 2-5 ETP staff. Make vs colocation vs sovereign cloud (OVH, Scaleway, T-Systems, Mistral Compute, CoreWeave) selon contrainte juridique et CAPEX disponible. Sur les modèles : Llama est le standard mondial OSS, Mistral cible la souveraineté EU (BNP, Armées via AMIAD), DeepSeek-V3 est le hard-mode (671B MoE), Qwen le standard Asie, et OpenAI/Anthropic ne sont pas vraiment on-prem-able. Les nouvelles forces 2026 (reasoning models, multimodal, MCP, migration Hopper → Blackwell) pèsent sur les choix architecturaux. Piège central : sous-utilisation GPU et compliance demandée après build, deux erreurs structurellement coûteuses.
