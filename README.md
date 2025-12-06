# EventFlow - Platformă de Management Evenimente

Proiect SCD - Implementarea celor 3 module de bază:
1. **Modul de autentificare** (Keycloak SSO)
2. **Modul de profil utilizator** (Managementul rolurilor)
3. **Baza de date** (PostgreSQL cu SQLAlchemy ORM)

## Arhitectură

- **Keycloak**: Serviciu de autentificare SSO (OAuth/OIDC)
- **User Profile Service**: Microserviciu Python (Flask) pentru managementul profilurilor și rolurilor
- **PostgreSQL**: Baza de date pentru stocarea utilizatorilor și rolurilor
- **Docker Swarm**: Deployment-ul întregii soluții

## Structura Proiectului

```
Proiect-SCD-V2/
├── database/
│   └── schema.sql              # Schema bazei de date
├── services/
│   └── user-profile-service/    # Serviciu Python pentru profiluri
│       ├── app.py              # Aplicația Flask principală
│       ├── requirements.txt    # Dependențe Python
│       └── Dockerfile         # Dockerfile pentru serviciu
├── keycloak-config/
│   └── eventflow-realm.json   # Configurație realm Keycloak
├── docker-stack.yml           # Stack Docker Swarm
└── docker-compose.keycloak.yml # Compose pentru testare locală
```

## Module Implementate

### 1. Modul de Autentificare (Keycloak)

- **Tehnologie**: Keycloak 25.0.0
- **Protocol**: OIDC/OAuth 2.0
- **Funcționalități**:
  - Single Sign-On (SSO)
  - JWT token generation
  - Role-based access control (RBAC)
  - Realm: `eventflow`
  - Roluri: ADMIN, ORGANIZER, ATTENDEE, STAFF

### 2. Modul de Profil Utilizator

- **Tehnologie**: Python 3.11 + Flask + SQLAlchemy
- **Funcționalități**:
  - Sincronizare automată cu Keycloak
  - Managementul profilurilor utilizatorilor
  - Managementul rolurilor (CRUD)
  - Validare JWT token
  - RBAC middleware

### 3. Baza de Date

- **Tehnologie**: PostgreSQL 15
- **ORM**: SQLAlchemy
- **Tabele**:
  - `users`: Profiluri utilizatori (sincronizate cu Keycloak)
  - `user_roles`: Rolurile utilizatorilor

## Deployment

### Prerequisit: Docker Swarm

```bash
# Inițializare Docker Swarm (dacă nu este deja inițializat)
docker swarm init

# Creare rețele
docker network create --driver overlay data-network
docker network create --driver overlay internal-network
```

### Deploy Stack

```bash
# 1. Construiește imaginile Docker (necesar pentru Docker Swarm)
./build-images.sh

# 2. Deploy întreg stack-ul
docker stack deploy -c docker-stack.yml eventflow

# 3. Verificare servicii
docker service ls

# 4. Verificare logs
docker service logs eventflow_user-profile-service
docker service logs eventflow_keycloak
```

### Testare Locală (Docker Compose)

```bash
# Pornire Keycloak
docker-compose -f docker-compose.keycloak.yml up -d

# Pornire User Profile Service (în alt terminal)
cd services/user-profile-service
docker build -t user-profile-service .
docker run -p 3004:3004 \
  -e DATABASE_URL=postgresql://eventflow:eventflow@localhost:5432/eventflow \
  -e KEYCLOAK_URL=http://localhost:8080 \
  user-profile-service
```

## Configurare

### Variabile de Mediu

Creează un fișier `.env` sau setează variabilele:

```env
# Database
POSTGRES_DB=eventflow
POSTGRES_USER=eventflow
POSTGRES_PASSWORD=eventflow

# Keycloak
KEYCLOAK_REALM=eventflow
KEYCLOAK_CLIENT_ID=eventflow-api
KEYCLOAK_CLIENT_SECRET=<obține din Keycloak Admin Console>
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin
KEYCLOAK_HOSTNAME=localhost
```

### Obținere Client Secret

1. Accesează Keycloak Admin Console: http://localhost:8080
2. Login: `admin` / `admin`
3. Selectează realm `eventflow`
4. Mergi la **Clients** → **eventflow-api** → **Credentials**
5. Copiază **Secret** și setează în `KEYCLOAK_CLIENT_SECRET`

## API Endpoints

### User Profile Service

- `GET /health` - Health check
- `GET /profile/<keycloak_sub>` - Obține profil utilizator (necesită JWT)
- `PUT /profile/<keycloak_sub>` - Actualizează profil (necesită JWT)
- `GET /profile/<keycloak_sub>/roles` - Obține rolurile (necesită JWT)
- `POST /profile/<keycloak_sub>/roles` - Adaugă rol (necesită ADMIN)
- `DELETE /profile/<keycloak_sub>/roles/<role>` - Șterge rol (necesită ADMIN)

### Autentificare

Obține token de la Keycloak:

```bash
curl -X POST http://localhost:8080/realms/eventflow/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin1" \
  -d "password=password123" \
  -d "grant_type=password" \
  -d "client_id=eventflow-api" \
  -d "client_secret=<YOUR_SECRET>"
```

## Utilizatori de Test

| Username | Password | Role |
|----------|----------|------|
| admin1 | password123 | ADMIN |
| organizer1 | password123 | ORGANIZER |
| attendee1 | password123 | ATTENDEE |
| staff1 | password123 | STAFF |

## Verificare Funcționalitate

```bash
# 1. Verifică serviciile
docker service ls

# 2. Verifică logs
docker service logs -f eventflow_user-profile-service

# 3. Testează health check
curl http://localhost:3004/health

# 4. Obține token și testează API
TOKEN=$(curl -s -X POST http://localhost:8080/realms/eventflow/protocol/openid-connect/token \
  -d "username=admin1&password=password123&grant_type=password&client_id=eventflow-api&client_secret=<SECRET>" \
  | jq -r '.access_token')

curl -H "Authorization: Bearer $TOKEN" http://localhost:3004/profile/<keycloak_sub>
```

## Componente

- **Open Source**: Keycloak, PostgreSQL
- **Proprii**: User Profile Service (Python/Flask)

## Note

- Toate serviciile comunică prin nume DNS (ex: `postgres`, `keycloak`)
- Variabilele de mediu sunt folosite pentru configurare (nu hardcoded)
- Stack-ul este gata pentru producție (cu ajustări de securitate)

