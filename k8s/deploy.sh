#!/bin/bash
# Deploy EventFlow pe Kubernetes
# Rulează din root-ul proiectului: ./k8s/deploy.sh

set -e

echo "=== EventFlow Kubernetes Deploy ==="

# 1. Namespace + config de baza
kubectl apply -f k8s/00-namespace.yml
kubectl apply -f k8s/01-secrets.yml
kubectl apply -f k8s/02-configmap.yml
kubectl apply -f k8s/03-storage.yml

# 2. Keycloak realm ConfigMap (din fisierul local)
kubectl create configmap keycloak-realm \
  --from-file=eventflow-realm.json=keycloak-config/eventflow-realm.json \
  -n eventflow --dry-run=client -o yaml | kubectl apply -f -

# 3. Infrastructura (postgres, redis, rabbitmq)
kubectl apply -f k8s/04-infra.yml
echo "Astept PostgreSQL sa fie ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n eventflow --timeout=120s

# 4. Keycloak
kubectl apply -f k8s/05-keycloak.yml

# 5. Kong API Gateway
kubectl apply -f k8s/06-kong.yml

# 6. Microservicii proprii
kubectl apply -f k8s/07-microservices.yml

# 7. Support (pgAdmin + Portainer)
kubectl apply -f k8s/08-support.yml

# 8. Monitoring (Prometheus + Grafana)
kubectl apply -f k8s/09-monitoring.yml

echo ""
echo "=== Deploy complet! ==="
echo "Verificare:"
kubectl get pods -n eventflow
echo ""
echo "URL-uri (minikube: inlocuieste localhost cu \$(minikube ip)):"
echo "  Kong (API):    http://localhost:30020/api/*"
echo "  Keycloak:      http://localhost:30080"
echo "  pgAdmin:       http://localhost:30059"
echo "  Portainer:     http://localhost:30900"
echo "  Prometheus:    http://localhost:30090"
echo "  Grafana:       http://localhost:30300"
