#!/bin/bash
# =============================================================================
#  Script de changement de modèle LLM
# =============================================================================
#
#  Ce script permet de changer facilement le modèle d'IA utilisé.
#  Il modifie le fichier .env et relance le service vLLM.
#
#  Utilisation :
#    ./scripts/switch-model.sh
#
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "  Changement de modèle LLM"
echo "=========================================="
echo ""

# Liste des modèles disponibles avec leur consommation VRAM estimée
echo "  Modèles disponibles :"
echo ""
echo "    1) Gemma 3 4B       (~3 Go VRAM)   - Rapide, bon pour les tests"
echo "    2) Llama 3.1 8B     (~6-8 Go VRAM) - Bon équilibre"
echo "    3) GLM-4 9B         (~6-8 Go VRAM) - Bon en multilingue"
echo "    4) DeepSeek R1 14B  (~10-12 Go)    - Raisonnement avancé"
echo "    5) Gemma 3 27B      (~18-20 Go)    - Le plus puissant"
echo ""

# Demande le choix de l'utilisateur
read -p "  Votre choix (1-5) : " choice

# Associe le choix au nom du modèle HuggingFace
case $choice in
    1) MODEL="google/gemma-3-4b-it" ;;
    2) MODEL="meta-llama/Meta-Llama-3.1-8B-Instruct" ;;
    3) MODEL="THUDM/glm-4-9b-chat" ;;
    4) MODEL="deepseek-ai/DeepSeek-R1-Distill-Qwen-14B" ;;
    5) MODEL="google/gemma-3-27b-it" ;;
    *)
        echo -e "${RED}Choix invalide.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}[INFO]${NC} Modèle sélectionné : ${MODEL}"

# Vérifie que le fichier .env existe
if [ ! -f .env ]; then
    echo -e "${RED}[ERREUR]${NC} Fichier .env introuvable. Lancez d'abord ./scripts/install.sh"
    exit 1
fi

# Modifie la ligne VLLM_MODEL dans le fichier .env
# sed remplace la ligne qui commence par VLLM_MODEL= (commentée ou non)
# par la nouvelle valeur
sed -i "s|^#*VLLM_MODEL=.*|VLLM_MODEL=${MODEL}|" .env

echo -e "${GREEN}[OK]${NC} Fichier .env mis à jour"
echo ""

# Relance uniquement le service vLLM (les autres services ne sont pas affectés)
echo -e "${BLUE}[INFO]${NC} Relancement de vLLM avec le nouveau modèle..."
echo "  (Le téléchargement peut prendre plusieurs minutes si c'est un nouveau modèle)"
echo ""

docker compose up -d vllm --force-recreate

echo ""
echo -e "${GREEN}[OK]${NC} vLLM est en train de charger ${MODEL}"
echo ""
echo "  Suivez la progression avec : docker compose logs -f vllm"
echo "  Le modèle sera disponible dans Open WebUI quand vLLM sera prêt."
echo ""
