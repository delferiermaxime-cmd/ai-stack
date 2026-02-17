#!/bin/bash
# =============================================================================
#  Script d'installation de la Stack IA
# =============================================================================
#
#  Ce script vérifie que votre serveur a tout ce qu'il faut,
#  puis lance la stack automatiquement.
#
#  Utilisation :
#    chmod +x scripts/install.sh
#    ./scripts/install.sh
#
# =============================================================================

# --- Couleurs pour les messages (rend la lecture plus facile) ---
RED='\033[0;31m'      # Rouge pour les erreurs
GREEN='\033[0;32m'    # Vert pour les succès
YELLOW='\033[1;33m'   # Jaune pour les avertissements
BLUE='\033[0;34m'     # Bleu pour les informations
NC='\033[0m'          # Remet la couleur par défaut

# --- Fonctions d'affichage ---
# Ces fonctions ajoutent des icônes et des couleurs aux messages

info() {
    # Affiche un message d'information en bleu
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    # Affiche un message de succès en vert
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    # Affiche un avertissement en jaune
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
}

error() {
    # Affiche une erreur en rouge et arrête le script
    echo -e "${RED}[ERREUR]${NC} $1"
    exit 1
}

# =============================================================================
#  ÉTAPE 1 : Vérification de Docker
# =============================================================================
#
#  Docker est le logiciel qui fait tourner les conteneurs.
#  Sans lui, rien ne peut fonctionner.
#

echo ""
echo "=========================================="
echo "  Installation de la Stack IA"
echo "=========================================="
echo ""

info "Vérification de Docker..."

# La commande 'command -v' vérifie si un programme est installé
if ! command -v docker &> /dev/null; then
    error "Docker n'est pas installé.
    
    Pour l'installer sur Ubuntu/Debian :
    
      curl -fsSL https://get.docker.com | sh
      sudo usermod -aG docker \$USER
      
    Puis déconnectez-vous et reconnectez-vous."
fi

# Vérifie que Docker Compose est disponible (intégré dans Docker récent)
if ! docker compose version &> /dev/null; then
    error "Docker Compose n'est pas disponible.
    
    Mettez à jour Docker vers une version récente :
      sudo apt update && sudo apt install docker-compose-plugin"
fi

success "Docker $(docker --version | grep -oP 'version \K[^,]+') détecté"

# =============================================================================
#  ÉTAPE 2 : Vérification du GPU NVIDIA
# =============================================================================
#
#  Les modèles d'IA ont besoin d'un GPU (carte graphique) NVIDIA pour fonctionner.
#  On vérifie que le GPU est détecté et que les drivers sont installés.
#

info "Vérification du GPU NVIDIA..."

# nvidia-smi est l'outil qui affiche les infos du GPU
if ! command -v nvidia-smi &> /dev/null; then
    error "Les drivers NVIDIA ne sont pas installés.
    
    Pour les installer sur Ubuntu :
      sudo apt update
      sudo apt install nvidia-driver-535
      sudo reboot"
fi

# Récupère les informations du GPU
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1)
GPU_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)

success "GPU détecté : ${GPU_NAME} (${GPU_VRAM} Mo de VRAM)"

# =============================================================================
#  ÉTAPE 3 : Vérification de NVIDIA Container Toolkit
# =============================================================================
#
#  C'est le pont entre Docker et le GPU.
#  Sans lui, les conteneurs ne peuvent pas accéder au GPU.
#

info "Vérification de NVIDIA Container Toolkit..."

# Essaie de lancer un conteneur avec accès GPU
if ! docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
    warn "NVIDIA Container Toolkit ne semble pas fonctionner."
    echo ""
    echo "  Pour l'installer :"
    echo ""
    echo "    # Ajouter le dépôt NVIDIA"
    echo "    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
    echo "    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \\"
    echo "      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \\"
    echo "      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list"
    echo ""
    echo "    # Installer"
    echo "    sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit"
    echo ""
    echo "    # Configurer Docker pour utiliser le GPU"
    echo "    sudo nvidia-ctk runtime configure --runtime=docker"
    echo "    sudo systemctl restart docker"
    echo ""
    
    read -p "Voulez-vous continuer quand même ? (o/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        exit 1
    fi
else
    success "NVIDIA Container Toolkit fonctionne correctement"
fi

# =============================================================================
#  ÉTAPE 4 : Recommandation de modèle selon la VRAM
# =============================================================================
#
#  Selon la quantité de VRAM (mémoire du GPU), on recommande un modèle.
#  Un modèle trop gros pour votre GPU causera une erreur "Out of Memory".
#

echo ""
info "Recommandation de modèle basée sur votre GPU (${GPU_VRAM} Mo de VRAM) :"
echo ""

# Convertit la VRAM en Go pour les comparaisons
VRAM_GB=$((GPU_VRAM / 1024))

if [ "$VRAM_GB" -ge 40 ]; then
    echo "  Votre GPU a ${VRAM_GB} Go de VRAM — Excellent !"
    echo "  → Vous pouvez utiliser TOUS les modèles, y compris Gemma 3 27B"
    RECOMMENDED_MODEL="google/gemma-3-27b-it"
elif [ "$VRAM_GB" -ge 20 ]; then
    echo "  Votre GPU a ${VRAM_GB} Go de VRAM — Très bien"
    echo "  → Recommandé : DeepSeek-R1 14B ou modèles jusqu'à ~14B"
    RECOMMENDED_MODEL="deepseek-ai/DeepSeek-R1-Distill-Qwen-14B"
elif [ "$VRAM_GB" -ge 12 ]; then
    echo "  Votre GPU a ${VRAM_GB} Go de VRAM — Correct"
    echo "  → Recommandé : Llama 3 8B ou GLM-4 9B"
    RECOMMENDED_MODEL="meta-llama/Meta-Llama-3.1-8B-Instruct"
elif [ "$VRAM_GB" -ge 8 ]; then
    echo "  Votre GPU a ${VRAM_GB} Go de VRAM — Limité"
    echo "  → Recommandé : Gemma 3 4B (le plus léger)"
    echo "  → Pensez à baisser VLLM_MAX_MODEL_LEN à 2048"
    RECOMMENDED_MODEL="google/gemma-3-4b-it"
else
    warn "Votre GPU a moins de 8 Go de VRAM."
    echo "  Les performances seront très limitées."
    echo "  → Utilisez Gemma 3 4B avec un contexte réduit"
    RECOMMENDED_MODEL="google/gemma-3-4b-it"
fi

echo ""

# =============================================================================
#  ÉTAPE 5 : Création du fichier .env
# =============================================================================

info "Configuration de l'environnement..."

# Vérifie si le fichier .env existe déjà
if [ -f .env ]; then
    warn "Le fichier .env existe déjà."
    read -p "Voulez-vous le remplacer ? (o/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        info "Conservation du fichier .env existant."
    else
        # Copie le fichier exemple comme nouveau .env
        cp .env.example .env
        success "Fichier .env créé à partir de .env.example"
    fi
else
    # Copie le fichier exemple
    cp .env.example .env
    success "Fichier .env créé à partir de .env.example"
fi

# =============================================================================
#  ÉTAPE 6 : Lancement de la stack
# =============================================================================

echo ""
info "Tout est prêt ! Lancement de la stack..."
echo ""
echo "  Cela va :"
echo "    1. Télécharger les images Docker (première fois uniquement)"
echo "    2. Télécharger le modèle LLM (~2-15 Go selon le modèle)"
echo "    3. Télécharger le modèle d'embedding BGE-M3 (~2 Go)"
echo "    4. Démarrer tous les services"
echo ""
echo "  Le premier lancement peut prendre 10 à 30 minutes."
echo ""

read -p "Lancer maintenant ? (O/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    info "Pour lancer plus tard :"
    echo "    docker compose up -d"
    echo ""
    exit 0
fi

# Lance tous les services en arrière-plan
docker compose up -d

echo ""
success "Stack lancée !"
echo ""
echo "=========================================="
echo "  Comment accéder aux services"
echo "=========================================="
echo ""
echo "  Open WebUI  : http://localhost:${WEBUI_PORT:-3000}"
echo "  vLLM API    : http://localhost:${VLLM_PORT:-8000}"
echo "  Qdrant      : http://localhost:${QDRANT_PORT:-6333}/dashboard"
echo "  Docling     : http://localhost:${DOCLING_PORT:-5001}"
echo ""
echo "=========================================="
echo "  Première connexion à Open WebUI"
echo "=========================================="
echo ""
echo "  1. Ouvrez http://localhost:${WEBUI_PORT:-3000} dans votre navigateur"
echo "  2. Créez un compte (le premier compte sera administrateur)"
echo "  3. Attendez que le modèle LLM apparaisse dans le sélecteur"
echo "     (cela peut prendre quelques minutes au premier lancement)"
echo ""
echo "=========================================="
echo "  Commandes utiles"
echo "=========================================="
echo ""
echo "  Voir l'état  : docker compose ps"
echo "  Voir les logs : docker compose logs -f"
echo "  Tout arrêter  : docker compose down"
echo "  Redémarrer    : docker compose restart"
echo ""
