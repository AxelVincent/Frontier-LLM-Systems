---
title: "37. EU AI Act et régulation GPAI"
description: "Timeline, classifications (GPAI vs high-risk vs systemic risk), obligations, seuils techniques (10^25 FLOPs), et postures des labs."
tags:
  - meta
aliases:
  - 37-eu-ai-act
---

> [!info] Prérequis
> [[06-meta/31-on-prem-vs-cloud|31. On-prem vs cloud]] · [[06-meta/30-open-vs-closed-source|30. Open vs closed source]] — la régulation conditionne les choix de déploiement et de fournisseur, surtout pour les acteurs servant l'UE.

> [!tip] Notes liées
> [[05-ops-safety/25-safety-engineering]] · [[05-ops-safety/26-multi-tenant-isolation]] · [[06-meta/33-on-premise-en-pratique]] · [[04-retrieval-quality/22-evals]]

## Le concept

L'**EU AI Act** (règlement (UE) 2024/1689) est entré en vigueur le **1er août 2024**. C'est le premier cadre légal complet au monde sur l'IA. Il classe les systèmes par niveau de risque et impose des obligations proportionnées, avec une attention particulière aux **GPAI** (General-Purpose AI Models) — les LLM frontier en font partie.

Pour tout LLM mis sur le marché en UE — peu importe où il est entraîné ou hébergé — le Règlement s'applique. Conséquence directe pour le wiki : tout acteur qui shippe une feature LLM consommée par des users UE est dans le scope.

## Classification des systèmes IA

Le Règlement classe par niveau de risque, du plus interdit au plus libre.

| Niveau | Exemples | Obligations |
|---|---|---|
| **Prohibited** | Social scoring gouvernemental, manipulation cognitive, identification biométrique temps-réel dans espace public (sauf exceptions) | Interdit. En vigueur depuis 2 fév. 2025. |
| **High-risk** | Recrutement RH, scoring crédit, dispositifs médicaux, justice, infra critique, éducation, asylum/border control | CE marking, conformity assessment, documentation, monitoring post-marché. **Pleinement applicable 2 août 2026**. |
| **Limited risk** | Chatbot grand public, deepfakes | Transparence (informer user qu'il parle à une IA, étiqueter contenu généré) |
| **Minimal risk** | Filtres anti-spam, recommandation jeux vidéo | Code de conduite volontaire |

Le statut "high-risk" ne dépend pas du modèle utilisé, mais de l'**usage** : un même LLM peut être utilisé en assistance créative (minimal risk) ou en sélection candidats RH (high-risk) — le seuil légal est dans l'application.

## GPAI : régime spécifique

À côté des classifications par usage, un régime parallèle s'applique aux **modèles de fondation eux-mêmes** : les GPAI.

### Définition GPAI

Un GPAI est un modèle qui peut accomplir une grande variété de tâches distinctes et qui peut être intégré dans des systèmes en aval. En pratique : tout LLM frontier (Claude, GPT, Gemini, Llama, Mistral, Qwen, DeepSeek).

### Deux niveaux GPAI

**GPAI standard** — tous les LLM frontier.
**GPAI avec risque systémique** — modèles particulièrement capables, présumés dangereux par seuil de compute.

### Le seuil de risque systémique : 10²⁵ FLOPs

Article 51 du Règlement : un GPAI est **présumé** présenter un risque systémique si son compute cumulé de training dépasse **10²⁵ FLOPs**.

12 modèles connus dépassent ce seuil en 2025 (estimation), incluant : modèles frontier d'OpenAI, Google, Anthropic, Meta, Mistral. Le provider peut présenter des arguments pour démontrer que malgré le seuil, son modèle ne pose pas de risque systémique — mais la charge de la preuve est inversée.

Notification obligatoire : le provider doit notifier la Commission **dans les 2 semaines** dès qu'il prévoit raisonnablement d'atteindre le seuil.

## Timeline

| Date | Étape | Public concerné |
|---|---|---|
| 1 août 2024 | **Entrée en vigueur** | Texte adopté |
| 2 fév 2025 | **Pratiques interdites** + AI literacy | Tous |
| 2 août 2025 | **Obligations GPAI** applicables, gouvernance (AI Office) | Providers GPAI |
| **2 août 2026** | **Pleinement applicable** : high-risk, transparence, enforcement actif | Tous + enforcement Commission |
| 2 août 2027 | Obligations high-risk pour produits déjà sur le marché (transitoire) | Existing high-risk products |

Le seuil critique pour l'écosystème LLM : **2 août 2026** — date à laquelle l'enforcement actif commence (formal requests for information, model recalls, administrative fines).

## Obligations GPAI standard

Applicables depuis 2 août 2025 à tous les providers GPAI :

1. **Technical documentation** — incluant training, testing, evaluation results. Mise à disposition du AI Office et national authorities sur demande.
2. **Information for downstream providers** — capabilities, limitations, intended use, conditions d'usage.
3. **Copyright compliance policy** — politique respectant la directive Copyright UE, notamment opt-outs des ayants droit (TDM Reservation).
4. **Public training data summary** — résumé suffisamment détaillé du contenu utilisé pour le training.

L'effort de documentation est non-trivial : un provider Mistral, Meta ou OpenAI doit publier un *training data summary* exposant grossièrement les sources.

## Obligations GPAI avec risque systémique

Stack additionnel applicable aux modèles > 10²⁵ FLOPs :

1. **Model evaluations** — incluant adversarial testing (red teaming) documenté.
2. **Systemic risk assessment** — identification et mitigation des risques.
3. **Serious incident reporting** — au AI Office et autorités compétentes sans délai injustifié.
4. **Cybersecurity protection** — état de l'art pour le modèle et l'infrastructure physique.

Ces obligations sont *en plus* de celles GPAI standard.

## Sanctions

Fines possibles :
- **Pratiques interdites** : jusqu'à €35M ou 7% du chiffre d'affaires mondial.
- **Non-conformité high-risk** : jusqu'à €15M ou 3%.
- **Documentation et obligations GPAI** : jusqu'à €15M ou 3%.
- **Faux/incomplete information aux autorités** : jusqu'à €7.5M ou 1%.

Les fines sont calculées sur le chiffre d'affaires *mondial* — pas seulement UE. Pour un acteur frontier (OpenAI, Google) le risque réel est en milliards.

## Postures des labs face à l'AI Act

Les positionnements publics divergent fortement.

### Mistral — conformité native

Mistral, basé en France, se positionne comme **naturellement aligné** : data residency EU, training et serving en juridiction EU, transparence sur les modèles Apache 2.0. Le Règlement est traité comme un avantage compétitif vs OpenAI/Anthropic. Argument de vente enterprise (BNP, Armées, Schneider) : "vous êtes déjà compliant avec nous".

### Anthropic — Responsible Scaling Policy (RSP)

Anthropic publie depuis 2023 sa **Responsible Scaling Policy** : framework de safety levels (ASL-1 à ASL-4+) avec evals et mitigations associés. Position publique : volonté d'aller au-delà de la conformité, alignement avec l'esprit du Règlement. Constitutional AI et red teaming structuré sont des arguments naturels.

### OpenAI — Preparedness Framework

OpenAI a un **Preparedness Framework** (déc. 2023) qui définit des seuils de capacité (cybersecurity, persuasion, model autonomy, CBRN) avec gating sur le déploiement. Tension publique avec l'EU sur certaines clauses (data residency, opt-out training). Lobby actif.

### Google DeepMind — Frontier Safety Framework

**Frontier Safety Framework** (2024) similaire en structure, focus sur les capabilities critiques (autonomy, cyber, bio). Position alignée avec la conformité EU via Vertex AI EU data residency.

### Meta / Llama — open weight tension

Position complexe : open weight implique que Meta n'a pas le contrôle aval (où Llama est déployé, comment, par qui). Lobby actif sur les obligations downstream providers vs upstream providers — Meta argumente qu'un provider open weight ne peut pas répondre des usages downstream.

### DeepSeek / Qwen — chinois, scope ambigu

Modèles entraînés en Chine, déployés mondialement via API ou open weight. Quand consommés en UE, ils tombent dans le scope du Règlement — mais l'enforcement extraterritorial est complexe. Sujets de discussion ouverts dans la Commission.

## Implications opérationnelles

### Pour les providers GPAI

- Equipe legal + safety dédiée.
- Pipeline doc training data (sources, durée, compute, énergie).
- Red teaming structuré documenté.
- Processus incident report < 24h vers AI Office.
- Pour les modèles > 10²⁵ FLOPs : cybersécurité renforcée (audits, pentests, supply chain).

### Pour les downstream consumers (apps qui consomment un LLM)

- Vérifier que le provider GPAI est conforme (sinon le risque remonte).
- Si usage **high-risk** (RH, crédit, médical, justice...), implementer le full conformity assessment : risk management, data governance, technical doc, transparency, human oversight, accuracy/robustness/cybersecurity, post-market monitoring.
- Transparency obligatoire pour limited risk : informer user qu'il parle à une IA.
- **CE marking** pour high-risk, EU database registration.

### Architecture induite

L'AI Act pousse vers :
- **Data residency UE** pour minimiser les surprises (DPA, accords sous-traitance).
- **Open weight + on-prem** pour les use cases sensibles (banque, santé, défense) — pousse Llama, Mistral, sovereign cloud.
- **Audit logs structurés** (chaque inference loggée, métadonnées, justifications).
- **Eval golden sets** documentés et versionnés.
- **Red team continue** pour les usages sensibles ou les modèles frontier déployés.

## Articulation avec autres réglementations

L'AI Act ne remplace pas les régulations existantes — il s'ajoute :
- **RGPD/GDPR** — protection des données personnelles. Le LLM qui mémorise des données users tombe sous RGPD *en plus* de l'AI Act.
- **NIS2** — cybersecurity infrastructure critique.
- **DSA** — Digital Services Act (plateformes, contenu).
- **DORA** — Digital Operational Resilience Act (finance).
- **HDS** (France) — Hébergeur de Données de Santé.
- **AI Liability Directive** (en discussion) — régime de responsabilité civile.

Pour une banque française qui ship une feature LLM : AI Act + RGPD + DORA + ACPR + (potentiellement) HDS.

## Pièges courants

- **Croire que open weight = exempt** — non, l'AI Act vise le provider GPAI initial.
- **Croire que servir hors UE = exempt** — si users UE, le scope s'applique.
- **Ne pas tracker le seuil 10²⁵ FLOPs** — l'omettre c'est rater la notification 2 semaines.
- **Pas de chain of custody training data** — impossible de produire le training data summary requis.
- **Confondre high-risk usage et frontier model** — un GPT-4o (frontier) utilisé en chatbot FAQ n'est pas "high-risk", un Llama 3.1 8B (non-frontier) utilisé en sélection CV l'est.
- **Pas de human oversight pour high-risk** — obligation légale, pas une option produit.
- **Croire que "AI Act compliance" est un seul livrable** — c'est une posture continue : doc, eval, monitoring, incident response.

## Vocabulaire clé

`EU AI Act`, `Règlement (UE) 2024/1689`, `GPAI` (General-Purpose AI), `systemic risk`, `Article 51`, `Article 55`, `seuil 10²⁵ FLOPs`, `prohibited practices`, `high-risk system`, `limited risk`, `conformity assessment`, `CE marking`, `EU AI Office`, `national competent authority`, `training data summary`, `TDM Reservation`, `Responsible Scaling Policy` (Anthropic), `Preparedness Framework` (OpenAI), `Frontier Safety Framework` (Google), `red teaming`, `serious incident report`, `RGPD/GDPR`, `NIS2`, `DSA`, `DORA`, `HDS`, `AI Liability Directive`.

## Synthèse

L'EU AI Act (Règlement (UE) 2024/1689, entré en vigueur 1 août 2024) classe les systèmes IA par niveau de risque (prohibited / high-risk / limited / minimal) et impose un régime parallèle aux GPAI (general-purpose AI models). Deux niveaux GPAI : standard (training data summary, technical documentation, copyright policy, info downstream) et **avec risque systémique** présumé au-delà de **10²⁵ FLOPs** de compute training (12 modèles connus en 2025, dont les frontier OpenAI / Google / Anthropic / Meta / Mistral). Obligations additionnelles pour systemic risk : adversarial testing documenté, risk assessment, serious incident reporting, cybersecurity état de l'art. Timeline : obligations GPAI applicables depuis 2 août 2025, **pleinement applicable et enforcement actif 2 août 2026**, sanctions jusqu'à €35M ou 7% CA mondial. Postures labs : Mistral conformité native (avantage compétitif EU), Anthropic Responsible Scaling Policy, OpenAI Preparedness Framework (lobby actif), Google Frontier Safety Framework, Meta tension open weight upstream/downstream, DeepSeek/Qwen scope ambigu. Implications pratiques pour shippers UE : data residency UE, open weight + on-prem pour use cases sensibles, audit logs structurés, eval continu, red team. L'AI Act s'ajoute à RGPD / NIS2 / DSA / DORA / HDS — pas de substitution. Piège central : croire que "AI Act compliance" est un livrable unique, alors que c'est une posture continue de documentation, evaluation, monitoring et incident response.
