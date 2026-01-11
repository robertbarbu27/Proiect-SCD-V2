#!/bin/bash

# Demo complet EventFlow – SSO + Profile Service + DB

set -e

echo "🚀 EventFlow Demo"
echo "================="
echo ""

cd "$(dirname "$0")"

if [ -f .env ]; then
  echo "➡️  Încarc variabilele din .env..."
  # shellcheck disable=SC1091
  source .env
else
  echo "⚠️  Fișierul .env nu există în directorul curent."
  echo "    Setează KEYCLOAK_CLIENT_SECRET și DB vars înainte de demo."
  echo ""
fi

echo "1️⃣  Servicii Docker Swarm:"
docker service ls --filter "name=eventflow" --format "  {{.Name}}\t{{.Replicas}}\t{{.Image}}"
echo ""

echo "2️⃣  Health check User Profile Service:"
curl -s http://localhost:3004/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:3004/health
echo ""

echo "3️⃣  Obțin token de la Keycloak pentru utilizatorul admin1..."
if [ -z "$KEYCLOAK_REALM" ]; then
  KEYCLOAK_REALM="eventflow"
fi
if [ -z "$KEYCLOAK_CLIENT_ID" ]; then
  KEYCLOAK_CLIENT_ID="eventflow-api"
fi

TOKEN=$(curl -s -X POST \
  "http://localhost:8080/realms/$KEYCLOAK_REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin1" \
  -d "password=password123" \
  -d "grant_type=password" \
  -d "client_id=$KEYCLOAK_CLIENT_ID" \
  -d "client_secret=$KEYCLOAK_CLIENT_SECRET" \
  | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "❌ Nu am putut obține token. Verifică:"
  echo "   - KEYCLOAK_CLIENT_SECRET în .env"
  echo "   - Utilizatorul admin1 în Keycloak"
  exit 1
fi

echo "   Token (primele 40 caractere):"
echo "   ${TOKEN:0:40}..."
echo ""

echo "4️⃣  Get /profile/admin1 (creează/sincronizează profilul în DB):"
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:3004/profile/admin1 | python3 -m json.tool 2>/dev/null || curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3004/profile/admin1
echo ""

echo "5️⃣  Get /profile/admin1/roles (roluri sincronizate din Keycloak):"
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:3004/profile/admin1/roles | python3 -m json.tool 2>/dev/null || curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3004/profile/admin1/roles
echo ""




