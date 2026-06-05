---
title: "07. Post-training et alignment"
description: "SFT, RLHF, DPO, Constitutional AI : transformer un base model en assistant qui suit des instructions."
tags:
  - architecture
aliases:
  - 29-post-training-alignment
  - 07-post-training-alignment
---

> [!tip] Notes liées
> [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]] · [[04-retrieval-quality/22-evals]] · [[05-ops-safety/25-safety-engineering]] · [[01-architecture/06-distributed-training]]

## Le pipeline canonique

Le pre-training produit un modèle "base" : capable de prédire le token suivant sur du texte général, mais peu utile en l'état. Le post-training transforme ce modèle base en un modèle "instruct" ou "chat" aligné sur des préférences humaines et capable de suivre des instructions.

> [!example] Intuition — base vs instruct
> Un base model est optimisé pour une seule chose : la **next-token prediction** sur la distribution du corpus de pre-training. Il complète, il ne répond pas. Soumis à « Bonjour, comment ça va ? », il peut produire « disait Jean en regardant la pluie » — continuation plausible selon le corpus. Le post-training réoriente cette capacité brute vers un format dialogique : suivre une instruction, refuser une demande dangereuse, adopter un persona stable.

Le pipeline canonique moderne :

1. **Pre-training** : next-token prediction sur des trillions de tokens.
2. **SFT** (Supervised Fine-Tuning) : fine-tuning sur des exemples (instruction, response).
3. **Alignment** : RLHF, DPO, ou variantes pour aligner le modèle sur des préférences.

## SFT (Supervised Fine-Tuning)

Fine-tuning standard sur un dataset de paires (instruction, response) curated.

- Le modèle apprend à produire des réponses dans le style et le format souhaités.
- Format de prompt typique : `<|user|> question <|assistant|> answer`.
- Dataset typique : 10k à 1M exemples. Qualité > quantité.
- Loss : cross-entropy standard, souvent uniquement sur les tokens de la response (masking de la instruction).

### Instruction tuning

Variante de SFT où le dataset contient une **diversité d'instructions** couvrant de nombreuses tâches (question answering, summarization, code, reasoning, etc.). Améliore la généralisation zero-shot.

Datasets canoniques : FLAN, Alpaca, ShareGPT, Open-Hermes, OpenAssistant.

## RLHF (Reinforcement Learning from Human Feedback)

Introduit par OpenAI (Christiano et al. 2017, InstructGPT 2022). Pipeline en trois étapes :

### 1. Collecte de préférences

Humains annotent des paires (prompt, response_A, response_B) en indiquant laquelle est préférable. Dataset de ~10k à ~100k préférences.

### 2. Reward model training

Entraîner un modèle séparé qui prédit la préférence humaine à partir d'une (prompt, response). Loss : Bradley-Terry, qui modélise la préférence comme une fonction logistique de la différence de scores.

```
P(A > B) = sigmoid(reward(A) - reward(B))
```

### 3. RL fine-tuning (PPO)

Optimiser le modèle pour **maximiser le reward** prédit par le reward model, avec une contrainte de **KL divergence** pour rester proche du modèle SFT initial (empêche le reward hacking).

> [!example] Intuition — la structure RLHF
> RLHF est un pipeline en trois étages :
> 1. **SFT** apprend la distribution `p(response | instruction)` sur des exemples curated.
> 2. **Reward model** apprend `r(prompt, response) → ℝ` à partir de préférences pairwise (Bradley-Terry).
> 3. **PPO** optimise la policy contre ce reward, avec une pénalité KL vers la policy SFT.
>
> La pénalité KL est la pièce critique : sans elle, la policy dérive vers les régions où le reward model est mal calibré et produit du *reward hacking*. C'est une contrainte de proximité à un prior connu sain.

```
maximize  E[reward(response)] - β · KL(π || π_SFT)
```

Algorithme : **PPO** (Proximal Policy Optimization), classique en RL.

### Limites de RLHF

- Complexité : pipeline en 3 étapes, instable, hyperparamètres sensibles.
- Coût compute : doit maintenir 4 modèles en mémoire (policy, ref policy, reward model, value model).
- Reward hacking : le modèle peut optimiser pour le reward model sans réelle amélioration qualitative.
- Difficile à reproduire.

## DPO (Direct Preference Optimization)

(Rafailov et al. 2023.) Reformule RLHF en une **loss supervisée directe** sur les paires de préférences, **sans reward model explicit**.

Idée centrale : la solution optimale de l'objectif RLHF peut être exprimée en forme close, ce qui permet de dériver une loss directement applicable au modèle.

```
L_DPO = -log sigmoid(β · (log(π(y_w | x) / π_ref(y_w | x)) - log(π(y_l | x) / π_ref(y_l | x))))
```

avec `y_w` la response préférée, `y_l` la rejetée, `π` la policy à entraîner, `π_ref` la policy de référence (SFT).

Avantages vs RLHF :
- Pas de reward model.
- Pipeline simple : SFT puis DPO.
- Plus stable, moins d'hyperparamètres.
- Reproduit ou bat RLHF sur la plupart des benchmarks.

Devenu le standard moderne pour l'alignment.

## Variantes de DPO

### IPO (Identity Preference Optimization)

Corrige une tendance de DPO à overfit sur des préférences peu informatives. Remplace la sigmoid par une identity loss.

### KTO (Kahneman-Tversky Optimization)

Au lieu de paires de préférences, utilise des **signaux unaires** (réponse jugée "bonne" ou "mauvaise"). Plus facile à collecter en pratique.

### ORPO (Odds Ratio Preference Optimization)

Combine SFT et preference optimization en **une seule étape** d'entraînement, en utilisant l'odds ratio entre response préférée et rejetée. Pipeline d'une étape au lieu de deux.

## Constitutional AI (Anthropic)

Approche alternative à RLHF (Bai et al. 2022). Le modèle génère lui-même des critiques et réécritures de ses propres responses selon une **constitution** (liste de principes), réduisant la dépendance aux annotations humaines.

Pipeline :
1. SFT.
2. **AI feedback** : le modèle critique et révise ses propres responses selon la constitution.
3. RL sur les préférences AI-generated.

Permet de scaler l'alignment avec moins de label humain. Adopté par Claude.

## Instruction tuning vs preference tuning

- **Instruction tuning (SFT)** : enseigne au modèle à suivre des instructions et à adopter un format.
- **Preference tuning (RLHF/DPO)** : affine selon des préférences humaines de qualité, ton, sécurité.

Le pipeline canonique combine les deux : SFT d'abord pour le format, puis preference tuning pour la qualité fine.

## Hallucinations : sources et mitigations

### Sources

- **Knowledge cut-off** : le modèle invente des informations sur des événements post-entraînement.
- **Long-tail facts** : le modèle confond des faits similaires (mauvaise date, mauvais auteur).
- **Confabulation under pressure** : le modèle invente plutôt que de dire "je ne sais pas".
- **Reward hacking** : RLHF peut renforcer des responses confiantes même quand elles sont fausses (préférence humaine biaisée vers la confiance).

### Mitigations

- **RAG** : ancrer les responses dans du retrieval. Voir [[04-retrieval-quality/20-rag-architecture]].
- **Calibration** : entraîner le modèle à exprimer son incertitude.
- **Self-consistency** : générer plusieurs responses et vérifier l'accord.
- **Verification** : second pass où le modèle vérifie ses propres claims.
- **Constitutional principles** : inclure "express uncertainty when unsure" dans la constitution.
- **Eval** : adversarial sets ciblés sur la calibration. Voir [[04-retrieval-quality/22-evals]].

## Vocabulaire clé

`pre-training`, `post-training`, `SFT` (Supervised Fine-Tuning), `instruction tuning`, `RLHF` (Reinforcement Learning from Human Feedback), `reward model`, `Bradley-Terry`, `PPO` (Proximal Policy Optimization), `KL penalty`, `KL divergence`, `reward hacking`, `DPO` (Direct Preference Optimization), `IPO`, `KTO`, `ORPO`, `Constitutional AI`, `AI feedback`, `preference tuning`, `policy`, `reference policy`, `hallucination`, `confabulation`, `calibration`.

## Synthèse

Le post-training transforme un modèle base (next-token prediction) en modèle aligné sur des instructions et préférences. SFT (Supervised Fine-Tuning) sur des paires (instruction, response) enseigne le format. Instruction tuning étend le SFT à une grande diversité de tâches. RLHF entraîne un reward model sur des préférences humaines puis fine-tune via PPO avec une KL penalty contre la policy SFT — pipeline complexe et instable. DPO élimine le reward model en dérivant la loss optimale en forme close, devenu le standard moderne. Variantes : IPO, KTO (signaux unaires), ORPO (SFT + preference en une étape). Constitutional AI scale l'alignment avec AI feedback selon une constitution. Hallucinations proviennent du knowledge cut-off, des long-tail facts, du reward hacking ; mitigations via RAG, calibration, self-consistency, verification, et eval adversariale.
