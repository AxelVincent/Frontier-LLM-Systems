---
title: "35. Multimodal : vision et audio"
description: "Vision-language models (Pixtral, GPT-4o, Gemini, Llama 4), audio (Voxtral, Whisper, Realtime API), TTS, fusion strategies, et architectures unifiées."
tags:
  - meta
aliases:
  - 35-multimodal
---

> [!info] Prérequis
> [[01-architecture/01-transformer-architecture|01. Transformer architecture]] — pour la base attention/tokenization. [[01-architecture/04-tokenization|04. Tokenization]] — pour comprendre comment les patches images et audio frames s'intègrent dans la même séquence.

> [!tip] Notes liées
> [[06-meta/34-reasoning-models]] · [[06-meta/30-open-vs-closed-source]] · [[02-inference/09-prefill-vs-decode]] · [[03-applied/14-context-engineering]]

## Le concept

Jusqu'en 2023, les LLM étaient text-only. À partir de 2024-2025, le multimodal devient natif : un seul modèle ingère **texte + images + audio** et produit **texte + audio**, sans pipeline cousue de modèles séparés (Whisper → LLM → TTS).

Trois modalités principales :
- **Vision** : images, document scans, vidéo (frames échantillonnées).
- **Audio** : speech recognition, audio understanding, music.
- **Speech / TTS** : génération audio en sortie, voice cloning, real-time conversation.

Deux familles d'architectures coexistent : **modèles unifiés** (un seul Transformer ingère et produit toutes modalités) et **modèles modulaires** (vision/audio encoders distincts feedant un LLM textuel).

## Vision-language models (VLM)

### Architecture canonique

```
Image → Vision encoder (ViT) → patches embeddings → projection → injection dans le LLM
```

1. L'image est découpée en **patches** de taille fixe (16×16 pixels typique pour ViT, 14×14 ou 32×32 selon variantes).
2. Chaque patch devient un token visuel embeddé.
3. Une projection (MLP ou cross-attention) adapte les embeddings à l'espace du LLM.
4. Les vision tokens sont injectés dans la séquence d'entrée du LLM, mélangés au texte.

Une image 1024×1024 = ~4 000 patches en 16×16 → ~4 000 tokens supplémentaires. Le contexte effectif est donc fortement consommé par l'image — implication directe sur [[02-inference/08-kv-cache-management|KV cache]] et coût.

### Stratégies de fusion

| Stratégie | Description | Latency | Qualité |
|---|---|---|---|
| **Early fusion** | Vision tokens injectés dès l'embedding du LLM | Faible | Bonne |
| **Intermediate fusion** | Cross-attention entre vision et text à plusieurs couches | Moyenne | Très bonne |
| **Late fusion** | Vision encoder séparé, modalités fusionnées en fin de pipeline | Élevée | Max sur certains benchmarks |

Tendance 2025-2026 : **early fusion native** (modèles vraiment unifiés type GPT-4o, Llama 4, Mistral Small 4) plutôt que late fusion (style LLaVA original).

### Modèles VLM 2025-2026

| Modèle | Lab | Licence | Notes |
|---|---|---|---|
| **GPT-4o** | OpenAI | Closed | Natif multimodal, vision + audio + texte unifiés |
| **Gemini 2 Pro / Ultra** | Google | Closed | Long context multimodal (1M+ tokens), video natif |
| **Claude 3.5/4 vision** | Anthropic | Closed | Vision excellente sur documents, charts |
| **Pixtral 12B** | Mistral | Apache 2.0 | OSS, ViT-large encoder, intégré dans Mistral Small 4 |
| **Llama 4** (2025) | Meta | Community license | Multimodal natif, vision + texte |
| **Qwen2-VL / Qwen3-VL** | Alibaba | Apache 2.0 | OSS, top open-weight VLM, multi-image |
| **NVLM** | Nvidia | Open | Recherche, fusion strategy explorée |
| **Phi-3-vision / Phi-4-multimodal** | Microsoft | MIT | Petits modèles edge-able |

### Cas d'usage VLM

- **OCR avancé** : Pixtral, Qwen2-VL excellents sur documents structurés (tables, forms).
- **Visual Question Answering (VQA)** : GPT-4o, Claude, Gemini pour Q&A sur images.
- **UI understanding** : agents qui voient les écrans (Anthropic Computer Use, OpenAI Operator).
- **Charts et graphs** : Claude particulièrement performant sur l'extraction depuis visualisations.
- **Vidéo** : Gemini long context (frames échantillonnées), GPT-4o sur clips courts.
- **Image generation** : couplé à un decoder image (DALL-E 3, Imagen, Gemini image gen, Mistral Pixtral image gen 2026).

## Audio understanding (ASR + ALM)

Deux familles :

### Speech-to-text (ASR) classique

Pipeline traditionnel : audio → encoder → text. Pas vraiment LLM mais souvent intégré.
- **Whisper v3 / v3-turbo** (OpenAI) : standard de fait OSS, multilingue, ~99 langues.
- **NVIDIA Parakeet / Canary** : alternatives Nvidia.
- **AssemblyAI, Deepgram** : APIs commerciales avec features (diarisation, timestamps).

### Audio language models (ALM)

Modèles unifiés audio + texte, qui comprennent au-delà de la transcription : intent, emotion, contexte audio (music vs speech, langue, accent).

- **Voxtral Small (24B) / Mini (3B)** (Mistral, juillet 2025) : premier audio model open weight enterprise-grade. Apache 2.0 sur Small et Mini.
- **GPT-4o audio** (OpenAI) : audio natif unifié avec texte.
- **Gemini 2 audio** (Google) : audio input intégré.
- **Whisper successors et fine-tunes** : pour transcription pure.

## Génération audio et voice (TTS)

### TTS classique

- **ElevenLabs** : leader marché, voice cloning, multilingue.
- **OpenAI TTS** (modèles tts-1, tts-1-hd, gpt-4o-mini-tts) : pricing accessible.
- **Google Cloud TTS, Azure TTS** : enterprise standard.

### TTS frontier 2025-2026

- **Voxtral TTS** (Mistral, mars 2026) : built sur Ministral 3B, 8 GB BF16, runnable single GPU 16 GB+, zero-shot voice cloning, multilingue, real-time streaming. Concurrent direct d'ElevenLabs.
- **Cartesia Sonic** : ultra-low latency, modèles SSM (Mamba-based) pour streaming.
- **Sesame** : conversation naturelle.

## Architectures unifiées 2025-2026

Le mouvement clé : un seul modèle qui ingère et produit toutes modalités.

### GPT-4o (OpenAI, mai 2024)

- **Natif** unifié speech + vision + text — pas de pipeline cousue.
- Latency conversation ~250ms (vs ~3s pipeline classique).
- Audio in + audio out + image in + text in/out dans un seul forward pass.
- **OpenAI Realtime API** (août 2025) : exposition de cette capability via WebSocket pour voice agents low-latency.

### Mistral Small 4 (mars 2026)

- **Unifie Magistral** (reasoning) + **Pixtral** (vision) + **Devstral** (code).
- Un seul modèle, multiple modes accessibles.
- Apache 2.0.

### Llama 4 (Meta, 2025)

- Natif multimodal, vision + texte.
- Conserve la philosophie open-weight Community License.

### Gemini 2 (Google)

- Long context (1M+ tokens) multimodal.
- Video natif (frames échantillonnées + audio synchronisé).
- Strength : capacité à traiter de très longs documents multimodaux.

## Implications opérationnelles

### Tokens visuels et coût

Une image 1024×1024 = ~4k tokens. Pricing typique 2025 :
- GPT-4o : compte les tokens image dans le total.
- Claude : tile-based, prix selon taille.
- Mistral / Pixtral : tokens image inclus dans le contexte.

À monitorer : une feature qui upload des photos peut faire exploser le coût ([[05-ops-safety/24-cost-attribution|cf. 24]]).

### Latency audio real-time

Le temps de réponse cible pour la conversation humaine est ~250-500ms. Requirements :
- Modèle natif audio (pas pipeline STT → LLM → TTS).
- Streaming bidirectionnel (WebSocket / WebRTC).
- Pas de [[06-meta/34-reasoning-models|reasoning long]] si latency critique.
- Pré-fetch du contexte côté serveur.

### Eval multimodal

Benchmarks canoniques :
- **MMMU** — Massive Multi-discipline Multimodal Understanding.
- **MathVista** — math avec visualisations.
- **DocVQA** — documents scannés.
- **ChartQA** — extraction depuis charts.
- **AI2D** — diagrammes scientifiques.
- **VATEX, MSR-VTT** — video captioning.
- **LibriSpeech, FLEURS** — ASR multilingue.

### Sécurité

Vecteurs d'attaque spécifiques multimodal :
- **Image-based prompt injection** : texte caché dans image qui détourne le modèle.
- **Adversarial images** : patterns conçus pour induire des classifications erronées.
- **Voice cloning abuse** : usurpation par TTS.
- Voir [[05-ops-safety/25-safety-engineering]] pour les mitigations.

## Études de cas comparées (2025-2026)

| Lab | VLM | Audio in | Audio out | Architecture |
|---|---|---|---|---|
| OpenAI | GPT-4o vision | GPT-4o audio + Whisper | GPT-4o TTS + gpt-4o-mini-tts | Unifié natif |
| Google | Gemini 2 multimodal | Gemini 2 audio | TTS API | Unifié natif (vision+audio+video) |
| Anthropic | Claude vision | Non (transcription via API tiers) | Non (TTS via tiers) | Vision + texte |
| Meta | Llama 4 vision | (en évolution) | (en évolution) | Multi-modèle |
| Mistral | Pixtral 12B / Small 4 | Voxtral Small/Mini | Voxtral TTS | Modèles séparés, unification dans Small 4 |
| Alibaba (Qwen) | Qwen2-VL, Qwen3-VL | Qwen-Audio | — | Modèles séparés |
| Microsoft | Phi-4-multimodal | Phi-4-multimodal | (via API tiers) | Petit unifié edge |

### Patterns

| Use case | Choix typique |
|---|---|
| OCR documents bureautiques | Pixtral, Qwen2-VL, Claude |
| Agent UI / Computer Use | Claude (Computer Use), GPT-4o (Operator) |
| Voice agent customer support | GPT-4o Realtime, Voxtral + Voxtral TTS |
| Long context multimodal (vidéo, gros docs) | Gemini 2 Pro |
| Transcription multilingue | Whisper v3, Voxtral |
| TTS voice cloning | ElevenLabs, Voxtral TTS, Cartesia |
| Vision on-prem souverain | Pixtral self-hosted, Qwen2-VL |
| Edge multimodal | Phi-4-multimodal, Voxtral Mini, LLaVA-Phi |

## Pièges courants

- **Image trop grande non rescalée** — explosion des tokens, latency et cost.
- **Pipeline audio cousue alors qu'unifié dispo** — latency 3s au lieu de 250ms.
- **Pas de fallback texte** — un modèle multimodal down = toute la feature down.
- **Streaming non bidirectionnel pour voice** — half-duplex = UX médiocre.
- **Vision prompt injection ignoré** — pas d'eval adversarial sur images.
- **Voice cloning sans consent** — risque réglementaire et éthique.
- **OCR avec extraction brute** — pas de structure, données plates à reformater côté harness.

## Vocabulaire clé

`VLM` (Vision-Language Model), `ALM` (Audio-Language Model), `ViT` (Vision Transformer), `patch`, `vision encoder`, `multimodal projection`, `early fusion`, `intermediate fusion`, `late fusion`, `cross-attention`, `unified multimodal`, `Pixtral`, `Voxtral`, `GPT-4o`, `Gemini 2 multimodal`, `Llama 4 multimodal`, `Qwen-VL`, `Whisper`, `Realtime API`, `WebRTC`, `STT/TTS`, `voice cloning`, `MMMU`, `DocVQA`, `ChartQA`, `MathVista`, `LibriSpeech`, `image-based prompt injection`, `adversarial image`.

## Synthèse

Le multimodal devient le standard 2024-2026 : modèles natifs qui ingèrent texte + image + audio et produisent texte + audio (parfois image). VLM standard = ViT pour découper l'image en patches → projection → injection dans le LLM. Stratégies de fusion : late (qualité max, latency haute), early (latency basse, qualité quasi équivalente sur les modèles unifiés natifs). Acteurs : OpenAI GPT-4o unifié natif (Realtime API ~250ms), Google Gemini 2 long context multimodal, Anthropic Claude vision (forte sur documents), Meta Llama 4 OSS multimodal, Mistral Pixtral + Voxtral + Voxtral TTS + unification dans Small 4, Qwen2/3-VL OSS multilingue, Microsoft Phi-4-multimodal edge. Audio : Whisper v3 standard ASR OSS, Voxtral premier ALM open weight enterprise-grade, Voxtral TTS / ElevenLabs / Cartesia pour génération voice. Implications opérationnelles : tokens image consomment massivement le contexte (4k tokens pour 1024×1024), latency audio real-time exige une architecture unifiée, eval sur MMMU/DocVQA/ChartQA/MathVista/LibriSpeech, vecteurs d'attaque spécifiques (image-based prompt injection, voice cloning abuse). Pas de "meilleur" lab universel : choix selon modalité dominante, contrainte souveraineté, et latency requise.
