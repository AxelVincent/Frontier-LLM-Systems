---
title: "32. Fine-tuning en pratique"
description: "LoRA, QLoRA, full FT — recettes, datasets, hyperparamètres, infra, évaluation, et l'outillage Mistral."
tags:
  - meta
aliases:
  - 32-fine-tuning-en-pratique
---

> [!info] Prérequis
> [[01-architecture/07-post-training-alignment|07. Post-training et alignment]] · [[06-meta/27-ft-vs-icl-vs-rag-vs-distill|27. FT vs ICL vs RAG vs distillation]] · [[06-meta/30-open-vs-closed-source|30. Open vs closed source]] — la décision *de* fine-tuner précède le *comment*.

> [!tip] Notes liées
> [[06-meta/31-on-prem-vs-cloud]] · [[02-inference/12-quantization-deep-dive]] · [[04-retrieval-quality/22-evals]] · [[05-ops-safety/26-multi-tenant-isolation]] · [[06-meta/29-production-failure-modes]]

## Le concept

[[06-meta/27-ft-vs-icl-vs-rag-vs-distill|27]] traite du *quand* fine-tuner (vs ICL, RAG, distillation). [[01-architecture/07-post-training-alignment|07]] traite du pipeline canonique (SFT → RLHF / DPO). Cette note traite du *comment concret* : quelle technique, quel dataset, quels hyperparamètres, quelle infra, quelle éval. C'est la note opérationnelle pour quelqu'un qui s'apprête à lancer un training run.

## Le spectre technique

Du plus heavy au plus lightweight :

```
Full FT              LoRA            QLoRA           Prefix/Prompt tuning
tous les              adapters         + base 4-bit    quelques
params trainable      bas-rang         quantized       embeddings only
~modèle complet       <1% params       <1% params      <0.01% params
en mémoire            trainable        trainable       trainable
```

### Full fine-tuning

Tous les paramètres bougent. Approche historique, devenue rare en pratique pour les modèles > 7B.

- **Mémoire** : ~16 octets par param avec Adam (params + grads + 2 états optim en FP32). Llama 70B en full FT ≈ 1.1 TB mémoire — multi-nœud requis.
- **Coût** : élevé, plusieurs nœuds H100 sur des jours.
- **Quand** : domain adaptation profond, alignment de masse (les labs eux-mêmes), recherche.
- **Risque** : [[01-architecture/07-post-training-alignment|catastrophic forgetting]] si dataset trop petit ou trop spécialisé.

### LoRA (Low-Rank Adaptation)

(Hu et al. 2021.) On freeze le modèle de base et on ajoute des **matrices bas-rang** sur certaines projections. La mise à jour `ΔW = A·B^T` où `A` et `B` sont petites (rank `r` typique : 4 à 64).

```
Forward pass : h = x · W + x · (A · B)
                     ↑ frozen   ↑ trainable
```

- **Mémoire trainable** : `r·(d_in + d_out)` au lieu de `d_in · d_out` → typiquement 0.1-1% des paramètres totaux.
- **Hyperparamètres clés** :
  - `r` : 8 typique, 16 pour tasks complexes, 64 si beaucoup de données.
  - `alpha` (scaling) : souvent `2·r` ou égal à `r`.
  - `target_modules` : `q_proj`, `v_proj` minimum ; ajouter `k_proj`, `o_proj`, MLP pour plus de capacité.
  - `dropout` : 0.05-0.1.
- **Atouts** :
  - Multi-tenant : un adapter par tenant, base partagée. Voir [[05-ops-safety/26-multi-tenant-isolation]].
  - Adapter switching à l'inference (vLLM supporte multiple LoRA adapters loaded).
  - Pas de catastrophic forgetting (base intacte).
  - Mergeable dans le base model si on veut un modèle unique en prod.
- **Limites** :
  - Capacité limitée si la tâche demande vraiment du knowledge update.
  - `r` trop bas → sous-fit ; trop haut → perte de l'avantage mémoire.

### QLoRA

(Dettmers et al. 2023.) LoRA + base model **quantized en 4-bit** (NF4 typiquement). L'archi gagnante pour fine-tuner gros modèles sur GPU modeste.

- **Mémoire** : Llama 70B fine-tunable sur 1× A100 80 GB ou 1× H100 80 GB.
- **Latency d'inference** : si on merge l'adapter dans le 4-bit base et qu'on sert quantized, latency comparable au modèle non FT. Sinon overhead léger.
- **Quand** : par défaut pour shops modestes. Quasi free lunch vs full FT en qualité sur la plupart des tâches downstream.

### Variantes

- **DoRA** (Weight-Decomposed LoRA, 2024) : décompose le poids en magnitude et direction, fine-tune les deux. Légèrement supérieur à LoRA pour le même r.
- **Prefix tuning** : on apprend un préfixe d'embeddings injecté à chaque couche. Très peu de params (<0.01%), capacité limitée.
- **P-tuning** / **prompt tuning** : embeddings soft prependés au prompt. Encore plus léger, surtout utile en multi-task.

En 2025, **QLoRA reste le default pratique**. DoRA pour les cas où on cherche le dernier point de qualité. Full FT seulement quand on a une vraie raison.

## Dataset : qualité > quantité

Le facteur le plus déterminant. Mauvais dataset = mauvais modèle, peu importe l'archi.

### Volume

- **Style / format transfer** : 500-2 000 paires bien curated suffisent.
- **Domain adaptation** : 5 000-50 000 exemples.
- **Tool use / function calling** : 1 000-10 000 trajectoires multi-turn.
- **Alignment (DPO sur préférences)** : 5 000-50 000 paires `(chosen, rejected)`.

Au-delà, gains marginaux décroissants sans curation très soigneuse.

### Format

Le format dépend de la baseline. Pour un modèle instruct (Mistral Instruct, Llama Instruct), respecter le template de conversation est non négociable :

```python
# Format ChatML / Mistral-style
{
  "messages": [
    {"role": "system", "content": "..."},
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ]
}
```

Erreur fréquente : oublier les special tokens (`<s>`, `[INST]`, `</s>`, etc.) du modèle de base — le modèle apprend alors un format dégradé et fait moins bien que le base.

### Curation

- **Dédup** : exact match + near-dup (MinHash, embedding similarity). Cf. [[01-architecture/04-tokenization]].
- **Contamination check** : pas d'exemples du test set dans le train set.
- **Quality filter** : LLM judge sur un échantillon, ou règles heuristiques (longueur, langue, refus).
- **Class balance** : si task multi-classe, vérifier la distribution.
- **Synthetic data** : OK si teacher fiable, mais risque d'amplifier les biais du teacher. Toujours mélanger avec du human-curated.

### Pièges

- **Réponses trop courtes / longues** : le modèle apprend la distribution de longueur, pas seulement le contenu.
- **Refus inappropriés** : si le dataset contient des refus mal contextualisés, le modèle devient over-refusing.
- **PII** : dataset doit être PII-scrubbed, sinon risque de régurgitation. Cf. [[05-ops-safety/26-multi-tenant-isolation]].

## Hyperparamètres

Valeurs de départ raisonnables (à ajuster selon dataset / modèle) :

| Paramètre | LoRA / QLoRA | Full FT |
|---|---|---|
| Learning rate | 1e-4 à 3e-4 | 1e-5 à 5e-5 |
| Batch size effective | 32-128 | 32-256 |
| Epochs | 1-3 | 1-2 |
| Warmup ratio | 0.03-0.1 | 0.03 |
| Scheduler | cosine | cosine |
| Weight decay | 0.0-0.01 | 0.01-0.1 |
| Gradient clipping | 1.0 | 1.0 |
| Mixed precision | BF16 | BF16 |

Notes :
- **Gradient accumulation** pour atteindre batch effectif sur petit GPU : `batch_per_device × accumulation_steps × n_devices`.
- **Epochs > 3 risque de overfitting**, surtout sur petits datasets.
- **Loss masking** : ne calculer la loss que sur les tokens de la response (pas les instructions). La plupart des frameworks le font par défaut, vérifier.

## Évaluation

Trois layers obligatoires :

### 1. Held-out set du task spécifique

- 10-20% du dataset gardé out-of-training.
- Métrique métier : exact match, F1, BLEU, rouge — selon task.
- LLM-as-judge si nécessaire (style, qualité subjective). Voir [[04-retrieval-quality/22-evals]].

### 2. Régression sur capabilities générales

- Run MMLU, HellaSwag, GSM8K, HumanEval sur le modèle fine-tuné vs base.
- Détecter [[01-architecture/07-post-training-alignment|catastrophic forgetting]] : si MMLU chute de 5+ points, c'est trop.
- Petit harness suffit : `lm-evaluation-harness` (EleutherAI) gère tout ça.

### 3. Eval en prod (shadow / A-B)

- Sample du traffic prod envoyé au modèle FT en parallèle du modèle prod actuel.
- Comparer : qualité (LLM judge ou human), latency, [[05-ops-safety/24-cost-attribution|cost]].
- Sortir l'A-B uniquement si gain significatif.

## Infra et outillage

Stack opérationnel typique 2025-2026 :

| Couche | Outils dominants | Alternatives |
|---|---|---|
| Framework training | Hugging Face `transformers` + `peft` + `trl` | `torchtune` (Meta, idiomatique PyTorch), lit-gpt |
| Recipe layer | **axolotl** (configs YAML), **unsloth** (single-GPU optimisé) | LLaMA-Factory, mlx-lm (Apple Silicon) |
| Stacks lab-specific | `mistral-finetune` (Mistral), `torchtune` (Meta) | — |
| Managed FT API | **OpenAI FT API**, **Mistral La Plateforme**, **Together AI**, **Fireworks**, **HuggingFace AutoTrain**, **AWS Bedrock Custom Models** | Anthropic n'expose pas de FT API public général |
| Enterprise full-stack | **Mistral Forge** (full pre-train + post-train + RL sur données client) | Together Enterprise, Databricks Mosaic AI |
| Tracking | Weights & Biases, MLflow | TensorBoard |
| Compute | H100 / H200 / B200 / GB200 | A100 / L40S (génération précédente), MI300X (AMD), Lambda Cloud, RunPod |
| Serving avec adapters | **vLLM** (LoRA multi-adapter), TGI | TensorRT-LLM, SGLang |

### Quel chemin choisir

- **Hacker solo / proto** : unsloth (single GPU, très optimisé) ou axolotl (configs YAML déclaratives) — agnostique du lab.
- **Stack Meta / Llama-first** : `torchtune` recipe library officielle, pleine intégration `transformers`.
- **Stack Mistral-first** : `mistral-finetune` officiel + La Plateforme managée + Forge pour l'enterprise lourd.
- **Closed FT only** : OpenAI FT API (4o-mini, certains 3.5) si on accepte data dans OpenAI ; Gemini FT via Vertex AI.
- **Shop sans équipe ML** : managed FT API du provider (OpenAI, Mistral, Together, Fireworks, AutoTrain).
- **Stack interne mature** : `transformers` + `peft` + `trl` + tracking maison, agnostique modèle.
- **Enterprise sur données propriétaires sensibles** : Mistral Forge (full training Mistral), Databricks Mosaic AI, ou pipeline custom on-prem.

## Études de cas comparées : FT chez chaque lab

Les approches FT diffèrent fortement selon la stratégie de chaque lab. Quatre archétypes.

### Meta / Llama — community-first, full open

- **Outillage officiel** : `torchtune` (recipe library PyTorch-native), pleine intégration avec `transformers`/`peft`/`trl`.
- **Pas de FT API managé** chez Meta — la communauté gère via HuggingFace AutoTrain, Together, Fireworks.
- **Llama Guard** family disponible pour FT safety side.
- Le FT Llama est devenu *le* standard de fait : la majorité des recettes axolotl/unsloth ciblent Llama en premier.

### Mistral — outillage propre + services managés

- **`mistral-finetune`** (GitHub, OSS) : repo officiel, LoRA + full FT supportés, configs pour tous les Mistral.
- **La Plateforme fine-tuning API** : managed FT sur Mistral Small (Nemo $1/M tokens) et Codestral ($3/M tokens), upload JSONL → modèle FT servi en API.
- **Mistral Forge** (mars 2026) : plateforme enterprise pour entraîner des modèles frontier *sur données propriétaires*, supportant full pre-training + post-training + RL. Adoptants early : Ericsson, ESA, Reply, DSO/HTX Singapore, ASML. Le pattern : client fournit corpus, Mistral fournit GPU + expertise, modèle déployé chez le client.
- **Mistral Vibe** : autonomous coding agent qui peut piloter Forge (FT, hyperparam search, scheduling, synthetic data generation).
- Découplage open weights / managed : FT en interne possible, déploiement libre (on-prem, sovereign cloud, Bedrock, Vertex AI).

### OpenAI — FT API closed avec garde-corps

- **FT API** disponible sur GPT-4o-mini, certaines versions GPT-3.5 et `o-mini`.
- Limites : modèles autorisés uniquement, modèle FT reste sur l'infra OpenAI, data envoyée à OpenAI pour le training (DPA / no-train opt-out disponibles enterprise), prix dégradés à long terme.
- C'est un FT "pour rester chez nous" — bon pour customer support, classification ; mauvais pour souveraineté.

### Anthropic — pas de FT API public

- Anthropic n'expose pas de FT API public général en 2025-2026.
- L'approche : modèles déjà très bien post-trained (Constitutional AI), prompt engineering + extended thinking comme primary lever.
- Pour les enterprise customers, Anthropic propose du custom alignment via contrat (rare, sélectif).

### Google — FT sur Vertex AI

- **Gemini FT via Vertex AI** : supervised tuning, RLHF distillation. Disponible sur Gemini Flash / Pro selon le niveau.
- **Gemma 2 / 3** open-weight FT via `transformers`, `torchtune`, ou Vertex AI Custom Models.
- Position intermédiaire : Gemma pour FT communautaire, Gemini pour FT managé closed.

### DeepSeek — pas de FT API, écosystème ouvert

- Les modèles DeepSeek (V3, R1) sont MIT, FT via la stack OSS standard (axolotl, unsloth, transformers).
- Pas de FT API managé direct chez DeepSeek — community-driven via Together AI, Fireworks, HuggingFace AutoTrain.

### Lecture des patterns

| Lab | FT outillage propre | FT API managé | Enterprise full-train |
|---|---|---|---|
| Meta | `torchtune` | Non | Via partenaires (Databricks, AWS) |
| Mistral | `mistral-finetune` | La Plateforme | Mistral Forge |
| OpenAI | — | FT API (limité) | Custom Model accord |
| Anthropic | — | Non | Custom alignment contrat rare |
| Google | — | Vertex AI Custom | Vertex AI Custom Models |
| DeepSeek | — | Non (via partenaires) | — |
| Qwen | — | Via Alibaba Cloud | Alibaba Cloud enterprise |

Le pattern dominant pour les data sensibles : open weight (Llama, Mistral, Qwen, DeepSeek) + FT custom sur GPU contrôlés (on-prem, sovereign cloud, ou compute dédié type Mistral Compute / Together Dedicated). Les FT API closed sont pratiques pour des cas non-sensibles mais perdent l'argument souveraineté.

## Recettes courantes

### Recette A : domain adaptation (juridique, médical, scientifique)

- 5 000-20 000 paires curated du domaine.
- QLoRA r=16, target `q,k,v,o,gate,up,down`.
- lr 2e-4, 2 epochs, batch effectif 64.
- Éval : task-specific + MMLU regression check.
- Base recommandée : Llama 3.3 70B (standard de fait), Mistral Small 22B, ou Qwen 2.5 selon licence/langue.

### Recette B : style transfer / format (output JSON strict, ton brand)

- 500-2 000 paires impeccables.
- QLoRA r=8, target `q,v` uniquement.
- lr 1e-4, 1-2 epochs, batch effectif 32.
- Éval : LLM-judge sur conformité format + style.
- Base : modèle instruct du domaine.

### Recette C : tool use / function calling specialization

- 1 000-10 000 trajectoires multi-turn avec tool calls structurés.
- QLoRA r=16-32, target tous les projections + MLP.
- lr 1e-4, 2-3 epochs.
- Éval : tool selection accuracy, schema conformity ([[03-applied/16-structured-outputs|cf. 16]]).

### Recette D : alignment via DPO (préférences)

- 5 000-50 000 paires `(prompt, chosen, rejected)`.
- Démarre d'un modèle SFT-é (recette A ou B).
- QLoRA r=16, lr 5e-7 (très bas, DPO est sensible).
- β (KL strength) : 0.1 typique.
- 1 epoch suffit, plus risque de divergence.

## Pièges classiques

- **Apprendre les special tokens à l'envers** — voir Format ci-dessus.
- **lr trop élevé** → divergence, ou worse, modèle apparemment OK mais avec capacités générales détruites.
- **Pas de eval baseline avant** — impossible de savoir si le FT a aidé.
- **Évaluer uniquement sur le held-out task-specific** — manque le catastrophic forgetting.
- **Fine-tuner trop tôt** : si ICL ou RAG suffit ([[06-meta/27-ft-vs-icl-vs-rag-vs-distill|cf. 27]]), c'est de l'overengineering.
- **Cross-tenant leakage** : full FT sur un dataset multi-client = data d'un client peut sortir dans la réponse d'un autre. LoRA par tenant atténue. Voir [[05-ops-safety/26-multi-tenant-isolation]].
- **Versioning absent** : adapter `v17_final_final` sans tracking — irreproductible.
- **Pas de A-B en prod** — on shippe un modèle FT et on découvre 2 semaines après qu'il est pire sur le tail.

## Vocabulaire clé

`full fine-tuning`, `LoRA`, `QLoRA`, `DoRA`, `rank`, `alpha`, `target modules`, `adapter`, `prefix tuning`, `P-tuning`, `loss masking`, `gradient accumulation`, `mixed precision BF16`, `cosine schedule`, `warmup ratio`, `catastrophic forgetting`, `MMLU regression`, `LLM-as-judge`, `lm-evaluation-harness`, `axolotl`, `unsloth`, `mistral-finetune`, `torchtune`, `Mistral Forge`, `peft`, `trl`, `AutoTrain`, `Vertex AI Custom`, `held-out set`, `adapter merging`, `shadow eval`, `cross-tenant leakage`.

## Synthèse

Fine-tuner en pratique se résume à : (1) choisir la technique — QLoRA par défaut, full FT seulement avec vraie raison, DoRA pour le dernier point de qualité ; (2) curer le dataset — qualité > quantité, 1k-50k exemples bien formatés au template du modèle, dédup et contamination check ; (3) hyperparamètres — lr 1e-4 LoRA / 2e-5 full, 1-3 epochs, cosine schedule, BF16 ; (4) évaluer en trois layers — held-out task-specific, regression sur MMLU/HellaSwag pour catastrophic forgetting, A-B en prod ; (5) outillage — axolotl / unsloth pour solo, `torchtune` pour stack Llama, `mistral-finetune` pour stack Mistral, managed FT API si pas d'équipe ML. Le paysage 2025-2026 se lit par lab : Meta mise sur l'écosystème community-first (`torchtune`) sans FT API managé, Mistral occupe le créneau hybride avec `mistral-finetune` OSS + La Plateforme + **Mistral Forge** pour le full-training enterprise sur données propriétaires (Ericsson, ESA, ASML), OpenAI propose un FT API closed limité aux modèles autorisés, Anthropic n'expose pas de FT public, Google offre Gemma OSS + Gemini Vertex AI Custom, DeepSeek et Qwen restent OSS sans FT API direct. Le pattern dominant pour données sensibles : open weight + FT custom sur GPU contrôlés (on-prem, sovereign cloud, ou compute dédié).
