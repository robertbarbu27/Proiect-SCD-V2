#!/bin/bash

# Test rapid pentru servicii

echo "🚀 Test Rapid EventFlow"
echo ""

# Test User Profile Service
echo "1. User Profile Service:"
curl -s http://localhost:3004/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:3004/health
echo ""
echo ""

# Test Keycloak
echo "2. Keycloak:"
KC_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health/ready 2>/dev/null)
if [ "$KC_STATUS" == "200" ]; then
    echo "✅ Keycloak este gata!"
    echo "   Admin Console: http://localhost:8080"
else
    echo "⏳ Keycloak se pornește... (HTTP $KC_STATUS)"
fi
echo ""

# Status servicii
echo "3. Status Servicii:"
docker service ls --filter "name=eventflow" --format "  {{.Name}}: {{.Replicas}}"
echo ""

echo "✅ Test complet!"

