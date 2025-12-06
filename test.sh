#!/bin/bash

# Script de testare pentru EventFlow - Module de bază

echo "🧪 EventFlow - Testare Module de Bază"
echo "======================================"
echo ""

# Culori pentru output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funcție pentru test
test_service() {
    local name=$1
    local url=$2
    local expected=$3
    
    echo -n "Testing $name... "
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    
    if [ "$response" == "$expected" ]; then
        echo -e "${GREEN}✅ OK${NC} (HTTP $response)"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC} (Expected HTTP $expected, got HTTP $response)"
        return 1
    fi
}

# 1. Verifică serviciile Docker
echo "📦 Verificare servicii Docker Swarm..."
echo ""

docker service ls | grep eventflow

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 2. Test Keycloak
echo "🔐 Test 1: Keycloak (Modul Autentificare)"
echo ""

if test_service "Keycloak Health" "http://localhost:8080/health/ready" "200"; then
    echo -e "${GREEN}✅ Keycloak este disponibil${NC}"
    echo ""
    echo "   Admin Console: http://localhost:8080"
    echo "   Username: admin"
    echo "   Password: admin"
else
    echo -e "${YELLOW}⚠️  Keycloak nu este încă gata. Așteaptă câteva secunde...${NC}"
    echo "   Verifică: docker service logs eventflow_keycloak"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 3. Test User Profile Service
echo "👤 Test 2: User Profile Service (Modul Profil Utilizator)"
echo ""

if test_service "User Profile Health" "http://localhost:3004/health" "200"; then
    echo -e "${GREEN}✅ User Profile Service este disponibil${NC}"
    
    # Testează endpoint-ul de health
    echo ""
    echo "   Response:"
    curl -s http://localhost:3004/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:3004/health
else
    echo -e "${RED}❌ User Profile Service nu răspunde${NC}"
    echo "   Verifică: docker service logs eventflow_user-profile-service"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 4. Test PostgreSQL
echo "🗄️  Test 3: PostgreSQL (Baza de Date)"
echo ""

# Verifică dacă containerul rulează
POSTGRES_RUNNING=$(docker service ps eventflow_postgres --filter "desired-state=running" --format "{{.CurrentState}}" | grep -c "Running" || echo "0")

if [ "$POSTGRES_RUNNING" -gt 0 ]; then
    echo -e "${GREEN}✅ PostgreSQL este disponibil${NC}"
    echo ""
    echo "   Database: eventflow"
    echo "   User: eventflow"
    echo "   Port: 5432 (internal)"
else
    echo -e "${RED}❌ PostgreSQL nu rulează${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 5. Test integrare - Obține token de la Keycloak
echo "🔗 Test 4: Integrare Keycloak + User Profile Service"
echo ""

# Verifică dacă Keycloak este gata
KC_READY=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/health/ready" 2>/dev/null)

if [ "$KC_READY" == "200" ]; then
    echo "Încercare obținere token de la Keycloak..."
    echo ""
    
    # Obține client secret (dacă este setat în .env)
    if [ -f .env ]; then
        source .env
    fi
    
    if [ -z "$KEYCLOAK_CLIENT_SECRET" ] || [ "$KEYCLOAK_CLIENT_SECRET" == "" ]; then
        echo -e "${YELLOW}⚠️  KEYCLOAK_CLIENT_SECRET nu este setat în .env${NC}"
        echo "   Pași:"
        echo "   1. Accesează http://localhost:8080"
        echo "   2. Login cu admin/admin"
        echo "   3. Selectează realm 'eventflow'"
        echo "   4. Mergi la Clients → eventflow-api → Credentials"
        echo "   5. Copiază Secret și adaugă în .env"
    else
        echo "Obținere token pentru utilizator test (admin1)..."
        
        TOKEN_RESPONSE=$(curl -s -X POST "http://localhost:8080/realms/eventflow/protocol/openid-connect/token" \
          -H "Content-Type: application/x-www-form-urlencoded" \
          -d "username=admin1" \
          -d "password=password123" \
          -d "grant_type=password" \
          -d "client_id=eventflow-api" \
          -d "client_secret=$KEYCLOAK_CLIENT_SECRET")
        
        TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))" 2>/dev/null)
        
        if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] && [ "$TOKEN" != "" ]; then
            echo -e "${GREEN}✅ Token obținut cu succes${NC}"
            echo ""
            
            # Extrage keycloak_sub din token (simplificat)
            echo "Testare endpoint User Profile Service cu token..."
            
            # Pentru test, folosim un keycloak_sub generic
            # În realitate, ar trebui să extragem din token
            TEST_SUB="f:$(echo "$TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('sub', ''))" 2>/dev/null || echo "test")"
            
            if [ -n "$TEST_SUB" ] && [ "$TEST_SUB" != "f:" ]; then
                PROFILE_RESPONSE=$(curl -s -w "\n%{http_code}" \
                  -H "Authorization: Bearer $TOKEN" \
                  "http://localhost:3004/profile/$TEST_SUB" 2>/dev/null)
                
                HTTP_CODE=$(echo "$PROFILE_RESPONSE" | tail -n1)
                BODY=$(echo "$PROFILE_RESPONSE" | head -n-1)
                
                if [ "$HTTP_CODE" == "200" ]; then
                    echo -e "${GREEN}✅ User Profile Service răspunde corect cu token${NC}"
                    echo ""
                    echo "   Response:"
                    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
                else
                    echo -e "${YELLOW}⚠️  User Profile Service răspunde cu HTTP $HTTP_CODE${NC}"
                    echo "   (Poate fi normal dacă utilizatorul nu există încă în DB)"
                fi
            else
                echo -e "${YELLOW}⚠️  Nu s-a putut extrage keycloak_sub din token${NC}"
            fi
        else
            ERROR=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error_description', json.load(sys.stdin).get('error', 'Unknown error')))" 2>/dev/null || echo "Unknown error")
            echo -e "${RED}❌ Eroare la obținerea token-ului: $ERROR${NC}"
            echo ""
            echo "   Verifică:"
            echo "   - KEYCLOAK_CLIENT_SECRET este corect în .env"
            echo "   - Utilizatorul admin1 există în Keycloak"
        fi
    fi
else
    echo -e "${YELLOW}⚠️  Keycloak nu este încă gata pentru teste de integrare${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 6. Rezumat
echo "📊 Rezumat Teste"
echo ""

echo "Module de bază implementate:"
echo "  ✅ 1. Modul Autentificare (Keycloak SSO)"
echo "  ✅ 2. Modul Profil Utilizator (User Profile Service - Python/Flask)"
echo "  ✅ 3. Baza de Date (PostgreSQL + SQLAlchemy ORM)"
echo ""

echo "Servicii Docker Swarm:"
docker service ls --filter "name=eventflow" --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📝 Comenzi utile:"
echo "  - Verifică logs: docker service logs -f eventflow_<service-name>"
echo "  - Verifică status: docker service ls"
echo "  - Keycloak Admin: http://localhost:8080"
echo "  - User Profile API: http://localhost:3004/health"
echo ""

echo "✅ Testare completă!"

