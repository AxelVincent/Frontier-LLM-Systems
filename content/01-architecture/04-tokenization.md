---
title: "04. Tokenization"
description: "BPE, SentencePiece, Tiktoken, byte-level fallback, multilingue : comment le texte devient des IDs."
tags:
  - architecture
aliases:
  - 26-tokenization
  - 04-tokenization
---

> [!tip] Notes liées
> [[01-architecture/01-transformer-architecture]] · [[04-retrieval-quality/20-rag-architecture]] · [[03-applied/14-context-engineering]]

## Le concept

Un LLM ne traite pas du texte directement mais des **tokens** : des identifiants entiers correspondant à des unités sub-lexicales. Le **tokenizer** convertit texte → tokens (encode) et tokens → texte (decode).

> [!example] Intuition
> L'input du modèle n'est jamais du texte, mais une séquence d'entiers (`[15043, 11856, 287, ...]`) indexant un vocabulaire fixe. La granularité est **sub-lexicale** : `"unbelievable"` → `["un", "believ", "able"]`. Conséquence opérationnelle : la facturation, le `max_tokens`, et la longueur réelle du contexte se mesurent en tokens, pas en mots — et le ratio mots/tokens varie fortement par langue.

Choix de tokenization impactent : taille du vocabulaire, longueur des séquences, qualité de la représentation, comportement multilingue, robustesse aux typos.

## Les algorithmes principaux

### BPE (Byte-Pair Encoding)

Algorithme initialement utilisé en compression, adapté à la NLP par Sennrich et al. (2016).

**Principe** :
1. Vocabulaire initial : tous les bytes (ou caractères Unicode) individuels.
2. Compter toutes les paires adjacentes de tokens dans le corpus.
3. Fusionner la paire la plus fréquente en un nouveau token.
4. Répéter jusqu'à atteindre la taille de vocabulaire cible.

**Résultat** : un vocabulaire mixte de caractères, sub-mots fréquents, et mots complets pour les mots les plus communs.

**Utilisé par** : GPT-2, GPT-3, GPT-4, RoBERTa, Llama, Mistral.

### Byte-level BPE

Variante de BPE où les **bytes** sont l'unité initiale au lieu des caractères Unicode. Garantit qu'aucun texte n'est OOV (out-of-vocabulary) puisque tout texte se décompose en bytes.

Utilisé par GPT-2, Llama, Mistral.

### WordPiece

Variante développée par Google pour BERT. La fusion des paires se fait selon un critère de **likelihood** plutôt que de fréquence brute, ce qui favorise les fusions qui améliorent la probabilité du corpus.

### Unigram LM

Approche probabiliste (Kudo 2018). On part d'un grand vocabulaire et on **élimine itérativement** les tokens qui contribuent le moins à la likelihood du corpus. Plus principled que BPE, donne un vocabulaire plus régulier.

Utilisé par SentencePiece (option `model_type=unigram`).

### SentencePiece

Librairie (et non algorithme) de Google qui implémente BPE et Unigram LM. Particularité : traite le texte comme une **séquence brute** sans pré-tokenization (pas de split sur les espaces), ce qui rend l'algorithme **language-agnostic**.

Utilisé par T5, mT5, ALBERT, XLNet, Mistral (via tokenizer SentencePiece-compatible).

### Tiktoken

Tokenizer d'OpenAI. Implémentation rapide en Rust de BPE byte-level. Pas un algorithme distinct, juste une implémentation très efficace.

## Vocabulary size

Choix typiques :
- 32k : Llama 1, Mistral 7B/Mixtral.
- 50k : GPT-2.
- 100k : GPT-4, Llama 3 (utilise 128k).
- 128k-256k : modèles multilingues avec couverture étendue.

### Trade-offs

- **Petit vocab** : plus de tokens par mot, séquences plus longues, embedding matrix plus petite (moins de paramètres dans la projection finale).
- **Grand vocab** : moins de tokens par mot, séquences plus courtes, embedding matrix plus grande (paramètres significatifs : pour 128k × d_model=4096, on parle de 500M paramètres).

L'optimum dépend du compromis entre coût compute (séquence longue = [[02-inference/09-prefill-vs-decode|prefill]] long) et coût mémoire (embedding matrix grande).

## Tokenization multilingue

Les LLM entraînés principalement sur de l'anglais tokenizent inefficacement les langues moins représentées. Exemple typique : un mot français peut prendre 1-2 tokens, un mot japonais ou hindi peut prendre 5-10 tokens (en passant par byte-level fallback).

Conséquences pratiques :
- Le contexte effectif (en mots) est plus court pour ces langues.
- Le coût (par token) est plus élevé pour ces langues.
- La qualité de génération peut être inférieure.

Solutions :
- Vocabulaire plus large (Llama 3 : 128k tokens, dont une part dédiée aux langues non-anglaises).
- Tokenizers spécialisés (Mistral a un vocabulaire optimisé pour les langues européennes).
- **Byte-level fallback** : si un caractère n'est pas dans le vocab, le décomposer en bytes. Garantit la couverture mais explose la taille de séquence.

## Erreurs et pièges classiques

- **Off-by-one sur le BOS/EOS** : oublier d'ajouter le token de début ou de fin de séquence selon les conventions du modèle.
- **Comptage tokens ≠ comptage caractères** : un prompt de 1000 caractères peut faire 250-400 tokens en anglais, 500-800 tokens en français, et plus en non-latin.
- **Tokens spéciaux dans le user input** : certains tokenizers ont des tokens spéciaux (`<|endoftext|>`, `<|system|>`) qui peuvent être injectés par un attaquant pour casser le format de chat. Mitigations : escaping, ou tokenizer qui les traite comme texte brut.
- **Number tokenization** : les nombres peuvent être tokenizés de manière inconsistante ("123" en un token, "1234" en deux). Affecte les performances sur les tâches math.

## Vocabulaire clé

`token`, `tokenizer`, `vocabulary`, `BPE` (Byte-Pair Encoding), `byte-level BPE`, `WordPiece`, `Unigram LM`, `SentencePiece`, `Tiktoken`, `BOS` (Beginning Of Sequence), `EOS` (End Of Sequence), `byte-level fallback`, `OOV` (Out-Of-Vocabulary), `subword`, `multilingual tokenization`.

## Synthèse

Le tokenizer convertit texte en identifiants entiers manipulés par le modèle. BPE (Byte-Pair Encoding) est l'algorithme dominant : il part de caractères ou bytes individuels et fusionne itérativement les paires les plus fréquentes jusqu'à atteindre la taille de vocabulaire cible. Byte-level BPE garantit qu'aucun texte n'est OOV. SentencePiece est une librairie language-agnostic qui implémente BPE et Unigram LM. Tiktoken est l'implémentation Rust rapide d'OpenAI. Vocabulary size typique : 32k à 128k, trade-off entre longueur de séquence et taille de l'embedding matrix. Les langues non-anglaises sont souvent sur-tokenizées, ce qui réduit le contexte effectif et augmente le coût. Pièges classiques : BOS/EOS oubliés, tokens spéciaux exploitables par un attaquant, tokenization inconsistante des nombres.
