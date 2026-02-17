#!/bin/bash
# =============================================================================
#  Script de diagnostic - Vérifie que tout fonctionne
# =============================================================================
#
#  Lance ce script si quelque chose ne marche pas.
#  Il vérifie chaque service et te dit exactement ce qui ne va pas.
#
#  Utilisation :
#    ./scripts/diagnostic.sh
#
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "  Diagnostic de la Stack IA"
echo "=========================================="
echo ""

# Compteur d'erreurs
ERRORS=0

# --- Fonction de test d'un service ---
# Vérifie si un service répond sur un URL donné
check_service() {
    local name=$1      # Nom du service (pour l'affichage)
    local url=$2       # URL à tester
    local port=$3      # Port (pour l'affichage)

    printf "  %-15s " "${name}..."

    # curl envoie une requête HTTP et vérifie la réponse
    # -s  : mode silencieux (pas de barre de progression)
    # -o  : redirige la sortie vers /dev/null (on ne veut pas voir le contenu)
    # -w  : affiche le code HTTP de la réponse
    # --max-time : timeout de 5 secondes
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)

    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
        echo -e "${GREEN}OK${NC} (port ${port}, HTTP ${HTTP_CODE})"
    else
        echo -e "${RED}ERREUR${NC} (port ${port}, HTTP ${HTTP_CODE})"
        ERRORS=$((ERRORS + 1))
    fi
}

# --- 1. État des conteneurs Docker ---
echo -e "${BLUE}1. État des conteneurs Docker${NC}"
echo ""
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
echo ""

# --- 2. Test de chaque service ---
echo -e "${BLUE}2. Test de connectivité des services${NC}"
echo ""

# Lit les ports depuis le .env (ou utilise les valeurs par défaut)
source .env 2>/dev/null

check_service "vLLM" "http://localhost:${VLLM_PORT:-8000}/health" "${VLLM_PORT:-8000}"
check_service "TEI" "http://localhost:${TEI_PORT:-8081}/health" "${TEI_PORT:-8081}"
check_service "Qdrant" "http://localhost:${QDRANT_PORT:-6333}/healthz" "${QDRANT_PORT:-6333}"
check_service "Docling" "http://localhost:${DOCLING_PORT:-5001}/health" "${DOCLING_PORT:-5001}"
check_service "Open WebUI" "http://localhost:${WEBUI_PORT:-3000}" "${WEBUI_PORT:-3000}"

echo ""

# --- 3. Vérification GPU ---
echo -e "${BLUE}3. Utilisation du GPU${NC}"
echo ""
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits | while IFS=',' read -r name util used total; do
        echo "  GPU : ${name}"
        echo "  Utilisation : ${util}%"
        echo "  VRAM : ${used} Mo / ${total} Mo"
    done
else
    echo -e "  ${RED}nvidia-smi non disponible${NC}"
fi
echo ""

# --- 4. Vérification du modèle vLLM ---
echo -e "${BLUE}4. Modèle LLM chargé${NC}"
echo ""
MODELS=$(curl -s http://localhost:${VLLM_PORT:-8000}/v1/models 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$MODELS" ]; then
    echo "  $MODELS" | python3 -m json.tool 2>/dev/null || echo "  $MODELS"
else
    echo -e "  ${YELLOW}vLLM n'est pas encore prêt (le modèle est en cours de chargement)${NC}"
fi
echo ""

# --- 5. Test de l'embedding ---
echo -e "${BLUE}5. Test de l'embedding (TEI + BGE-M3)${NC}"
echo ""
EMBED_RESULT=$(curl -s -X POST http://localhost:${TEI_PORT:-8081}/embed \
    -H "Content-Type: application/json" \
    -d '{"inputs":"test"}' --max-time 10 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$EMBED_RESULT" ]; then
    # Vérifie que la réponse contient des nombres (= des vecteurs)
    if echo "$EMBED_RESULT" | grep -q "\["; then
        echo -e "  ${GREEN}OK${NC} - L'embedding fonctionne correctement"
    else
        echo -e "  ${RED}ERREUR${NC} - Réponse inattendue : $EMBED_RESULT"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "  ${YELLOW}TEI n'est pas encore prêt${NC}"
fi
echo ""

# --- 6. Espace disque ---
echo -e "${BLUE}6. Espace disque${NC}"
echo ""
df -h / | awk 'NR==2 {print "  Utilisé : " $3 " / " $2 " (" $5 " utilisé)"}'
echo ""
echo "  Volumes Docker :"
docker system df --format "  Images: {{.Images.Size}}  |  Conteneurs: {{.Containers.Size}}  |  Volumes: {{.Volumes.Size}}" 2>/dev/null
echo ""

# --- Résumé ---
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "  ${GREEN}Tout fonctionne correctement !${NC}"
else
    echo -e "  ${RED}${ERRORS} problème(s) détecté(s)${NC}"
    echo ""
    echo "  Conseils de dépannage :"
    echo "    - Voir les logs : docker compose logs -f [service]"
    echo "    - Redémarrer un service : docker compose restart [service]"
    echo "    - Tout relancer : docker compose down && docker compose up -d"
fi
echo "=========================================="
echo ""
