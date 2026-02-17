#!/bin/bash
# =============================================================================
#  Script de changement de modèle LLM (Open Source)
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
echo "  Changement de modèle LLM (Open Source)"
echo "=========================================="
echo ""

# Liste des modèles disponibles avec leur consommation VRAM estimée
echo "  Modèles disponibles :"
echo ""
echo "    1) GLM-4 9B          (~6-8 Go VRAM)  - Multilingue, open source"
echo "    2) DeepSeek R1 14B   (~10-12 Go VRAM) - Raisonnement avancé, open source"
echo "    3) Mistral 7B        (~6-7 Go VRAM)  - Très rapide, open source"
echo "    4) RedPajama 7B      (~7 Go VRAM)    - Instruction fine-tuning"
echo "    5) RedPajama 13B     (~12-13 Go VRAM) - Plus puissant"
echo ""

# Demande le choix de l'utilisateur
read -p "  Votre choix (1-5) : " choice

# Associe le choix au nom du modèle HuggingFace
case $choice in
    1) MODEL="THUDM/glm-4-9b-chat" ;;
    2) MODEL="deepseek-ai/DeepSeek-R1-Distill-Qwen-14B" ;;
    3) MODEL="mistralai/Mistral-7B-Instruct-v0.2" ;;
    4) MODEL="togethercomputer/RedPajama-INCITE-7B-Instruct" ;;
    5) MODEL="togethercomputer/RedPajama-INCITE-13B-Instruct" ;;
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
sed -i "s|^#*VLLM_MODEL=.*|VLLM_MODEL=${MODEL}|" .env

echo -e "${GREEN}[OK]${NC} Fichier .env mis à jour"
echo ""

# Relance uniquement le service vLLM
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
