---
title: "36. MCP et agent protocols"
description: "Model Context Protocol, l'écosystème des serveurs/clients, alternatives, gouvernance Linux Foundation, et impact sur l'architecture agent."
tags:
  - meta
aliases:
  - 36-mcp-agent-protocols
---

> [!info] Prérequis
> [[03-applied/17-function-calling-reliability|17. Function calling reliability]] — MCP est conceptuellement une extension/standardisation du function calling.

> [!tip] Notes liées
> [[03-applied/13-harness-engineering]] · [[03-applied/18-agent-guardrails]] · [[05-ops-safety/25-safety-engineering]] · [[06-meta/33-on-premise-en-pratique]]

## Le concept

Jusqu'en 2024, chaque LLM provider exposait son propre format de function calling : OpenAI tools, Anthropic tool_use, Google function_declarations. Intégrer un même outil (calendrier, base SQL, file system) à N modèles demandait N adaptateurs. **MCP** (Model Context Protocol) résout ce problème en standardisant le protocole d'**interaction tool/agent** entre modèles et outils.

Anthropic l'a introduit en novembre 2024. En 18 mois, il est devenu un standard industriel transversal supporté par tous les acteurs majeurs.

> [!example] Intuition — l'analogie USB-C
> Avant MCP : chaque modèle/IDE avait son propre format de tool ; chaque outil devait être ré-intégré. Comme avant USB-C, où chaque appareil avait son port.
>
> Avec MCP : un **MCP server** expose des tools, resources, prompts ; **n'importe quel client compatible MCP** peut s'y connecter. Une intégration = N modèles disponibles.

## Architecture

MCP est un protocole **client-serveur** basé sur **JSON-RPC 2.0**.

```
┌──────────────────────┐         JSON-RPC 2.0          ┌────────────────┐
│  Host application    │ ◄────────────────────────────►│  MCP server    │
│  (Claude Desktop,    │      stdio | HTTP+SSE         │  (Postgres,    │
│   Cursor, Claude     │                                │   GitHub, Slack│
│   Code, ChatGPT      │                                │   filesystem...│
│   Desktop, etc.)     │                                │                │
└──────────────────────┘                                └────────────────┘
       │
       │ embedded LLM
       ▼
   Modèle (Claude, GPT-4o, Gemini, Mistral, Llama...)
```

### Composants

- **Host** : l'application qui embarque un LLM (Claude Desktop, Cursor, Claude Code, etc.).
- **Client** : session JSON-RPC entre le host et un MCP server. Un host peut maintenir plusieurs clients en parallèle (un par server).
- **Server** : expose des tools, resources, prompts à travers l'API MCP.

### Transports

- **stdio** : subprocess local. Idéal pour outils desktop, dev local, sécurité par isolation OS.
- **HTTP + SSE** : connexions distantes scalables, microservices, déploiements cloud.
- **Streamable HTTP** (release candidate 2026-07-28) : core stateless qui scale sur infra HTTP standard, avec sticky sessions optionnels seulement.

### Primitives MCP

Trois primitives canoniques exposées par un server :

1. **Tools** — fonctions invocables par le modèle (`search_files`, `query_database`, `send_email`).
2. **Resources** — données lisibles (`file://path`, `db://query_result`).
3. **Prompts** — templates pré-définis qui guident des workflows utilisateur.

Une quatrième primitive avancée :
4. **Sampling** — un MCP server peut demander au host de générer du texte via son LLM. Utile pour des servers qui orchestrent du multi-step.

## Adoption (chiffres clés 2025-2026)

| Date | Étape | Volume |
|---|---|---|
| Nov 2024 | Anthropic lance MCP | ~2M downloads SDK/mois initialement |
| Avr 2025 | OpenAI adopte MCP | 22M downloads/mois |
| Juil 2025 | Microsoft Copilot Studio intègre | 45M |
| Déc 2025 | Critère mainstream | **97M downloads/mois**, 10 000+ servers en prod |
| Déc 2025 | **Anthropic donne MCP à la Linux Foundation** | Création de l'**Agentic AI Foundation** (AAIF), co-fondée avec Block et OpenAI |

Plateformes supportant MCP officiellement : Anthropic, OpenAI (ChatGPT, Codex), Google, Microsoft (Copilot Studio, VS Code), GitHub Copilot, Vercel, Cursor, Claude Desktop, Claude Code.

## MCP vs function calling natif

Le function calling natif des providers reste utilisable et performant. La différence est au niveau **écosystème et portabilité**.

| Critère | Function calling natif | MCP |
|---|---|---|
| Cible | Une API provider | Toute LLM compatible MCP |
| Format | OpenAI tools / Anthropic tool_use / etc. | JSON-RPC 2.0 standard |
| Reuse cross-provider | Adaptateur N×M | Adaptateur 1×N |
| Découverte dynamique | Pas standard | `tools/list` API |
| Capabilities riches | Limitées (tools only typique) | Tools + Resources + Prompts + Sampling |
| Auth | Côté provider | OAuth 2.0 / OpenID Connect (RC 2026) |
| Mature en prod | Très (4-5 ans) | Émerge (1.5 ans, mais momentum massif) |

Pattern fréquent en 2026 : on garde le function calling natif pour les **tools simples internes**, et on utilise MCP pour les **integrations cross-app / écosystème** (GitHub, Slack, base SQL externe, etc.).

## Alternatives et concurrents

### Function calling propriétaires

- **OpenAI tools / Realtime API tools** — référence historique.
- **Anthropic tool_use** — interopérable avec MCP côté Anthropic.
- **Google function_declarations** — sur Gemini.

### Frameworks agentic indépendants

- **LangChain / LangGraph** — orchestration et tool registry, peut consommer MCP.
- **LlamaIndex** — orienté retrieval, support MCP.
- **CrewAI, AutoGen** — multi-agent.
- **Google Genkit** — framework Google pour AI agents, expose abstractions tool.

### Protocoles concurrents

- **Anthropic Computer Use** — protocole spécifique d'agents qui contrôlent l'UI (clavier, souris, screenshot). Pas vraiment concurrent — complémentaire à MCP.
- **AGNTCY / Internet of Agents** — initiative Cisco pour agent-to-agent.

Aucun concurrent direct n'a atteint l'adoption MCP en 2026.

## Gouvernance et écosystème

**Agentic AI Foundation (AAIF)** — décembre 2025, sous Linux Foundation :
- Co-fondée par Anthropic, Block, OpenAI.
- Support : Microsoft, Google, GitHub, Cursor, Vercel, Block, etc.
- Mission : maintenir la spec MCP, éviter le capture par un seul acteur.

C'est une étape importante : un protocole *standard de fait* lancé par un acteur devient *standard ouvert* gouverné collectivement. Précédent semblable à Kubernetes (Google → CNCF).

## Cas d'usage en production

### Coding agents

Claude Code, Cursor, GitHub Copilot, OpenCode — tous parlent MCP pour les intégrations editor / VCS / docs internes. L'écosystème de MCP servers pour devtools est le plus mature.

Servers typiques utilisés :
- `filesystem` — lecture/écriture fichiers.
- `git` — commits, diff, branches.
- `github` — issues, PRs, code search.
- `postgres` / `sqlite` — query DBs.
- `playwright` / `puppeteer` — automation web.

### Enterprise integrations

- **Slack MCP server** — read/post messages.
- **Google Drive / Sharepoint MCP** — recherche/lecture documents.
- **Atlassian Jira/Confluence MCP** — projets.
- **Salesforce MCP** — CRM.
- **Snowflake MCP** — data warehouse query.

Pattern : un MCP server interne par système, exposé à tous les agents internes (Claude Desktop, Cursor, agents custom) sans réécrire l'intégration.

### Build vs reuse

Le pari MCP : **réutilisation**. Plutôt que chaque équipe écrive un nouveau wrapper d'API, on consomme des MCP servers existants. Ecosystem hub : `modelcontextprotocol.io/servers` et registry communautaires.

## Implications opérationnelles

### Security

Vecteurs d'attaque spécifiques MCP :
- **Server malveillant** — un MCP server installé localement peut exfiltrer toute la donnée que le modèle voit.
- **Tool spoofing** — server qui prétend être `github` mais ne l'est pas.
- **Prompt injection via resources** — un MCP server qui retourne du contenu qui détourne le modèle.

Mitigations :
- Signature des MCP servers (release 2026 prévoit ça).
- Sandbox par tenant pour les servers stateful.
- Permission boundary explicites (voir [[05-ops-safety/25-safety-engineering]]).
- Audit logs JSON-RPC complets.

### On-prem MCP

Sur déploiement [[06-meta/33-on-premise-en-pratique|on-prem]], les MCP servers tournent à côté du serving stack. Patterns :
- **Internal MCP gateway** — un proxy auth devant les servers internes.
- **mTLS** entre client et server pour les flux HTTP.
- **Service mesh** (Istio, Linkerd) pour le mesh interne.

### Observabilité

Chaque call MCP = un span dans la trace LLM, avec :
- Server identité.
- Tool/resource name.
- Argument schema validation pass.
- Latency et erreurs.
- Voir [[05-ops-safety/23-llm-observability]] pour le format.

## Études de cas comparées (2025-2026)

### Anthropic — créateur, deepest integration

Claude Desktop, Claude Code, Claude API natifs MCP. L'API tool_use d'Anthropic est conçue pour interopérer naturellement. Servers officiels Anthropic : filesystem, github, gdrive, slack, postgres, etc.

### OpenAI — adoption rapide

ChatGPT (avril 2025) et Codex (mid-2025) parlent MCP. Position : compatibilité plutôt que création. Le function calling natif OpenAI reste poussé pour les tools internes serveur-side, MCP pour les desktop apps et ecosystem.

### Microsoft — intégration plate-forme

Copilot Studio (juillet 2025) consomme MCP servers. VS Code, GitHub Copilot intègrent. Position stratégique : MCP comme standard pour brancher tout Microsoft 365 / Azure aux agents.

### Google — adoption tardive mais alignée

Gemini supporte MCP en 2025-2026. Genkit comme framework. Position : compatibilité tout en poussant Vertex AI Agents et ses propres abstractions.

### Mistral — alignement écosystème

Mistral AI Studio et Mistral Vibe (mars 2026) intègrent MCP pour leur stack agentic. Pas de positionnement créateur de protocole — alignement avec le standard.

### Meta, DeepSeek, Qwen

Adoption via les frameworks tiers (LangChain, LlamaIndex). Pas d'intégration native à date 2026, mais les modèles open weight sont consommés via clients MCP-compatibles (Cursor, Claude Code, Continue.dev, etc.).

## Pièges courants

- **Mélanger function calling et MCP côté harness** — choisir un mode par flux, sans le savoir on duplique les tools.
- **MCP server malveillant non audité** — installé "parce que ça marche", exfiltre des données.
- **Pas de auth sur les servers HTTP** — n'importe qui peut se connecter au server interne.
- **Sticky sessions oubliées** sur HTTP/SSE en charge — bug latents avec load balancer round-robin. Le RC 2026-07-28 corrige ce design.
- **Trop de servers connectés** — registry géant qui dégrade le tool selection (cf. [[06-meta/29-production-failure-modes|hallucinated tool calls]]).
- **Pas de versioning sur les servers** — bump d'API casse l'agent en prod.
- **Resources sans rate limit** — agent qui lit en boucle un fichier énorme.

## Vocabulaire clé

`MCP` (Model Context Protocol), `JSON-RPC 2.0`, `host`, `client`, `server`, `stdio transport`, `HTTP+SSE transport`, `Streamable HTTP`, `tools` (MCP), `resources` (MCP), `prompts` (MCP), `sampling` (MCP), `Agentic AI Foundation` (AAIF), `Linux Foundation`, `tool registry`, `tool spoofing`, `MCP gateway`, `mTLS`, `OAuth 2.0`, `OpenID Connect`, `Computer Use`, `Genkit`, `LangGraph`, `Continue.dev`.

## Synthèse

MCP (Model Context Protocol) est devenu en 18 mois (nov. 2024 → 2026) le standard de fait pour exposer tools, resources, prompts à n'importe quel agent LLM compatible. Architecture client-serveur sur JSON-RPC 2.0, transports stdio (local) et HTTP+SSE (remote, distant). Adoption massive : 97M downloads SDK/mois en déc. 2025, 10 000+ servers en production, support universal (Anthropic, OpenAI, Microsoft, Google, GitHub, Cursor, Mistral, Vercel). Décembre 2025 : Anthropic donne MCP à la **Linux Foundation** via la nouvelle **Agentic AI Foundation**, co-fondée avec Block et OpenAI — passage de standard de fait à standard ouvert gouverné. Pattern fréquent : function calling natif pour tools internes simples, MCP pour intégrations cross-app et ecosystem. Sur on-prem, les MCP servers tournent à côté du serving stack avec mTLS / OIDC auth. Pièges principaux : servers malveillants non audités, mélange function calling/MCP, pas d'auth sur servers HTTP, trop de servers exposés qui dégradent la tool selection. MCP ne remplace pas le function calling — il standardise l'écosystème autour pour rendre les intégrations réutilisables across labs et clients.
