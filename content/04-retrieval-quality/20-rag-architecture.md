---
title: "20. RAG architecture moderne"
description: "Chunking, hybrid search (BM25 + dense), reranking, query rewriting : le stack RAG en production."
tags:
  - retrieval-quality
aliases:
  - 13-rag-architecture
  - 20-rag-architecture
---

> [!info] Prérequis
> [[03-applied/14-context-engineering|14. Context engineering]] — RAG est un cas particulier de context engineering, où le contexte vient d'un index.

> [!tip] Notes liées
> [[04-retrieval-quality/21-retrieval-evals]] · [[03-applied/14-context-engineering]] · [[03-applied/15-prompt-vs-semantic-caching]] · [[06-meta/27-ft-vs-icl-vs-rag-vs-distill]]

## Le pattern de base

```
query → embed query → search vector store (+ keyword) → rerank → select top-k chunks → inject in context → LLM
```

Pattern devenu standard. Chaque étape porte cependant des dizaines de décisions, chacune pouvant dégrader la qualité.

> [!example] Intuition — knowledge paramétrique vs non-paramétrique
> RAG sépare deux sources de connaissance : la **paramétrique** (figée dans les poids du modèle au moment du [[01-architecture/07-post-training-alignment|pre-training]]) et la **non-paramétrique** (récupérée à la requête depuis un index externe). Le LLM devient une *fonction de synthèse* sur des chunks fournis à la volée, ce qui permet de mettre à jour la knowledge base sans réentraîner. Le coût se déplace : du training vers le retrieval, dont la qualité conditionne entièrement la sortie finale (garbage in, garbage out).

## Chunking

**Problème** : les documents doivent être découpés en chunks de taille gérable (embedded, retrieved, injected). Trop petit → chunks sans contexte. Trop gros → retrieval imprécis et saturation du budget context.

### Stratégies

**1. Fixed-size**
- 512 ou 1024 [[01-architecture/04-tokenization|tokens]]. Overlap 10-20% (pour ne pas couper au mauvais endroit).
- Simple. Adapté à la plupart des cas.

**2. Sentence-aware**
- Split sur sentence boundary, pack jusqu'à ~512 tokens.
- Plus performant que fixed sur du prose.

**3. Recursive**
- LangChain `RecursiveCharacterTextSplitter` : split sur paragraph, puis sentence, puis word.
- Bon défaut.

**4. Semantic chunking**
- Détection des changements de sujet (embedding distance entre phrases adjacentes).
- Plus coûteux (embed à l'ingestion). Adapté aux transcriptions et conversations.

**5. Structure-aware**
- Pour Markdown / HTML / code : respecter les headings, sections, fonctions.
- Chunk = unité sémantique naturelle.

**6. Late chunking** (technique 2024)
- Embed du doc complet puis chunking sur les embeddings.
- Chaque chunk conserve le contexte du doc complet dans son embedding.
- Plus coûteux, qualité de retrieval améliorée.

### Pièges

- Couper en milieu de phrase → retrieval miss.
- Couper en milieu d'un tableau ou de code → contexte perdu.
- Chunks sans header (provenance perdue).

### Pattern : contextualized chunks

- Préfixer chaque chunk de "Document: {title}. Section: {section}. Content: {chunk_content}".
- Le retrieval matche mieux, le LLM contextualizes mieux.

## Embeddings

### Modèles canoniques

- OpenAI `text-embedding-3-small` / `large`.
- Mistral `mistral-embed`.
- Cohere `embed-multilingual-v3`.
- Open source : `BGE-large`, `e5-mistral-7b-instruct`, `nomic-embed-text`.

### Dimensions

Typique : 384, 768, 1024, 1536, 3072. Plus haut = plus précis mais plus coûteux (vector store) et plus lent (search).

**Matryoshka embeddings** : modèles entraînés de manière à autoriser la troncature des dimensions sans grosse perte (e5-mistral, certains OpenAI). Utile pour le trade-off cost/perf.

**Normalisation** : la plupart des embeddings sont L2-normalized → cosine similarity = dot product. Plus rapide à search.

## Vector store

### ANN algorithms

- **HNSW** : Hierarchical Navigable Small World. Graphs multi-niveau. Très rapide, consomme beaucoup de mémoire.
- **IVF** (Inverted File Index) : cluster les vecteurs, search dans clusters proches. Trade-off rappel/vitesse.
- **PQ** (Product Quantization) : compress les vecteurs, search approximate. Combiné avec IVF (IVF-PQ).
- **Flat** (brute force) : exact, O(N). Adapté à <1M vecteurs.

### Vector stores

Pinecone, Weaviate, Qdrant, Milvus, pg_vector, Chroma, FAISS, LanceDB.

### Trade-offs

- Recall vs latency vs memory vs index build time.
- Updates : certains index supportent les inserts incrémentaux, d'autres nécessitent un rebuild.

## Hybrid search

**Motivation** : les dense embeddings sont mauvais sur :
- Mots exacts (noms de personnes, IDs, codes).
- Termes rares non vus à l'entraînement.
- Recherche par mot-clé pure.

**Solution** : combiner dense + sparse (BM25 ou SPLADE).

- BM25 : TF-IDF classique. Rapide, no training.
- SPLADE : sparse learned. Plus performant que BM25 sur certains domaines, plus coûteux.

**Fusion** : Reciprocal Rank Fusion (RRF) — combine les rankings sans normalisation des scores.

```
rrf_score = sum(1 / (k + rank_i)) for each list
```

k souvent 60.

## Reranking

Après retrieval initial (top-100), rerank en top-10 avec un modèle plus puissant.

### Architectures

- **Bi-encoder** : embedding query + embedding chunk séparément → score. C'est l'embedding standard. Rapide.
- **Cross-encoder** : query et chunk traités ensemble par un transformer. Beaucoup plus précis, beaucoup plus lent. Non scalable au million de chunks → réservé au top-100.

**Modèles** : Cohere Rerank v3, BGE Reranker v2.

**Gain** : 10-30% sur [[04-retrieval-quality/21-retrieval-evals|recall@10]] typiquement. Critique pour la qualité finale.

## Freshness

RAG sur des docs qui changent → invalidation cache de retrieval, re-embed, re-index.

- Stratégies : full re-index quotidien, delta indexing, real-time CDC.
- [[03-applied/15-prompt-vs-semantic-caching|TTL]] sur les embeddings (utilité limitée, mais pertinent sur des metadata).
- Versioning des chunks (savoir quel chunk a été utilisé pour quelle réponse — pour debug).

## Failure modes

- **Bad chunk** : chunk pertinent existant mais raté par le search (recall failure).
- **Distractor chunk** : retrieval ramène des chunks "voisins" qui ressemblent mais sont hors-sujet → LLM confus.
- **Over-retrieval** : injection de 30 chunks, LLM [[03-applied/14-context-engineering|lost-in-the-middle]]. Voir [[03-applied/14-context-engineering]].
- **Stale chunk** : chunk pertinent mais obsolète.
- **Coverage gap** : query parle d'un sujet absent du corpus → le modèle invente ([[01-architecture/07-post-training-alignment|hallucine]] sans signaler "je n'ai pas trouvé").

## Vocabulaire clé

`chunking`, `fixed-size`, `recursive chunking`, `semantic chunking`, `late chunking`, `contextualized chunks`, `embeddings`, `dense retrieval`, `sparse retrieval`, `BM25`, `SPLADE`, `hybrid search`, `RRF` (Reciprocal Rank Fusion), `HNSW`, `IVF`, `PQ`, `bi-encoder`, `cross-encoder`, `reranking`, `recall@k`, `precision@k`, `freshness`, `matryoshka embeddings`.

## Synthèse

Le RAG moderne dépasse le simple vector search. Chunking : recursive ou semantic, avec contextualized chunks qui préfixent le titre du doc et la section pour que le retrieval matche mieux et que le LLM contextualizes. Embeddings : Mistral-embed, OpenAI, BGE selon le use case. Vector store : HNSW pour speed, IVF-PQ pour memory. Critique : hybrid search dense + BM25 fusionnés via RRF, parce que les dense embeddings sont mauvais sur les mots exacts comme les IDs ou noms propres. Reranking avec un cross-encoder sur top-100 → top-10, gain 10-30% recall. Freshness : invalidation et re-index sur les docs qui changent. Failure modes : bad chunk, distractor chunks, over-retrieval qui cause lost-in-the-middle, et coverage gaps où le modèle hallucine au lieu de signaler "pas trouvé".
