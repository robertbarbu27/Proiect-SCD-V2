#!/bin/bash

# Script pentru construirea imaginilor Docker necesare pentru Docker Swarm

echo "🔨 Construire imagini Docker pentru EventFlow..."
echo ""

# Construiește imaginea pentru User Profile Service
echo "📦 Construire user-profile-service..."
docker build -t eventflow/user-profile-service:latest ./services/user-profile-service

if [ $? -eq 0 ]; then
    echo "✅ user-profile-service construit cu succes"
else
    echo "❌ Eroare la construirea user-profile-service"
    exit 1
fi

echo ""
echo "✅ Toate imaginile au fost construite cu succes!"
echo ""
echo "📋 Următorul pas:"
echo "   docker stack deploy -c docker-stack.yml eventflow"

