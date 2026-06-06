---
title: "14. Context engineering"
description: "Sélectionner ce qui rentre dans le contexte : compaction, summarization, attention dilution, retrieval-on-demand."
tags:
  - applied
aliases:
  - 02-context-engineering
  - 14-context-engineering
---

> [!tip] Notes liées
> [[03-applied/13-harness-engineering]] · [[02-inference/08-kv-cache-management]] · [[04-retrieval-quality/20-rag-architecture]] · [[03-applied/15-prompt-vs-semantic-caching]]

## Concept

**Long prompts** : fournir l'intégralité du matériel disponible dans le context window en supposant que le modèle saura identifier ce qui est pertinent.

**Context engineering** : sélectionner, ordonner, formater et compresser ce qui entre dans le context window pour maximiser l'attention sur les éléments pertinents.

## Pourquoi c'est critique

1. **Lost in the middle** : les modèles présentent un biais d'attention vers le début et la fin du contexte. Placer une information critique au milieu d'un long contexte réduit significativement la probabilité qu'elle soit utilisée.

> [!example] Intuition
> Un context window de 200k [[01-architecture/04-tokenization|tokens]] définit une *capacité*, pas une *qualité d'attention uniforme*. Les benchmarks empiriques (NIAH, RULER) montrent un biais positionnel marqué : précision élevée aux extrémités, dégradée au milieu. Le context engineering consiste à exploiter cette structure — placer les éléments critiques en début ou en fin, élaguer le bruit, ordonner les sections — au lieu de traiter la fenêtre comme un buffer plat.
2. **Attention dilution** : la qualité d'attention se dégrade avec le volume de [[01-architecture/04-tokenization|tokens]]. Dans un contexte de 100k tokens contenant un token critique, la probabilité que le modèle l'ignore n'est pas négligeable.
3. **Coût** : le [[02-inference/09-prefill-vs-decode|prefill]] scale linéairement (en compute) avec la taille du contexte. Long contexte = latence prefill + coût proportionnels. Voir [[02-inference/09-prefill-vs-decode]].
4. **Needle-in-haystack ≠ reasoning over haystack** : un modèle peut **retrouver** une information dans un contexte de 1M tokens (needle test), mais ne peut pas **raisonner** dessus. Confondre les deux capacités introduit des bugs subtils en production.

## Techniques

- **Retrieval-augmented** : sélectionner top-k [[04-retrieval-quality/20-rag-architecture|chunks]] pertinents au lieu d'injecter le document complet. Voir [[04-retrieval-quality/20-rag-architecture]].
- **Compaction** : résumer les tours anciens d'une conversation longue.
- **Sliding window** : ne conserver que les N derniers tours.
- **Memory layer** : extraire les faits durables d'une conversation, les persister dans un store séparé, et les injecter sélectivement.
- **Structured context** : XML tags, sections nommées, headers Markdown — le modèle traite mieux ce qui est explicitement étiqueté.
- **Ordering** : information critique en début et en fin, structure stable, absence de préambules dilatoires.
- **Pruning** : retrait dynamique des tools et exemples non-pertinents à la requête courante.

## Anti-pattern : "200k [[01-architecture/04-tokenization|tokens]] disponibles, autant les utiliser"

Un context window de 200k tokens ne signifie pas qu'il faille en injecter 200k. Les [[03-applied/13-harness-engineering|harness]] matures sélectionnent agressivement. Raisons : coût, lost-in-the-middle, et latence prefill incompatible avec une UX interactive.

## Vocabulaire clé

`context engineering`, `lost in the middle`, `needle in a haystack`, `attention dilution`, `compaction`, `sliding window`, `memory layer`, `context pruning`, `structured context`.

## Synthèse

Disposer d'un context window de 200k tokens n'implique pas qu'il faille y injecter 200k tokens. Le context engineering consiste à sélectionner ce qui rentre, l'ordonner (le modèle a un biais "lost in the middle"), et compresser l'historique. En pratique : retrieval, sliding window, compaction, et memory layer séparée pour les faits durables. Piège classique : confondre needle-in-haystack — qui fonctionne — avec reasoning over haystack — qui se dégrade rapidement avec le volume.
