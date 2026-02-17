# Stack IA Locale — Pipeline RAG complète avec Docker

Une stack complète pour déployer votre propre assistant IA avec recherche dans vos documents (RAG), le tout en local sur votre serveur.

## Ce que fait ce projet

Ce projet installe et connecte **5 services** qui travaillent ensemble pour créer un assistant IA privé, accessible à plusieurs utilisateurs en même temps, capable de lire et comprendre vos documents.

```
┌──────────────────────────────────────────────────────────────────┐
│                        VOTRE SERVEUR                             │
│                                                                  │
│  ┌───────────────┐                                               │
│  │  Open WebUI   │ ← Interface web (comme ChatGPT)              │
│  │  port 3000    │   Les utilisateurs se connectent ici          │
│  └──┬──┬──┬──┬───┘                                               │
│     │  │  │  │                                                    │
│     │  │  │  └──▶ ┌─────────────┐                                │
│     │  │  │       │   Docling   │ ← Lit les PDF, Word, Excel     │
│     │  │  │       │  port 5001  │   et extrait le texte propre   │
│     │  │  │       └─────────────┘                                │
│     │  │  │                                                      │
│     │  │  └─────▶ ┌─────────────┐                                │
│     │  │          │  TEI (BGE)  │ ← Transforme le texte en       │
│     │  │          │  port 8081  │   vecteurs pour la recherche   │
│     │  │          └─────────────┘                                │
│     │  │                                                         │
│     │  └────────▶ ┌─────────────┐                                │
│     │             │   Qdrant    │ ← Stocke les vecteurs          │
│     │             │  port 6333  │   (mémoire de recherche)       │
│     │             └─────────────┘                                │
│     │                                                            │
│     └───────────▶ ┌─────────────┐                                │
│                   │    vLLM     │ ← Le cerveau : génère les      │
│                   │  port 8000  │   réponses intelligentes       │
│                   └─────────────┘                                │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### En termes simples

1. **Un utilisateur** ouvre son navigateur et va sur l'interface (Open WebUI)
2. Il **uploade un document** (PDF, Word, etc.)
3. **Docling** lit le document et en extrait le texte proprement structuré
4. **TEI** (avec le modèle BGE-M3) transforme ce texte en nombres (des "vecteurs") qui capturent le sens des phrases
5. Ces vecteurs sont stockés dans **Qdrant** (une base de données spécialisée)
6. Quand l'utilisateur **pose une question**, le système cherche dans Qdrant les passages de documents les plus pertinents
7. **vLLM** génère une réponse en s'appuyant sur ces passages

C'est ce qu'on appelle le **RAG** (Retrieval-Augmented Generation) : l'IA ne se contente pas d'inventer une réponse, elle la base sur vos vrais documents.

## Ce qu'il vous faut (prérequis)

| Élément | Minimum | Recommandé |
|---------|---------|------------|
| **Système** | Linux (Ubuntu 22.04+) | Ubuntu 24.04 LTS |
| **GPU** | NVIDIA avec 8 Go VRAM | NVIDIA avec 24+ Go VRAM |
| **RAM** | 16 Go | 32 Go |
| **Disque** | 50 Go libres | 100 Go libres |
| **Docker** | Version 24+ | Dernière version |
| **Drivers NVIDIA** | Compatible CUDA 12.2+ | Dernière version |

### Pourquoi un GPU NVIDIA ?

Les modèles d'IA font des millions de calculs en parallèle. Les GPU NVIDIA sont conçus pour ça. Sans GPU, un modèle mettrait des minutes pour répondre au lieu de quelques secondes.

## Installation

### Étape 1 : Télécharger le projet

```bash
# Télécharge le projet depuis GitHub
git clone https://github.com/delferiermaxime-cmd/ai-stack.git

# Entre dans le dossier du projet
cd ai-stack
```

### Étape 2 : Lancer l'installation automatique

```bash
# Rend le script exécutable
chmod +x scripts/*.sh

# Lance l'installation
# Ce script vérifie que tout est en place et vous guide
./scripts/install.sh
```

Le script d'installation va :
1. Vérifier que Docker est installé
2. Vérifier que votre GPU est détecté
3. Vérifier que Docker peut accéder au GPU
4. Vous recommander un modèle adapté à votre GPU
5. Créer le fichier de configuration (.env)
6. Lancer tous les services

### Étape 3 : Installation manuelle (si vous préférez)

```bash
# 1. Copier le fichier de configuration
cp .env.example .env

# 2. Modifier la configuration selon vos besoins
nano .env

# 3. Lancer tous les services
docker compose up -d

# 4. Suivre les logs (optionnel)
docker compose logs -f
```

### Étape 4 : Première connexion

1. Ouvrez votre navigateur et allez sur : **http://ADRESSE-DE-VOTRE-SERVEUR:3000**
2. Cliquez sur "Sign up" (créer un compte)
3. **Le premier compte créé devient automatiquement administrateur**
4. Attendez quelques minutes que le modèle LLM finisse de se charger
5. Le modèle apparaîtra dans le sélecteur en haut de la page de chat

## Configuration post-installation

Après la première connexion en tant qu'administrateur, vérifiez ces paramètres dans **Admin Panel → Settings** :

### Vérifier la connexion LLM
- Allez dans **Admin Panel → Settings → Connections**
- Vous devriez voir une connexion OpenAI pointant vers vLLM
- Le modèle doit apparaître dans la liste

### Vérifier Docling (extraction de documents)
- Allez dans **Admin Panel → Settings → Documents**
- Vérifiez que "Content Extraction Engine" est sur **Docling**
- L'URL du serveur doit être : `http://docling:5001`

### Vérifier l'embedding
- Toujours dans **Documents**, vérifiez que le modèle d'embedding est **BAAI/bge-m3**
- Le moteur d'embedding doit être sur **OpenAI** (car TEI utilise l'API compatible OpenAI)

### Vérifier Qdrant
- La base vectorielle doit être sur **Qdrant**
- L'URI doit être : `http://qdrant:6333`

## Changer de modèle LLM

Vous pouvez changer le modèle d'IA à tout moment. Un seul modèle tourne à la fois (pour économiser la VRAM).

### Méthode simple (script)

```bash
./scripts/switch-model.sh
```

### Méthode manuelle

```bash
# 1. Modifiez le modèle dans le fichier .env
nano .env
# Changez la ligne VLLM_MODEL=...

# 2. Relancez uniquement vLLM
docker compose up -d vllm --force-recreate

# 3. Suivez le chargement du nouveau modèle
docker compose logs -f vllm
```

### Modèles disponibles

| Modèle | VRAM requise | Forces |
|--------|-------------|--------|
| `google/gemma-3-4b-it` | ~3 Go | Rapide, bon pour les tests |
| `meta-llama/Meta-Llama-3.1-8B-Instruct` | ~6-8 Go | Bon équilibre performance/ressources |
| `THUDM/glm-4-9b-chat` | ~6-8 Go | Bon en multilingue |
| `deepseek-ai/DeepSeek-R1-Distill-Qwen-14B` | ~10-12 Go | Raisonnement avancé |
| `google/gemma-3-27b-it` | ~18-20 Go | Le plus puissant |

**Note :** Les modèles Llama et Gemma nécessitent un token HuggingFace (voir la section HF_TOKEN dans le fichier .env).

## Utilisation du RAG (recherche dans vos documents)

### Uploader des documents

1. Dans Open WebUI, allez dans **Workspace → Knowledge**
2. Cliquez sur **"+ Create a Knowledge Base"**
3. Donnez un nom (ex: "Documentation interne")
4. Uploadez vos fichiers (PDF, Word, Excel, PowerPoint, images)
5. Docling va les traiter automatiquement (ça peut prendre quelques minutes pour les gros fichiers)

### Utiliser les documents dans une conversation

- Tapez **#** dans le chat pour voir la liste des bases de connaissances
- Sélectionnez la base que vous voulez utiliser
- Posez votre question : l'IA cherchera la réponse dans vos documents

## Diagnostic et dépannage

### Lancer le diagnostic

```bash
./scripts/diagnostic.sh
```

Ce script vérifie que chaque service fonctionne et vous dit exactement ce qui ne va pas.

### Commandes utiles

```bash
# Voir l'état de tous les services
docker compose ps

# Voir les logs d'un service spécifique
docker compose logs -f vllm      # Logs du LLM
docker compose logs -f tei       # Logs de l'embedding
docker compose logs -f qdrant    # Logs de la base vectorielle
docker compose logs -f docling   # Logs de l'extracteur de documents
docker compose logs -f open-webui # Logs de l'interface

# Redémarrer un service
docker compose restart vllm

# Tout arrêter
docker compose down

# Tout supprimer (attention : efface les données !)
docker compose down -v
```

### Problèmes fréquents

#### vLLM ne démarre pas (erreur "Out of Memory")
Votre GPU n'a pas assez de VRAM pour le modèle choisi.
- Choisissez un modèle plus petit (`./scripts/switch-model.sh`)
- Ou baissez `VLLM_MAX_MODEL_LEN` dans le `.env` (ex: 2048)
- Ou baissez `VLLM_GPU_MEM` dans le `.env` (ex: 0.70)

#### Open WebUI n'affiche aucun modèle
vLLM est encore en train de charger le modèle.
- Vérifiez avec : `docker compose logs -f vllm`
- Attendez de voir "Started server process" dans les logs
- Le premier lancement télécharge le modèle, ça peut prendre 10-30 min

#### Les documents ne sont pas bien extraits
- Vérifiez que Docling est actif : `docker compose logs docling`
- Dans Admin Panel → Settings → Documents, vérifiez que l'engine est sur "Docling"
- Pour les PDF scannés, Docling utilise l'OCR automatiquement

#### Erreur "Cannot connect to host" dans les logs Open WebUI
Les noms de services Docker (`vllm`, `tei`, `qdrant`, `docling`) doivent être utilisés (pas `localhost`). Vérifiez vos variables d'environnement dans le `.env`.

## Structure du projet

```
ai-stack/
├── docker-compose.yml     # Définit et configure tous les services
├── .env.example           # Modèle de configuration (à copier en .env)
├── .gitignore             # Fichiers ignorés par Git
├── README.md              # Ce fichier
├── docs/
│   └── ARCHITECTURE.md    # Documentation technique détaillée
└── scripts/
    ├── install.sh         # Script d'installation automatique
    ├── switch-model.sh    # Script pour changer de modèle LLM
    └── diagnostic.sh      # Script de diagnostic
```

## Sources et documentation

- **vLLM** : [docs.vllm.ai](https://docs.vllm.ai/en/stable/deployment/docker/)
- **TEI** : [huggingface.co/docs/text-embeddings-inference](https://huggingface.co/docs/text-embeddings-inference/)
- **BGE-M3** : [huggingface.co/BAAI/bge-m3](https://huggingface.co/BAAI/bge-m3)
- **Qdrant** : [qdrant.tech/documentation](https://qdrant.tech/documentation/)
- **Docling** : [docs.openwebui.com/.../docling](https://docs.openwebui.com/features/rag/document-extraction/docling/)
- **Open WebUI** : [docs.openwebui.com](https://docs.openwebui.com/)

## Licence

MIT — Utilisez ce projet comme vous le souhaitez.
