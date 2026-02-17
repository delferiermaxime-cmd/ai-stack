# Architecture technique

Ce document explique en détail comment les services communiquent entre eux et pourquoi chaque choix technique a été fait.

## Vue d'ensemble du flux de données

### Quand un utilisateur uploade un document

```
Utilisateur uploade un PDF
        │
        ▼
┌─ Open WebUI ─────────────────────────────────────────────┐
│                                                          │
│  1. Reçoit le fichier                                    │
│  2. Envoie le fichier à Docling ──────────────────────┐  │
│                                                       │  │
│     ┌─ Docling ──────────────────────────────┐        │  │
│     │  - Détecte le type de fichier          │        │  │
│     │  - Analyse la mise en page             │        │  │
│     │  - Extrait les tableaux                │        │  │
│     │  - Applique l'OCR si nécessaire        │        │  │
│     │  - Retourne du texte Markdown propre   │        │  │
│     └────────────────────────────────────────┘        │  │
│                                                       │  │
│  3. Découpe le texte en morceaux (chunks)             │  │
│     Par exemple : un PDF de 10 pages → 50 chunks     │  │
│                                                       │  │
│  4. Envoie chaque chunk à TEI pour l'embedding ────┐  │  │
│                                                    │  │  │
│     ┌─ TEI (BGE-M3) ──────────────────────────┐   │  │  │
│     │  - Reçoit un texte                       │   │  │  │
│     │  - Le transforme en vecteur              │   │  │  │
│     │    (liste de 1024 nombres décimaux)      │   │  │  │
│     │  - Ce vecteur capture le SENS du texte   │   │  │  │
│     └──────────────────────────────────────────┘   │  │  │
│                                                    │  │  │
│  5. Stocke les vecteurs dans Qdrant ────────────┐  │  │  │
│                                                  │  │  │  │
│     ┌─ Qdrant ──────────────────────────────┐   │  │  │  │
│     │  - Stocke chaque vecteur avec son     │   │  │  │  │
│     │    texte original                      │   │  │  │  │
│     │  - Optimisé pour retrouver les        │   │  │  │  │
│     │    vecteurs les plus similaires        │   │  │  │  │
│     └────────────────────────────────────────┘   │  │  │  │
│                                                  │  │  │  │
└──────────────────────────────────────────────────┘  │  │  │
```

### Quand un utilisateur pose une question (avec RAG)

```
Utilisateur : "Quel est le chiffre d'affaires de 2024 ?"
        │
        ▼
┌─ Open WebUI ─────────────────────────────────────────────┐
│                                                          │
│  1. Envoie la question à TEI ──────────────────────┐     │
│                                                    │     │
│     ┌─ TEI ──────────────────────────────────┐     │     │
│     │  Transforme la question en vecteur      │     │     │
│     └──────────────────────────────────────────┘     │     │
│                                                    │     │
│  2. Cherche dans Qdrant les vecteurs similaires ───┐     │
│                                                    │     │
│     ┌─ Qdrant ──────────────────────────────┐     │     │
│     │  Compare le vecteur de la question     │     │     │
│     │  avec tous les vecteurs stockés        │     │     │
│     │  Retourne les 5 passages les plus      │     │     │
│     │  similaires (configurable)             │     │     │
│     └────────────────────────────────────────┘     │     │
│                                                    │     │
│  3. Construit le prompt pour le LLM :              │     │
│     "Voici des extraits de documents :             │     │
│      [passage 1] [passage 2] [passage 3]           │     │
│      En te basant sur ces extraits, réponds à :    │     │
│      Quel est le chiffre d'affaires de 2024 ?"     │     │
│                                                    │     │
│  4. Envoie au LLM ────────────────────────────┐    │     │
│                                                │    │     │
│     ┌─ vLLM ──────────────────────────────┐   │    │     │
│     │  Génère une réponse en s'appuyant    │   │    │     │
│     │  sur les passages fournis            │   │    │     │
│     │  "D'après le rapport annuel,         │   │    │     │
│     │   le CA 2024 est de 12.5M€..."       │   │    │     │
│     └──────────────────────────────────────┘   │    │     │
│                                                │    │     │
│  5. Affiche la réponse à l'utilisateur         │    │     │
│                                                │    │     │
└────────────────────────────────────────────────┘    │     │
```

## Pourquoi ces choix techniques ?

### vLLM plutôt qu'Ollama pour le LLM

vLLM utilise le "continuous batching" et PagedAttention. En multi-utilisateurs, quand 5 personnes posent une question en même temps, vLLM les traite en parallèle sur le GPU. Ollama les mettrait en file d'attente.

### TEI plutôt qu'Ollama pour l'embedding

Quand un utilisateur uploade un gros PDF, il peut y avoir 200 chunks à vectoriser. TEI les regroupe en batches et les traite d'un coup grâce au batching dynamique. C'est de l'ordre de 10x plus rapide qu'Ollama pour cette tâche.

### Qdrant plutôt que ChromaDB

ChromaDB est le choix par défaut d'Open WebUI mais il ralentit fortement au-delà de quelques centaines de documents. Qdrant est conçu pour la production et maintient ses performances même avec des millions de vecteurs.

### Docling plutôt que Tika

Docling comprend la structure des documents (colonnes, tableaux, en-têtes) et produit du Markdown bien structuré. Tika extrait le texte brut sans comprendre la mise en page, ce qui donne souvent du texte mélangé et inutilisable pour le RAG.

## Communication réseau entre services

Tous les services tournent dans le même réseau Docker. Ils se trouvent par leur nom de service (pas par adresse IP).

| De | Vers | URL interne | Protocole |
|----|------|-------------|-----------|
| Open WebUI | vLLM | `http://vllm:8000/v1` | API OpenAI |
| Open WebUI | TEI | `http://tei:80/v1` | API OpenAI |
| Open WebUI | Qdrant | `http://qdrant:6333` | API REST |
| Open WebUI | Docling | `http://docling:5001` | API REST |

### Ports exposés sur le serveur hôte

Ces ports sont accessibles depuis l'extérieur du serveur (configurables dans `.env`) :

| Service | Port interne | Port hôte | Usage |
|---------|-------------|-----------|-------|
| Open WebUI | 8080 | 3000 | Interface utilisateur |
| vLLM | 8000 | 8000 | API LLM |
| TEI | 80 | 8081 | API Embedding |
| Qdrant | 6333 | 6333 | API Base vectorielle |
| Docling | 5001 | 5001 | API Extraction documents |

## Partage GPU entre vLLM et TEI

vLLM et TEI partagent le même GPU. L'allocation se fait automatiquement :

- **vLLM** réserve un pourcentage de la VRAM (paramètre `VLLM_GPU_MEM`, par défaut 85%)
- **TEI** utilise la VRAM restante (~2 Go suffisent pour BGE-M3)

Si votre GPU a 24 Go de VRAM : vLLM utilisera ~20 Go, TEI ~2 Go, il reste ~2 Go de marge.

Si vous avez des erreurs "Out of Memory", baissez `VLLM_GPU_MEM` à 0.75 dans le `.env`.
