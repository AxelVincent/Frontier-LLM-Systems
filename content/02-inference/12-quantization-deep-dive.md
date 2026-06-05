---
title: "12. Quantization deep-dive"
description: "INT8, INT4, FP8, GPTQ, AWQ, NF4 : pourquoi les bits comptent et comment chaque schéma se calibre."
tags:
  - inference
aliases:
  - 08-quantization-deep-dive
  - 12-quantization-deep-dive
---

> [!tip] Notes liées
> [[02-inference/11-speculative-quant-distill]] · [[02-inference/08-kv-cache-management]] · [[06-meta/28-tradeoffs]]

> [!example] Intuition — trade-off précision / range / mémoire
> Le poids physique d'un modèle est `n_params × bytes_per_dtype`. Llama 70B en FP16 = 140 GB ; en INT4 = 35 GB. Le gain mémoire est immédiat et conditionne ce qui tient sur un GPU donné. Le coût est la **résolution numérique** : passer de 16 bits à 4 bits réduit les valeurs représentables de 65k à 16, et l'erreur de quantization se propage non-linéairement dans les activations. D'où l'existence de schémas (GPTQ, AWQ) qui choisissent intelligemment les scales par groupe pour minimiser cette erreur.

## Les formats

| Format | Bits | Range représentable | Use case |
|---|---|---|---|
| FP32 | 32 | ~3.4e38 | Training classique, rarement inference |
| FP16 | 16 | ~6.5e4 | Inference standard, peut overflow |
| BF16 | 16 | ~3.4e38 (même range que FP32) | Inference et training, plus stable que FP16 |
| FP8 (E4M3, E5M2) | 8 | Hardware sur H100+ | Inference cutting-edge, légère perte |
| INT8 | 8 | -128..127 | Inference établie, gain mémoire 2x |
| INT4 | 4 | -8..7 | Inference cost-sensitive, qualité dégrade |
| INT2/INT1 | 2/1 | Trois/deux valeurs | Recherche, qualité catastrophique sur la plupart des tasks |

**BF16 vs FP16** : même nombre de bits, mais BF16 a 8 bits d'exponent (comme FP32) au lieu de 5 → plus de range, moins d'overflow. FP16 a plus de précision dans une range étroite. En LLM inference, **BF16 a quasi-totalement remplacé FP16** parce que les LLMs ont des activations avec grande range dynamique.

**FP8** : deux variantes — E4M3 (4 exponent bits, 3 mantissa, plus de précision) et E5M2 (plus de range). Hardware acceleration sur H100. Format dominant pour inference cutting-edge (DeepSeek-V3 fait son training en FP8).

## Schémas de quantization

**Symmetric vs asymmetric** :
- Symmetric : `q = round(x / scale)`. Un seul paramètre par groupe.
- Asymmetric : `q = round(x / scale + zero_point)`. Meilleur fit pour distributions skewed.

**Granularité** :
- Per-tensor : un seul scale pour tout le tensor. Simple, perte qualité élevée.
- Per-channel : un scale par channel. Standard pour INT8.
- Per-group (group-wise) : un scale par groupe de N elements (typiquement 128). Standard pour INT4.

**Weight-only vs Weight-Activation** :
- W8A16, W4A16 : weights quantized, activations en FP16. Le plus courant en LLM (les activations sont volatiles).
- W8A8 : tout en INT8. Plus rapide mais qualité dégrade plus.

## GPTQ

**G**eneralized **P**ost-**T**raining **Q**uantization. Quantize layer-by-layer via second-order info (Hessian approximée) pour minimiser l'erreur de reconstruction.

- Adapté pour INT4 weight-only.
- Calibration sur un dataset représentatif (typiquement quelques centaines de samples).
- Sensible au dataset de calibration : si la distribution change en production, la qualité se dégrade.
- Output : weights INT4 + scales FP16.

## AWQ

**A**ctivation-aware **W**eight **Q**uantization. Idée centrale : protéger les weights qui multiplient les activations à grande magnitude (les "salient weights"), en les conservant en précision relative plus haute.

- Souvent meilleure qualité que GPTQ à même bitwidth.
- Plus rapide à calibrer (pas de Hessian).
- Adapté pour INT4.

## GGUF

Format de fichier (et non technique de quantization) utilisé par **llama.cpp**. Stocke les weights quantized en multiples schémas (Q4_K_M, Q5_K_M, Q8_0, etc.) avec metadata. Standard pour le serving CPU et edge.

## Cas où la quantization dégrade

- **Tasks de raisonnement multi-étapes** (math, code) : INT4 dégrade plus que sur classif/QA simple.
- **Long context** : les attention scores deviennent moins précis, dégradation cumulée.
- **Outliers d'activations** : certaines activations LLM ont des valeurs énormes (>100x la moyenne). En W8A8 sans gestion, ces outliers détruisent la précision. SmoothQuant et LLM.int8() (Dettmers) gèrent ce cas.
- **Petits modèles** : un 7B INT4 dégrade plus relativement qu'un 70B INT4. Les gros modèles ont plus de redondance.
- **Modèles à grand vocabulaire** : la projection finale (lm_head) est souvent conservée en FP16.

## Mesure

- **Perplexity** sur wikitext / C4 : signal grossier, dégradation 1-5% acceptable.
- **MMLU, GSM8K, HumanEval** : tasks downstream, signal plus représentatif.
- **Eval custom** sur le workload cible : seul signal qui compte vraiment.

## Trade-off pratique

| Niveau | Qualité | Mémoire | Quand utiliser |
|---|---|---|---|
| BF16 | Référence | 1x | Default, training/inference standard |
| FP8 | Quasi-identique (≤1% delta sur MMLU) | 0.5x | Inference sur H100, prod cutting-edge |
| INT8 (W8A8 ou W8A16) | Quasi-identique | 0.5x | Standard prod, gain mémoire facile |
| INT4 AWQ ou GPTQ | -1 à -5% MMLU | 0.25x | Cost-sensitive, eval requis |
| INT4 brutal (per-tensor) | -10%+ | 0.25x | Anti-pattern, à éviter |
| INT2/INT1 | Catastrophe sauf usage spécifique | 0.125x | Recherche uniquement |

## Vocabulaire clé

`PTQ` (Post-Training Quantization), `QAT` (Quantization-Aware Training), `weight-only quantization`, `W8A8`, `W4A16`, `per-channel`, `per-group`, `symmetric/asymmetric`, `GPTQ`, `AWQ`, `GGUF`, `BNB` (bitsandbytes), `SmoothQuant`, `LLM.int8`, `outlier`, `calibration set`, `salient weights`.

## Synthèse

Plusieurs formats coexistent. BF16 est le standard, même nombre de bits que FP16 mais range étendue. FP8 sur H100 est hardware-accelerated, perte qualité ≤1%. INT8 weight-only divise la mémoire par deux pour une qualité quasi-intacte. INT4 nécessite une calibration : GPTQ minimise l'erreur de reconstruction via Hessian approximée, AWQ protège les weights qui multiplient des activations salient. AWQ donne souvent une meilleure qualité. GGUF est uniquement le format de fichier de llama.cpp. La quantization dégrade sur le reasoning multi-étapes, le long context, et les petits modèles. Les outliers d'activations constituent le piège classique en W8A8 — SmoothQuant ou LLM.int8 les gèrent.
