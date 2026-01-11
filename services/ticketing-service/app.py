"""
Ticketing Service - Managementul evenimentelor și biletelor
Integrare cu Keycloak pentru SSO și RBAC
"""
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
import os
import jwt
import requests
from datetime import datetime
from functools import wraps

app = Flask(__name__)
CORS(app)

# Configuration
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv(
    'DATABASE_URL',
    'postgresql://eventflow:eventflow@postgres:5432/eventflow'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Keycloak configuration
KEYCLOAK_URL = os.getenv('KEYCLOAK_URL', 'http://keycloak:8080')
KEYCLOAK_REALM = os.getenv('KEYCLOAK_REALM', 'eventflow')
KEYCLOAK_CLIENT_ID = os.getenv('KEYCLOAK_CLIENT_ID', 'eventflow-api')
# URL public (issuer din token)
KEYCLOAK_PUBLIC_URL = os.getenv('KEYCLOAK_PUBLIC_URL', KEYCLOAK_URL)

db = SQLAlchemy(app)


# Models
class Event(db.Model):
    __tablename__ = 'events'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text)
    location = db.Column(db.String(255))
    starts_at = db.Column(db.DateTime, nullable=False)
    total_tickets = db.Column(db.Integer, nullable=False)
    tickets_sold = db.Column(db.Integer, nullable=False, default=0)
    created_by = db.Column(db.String(255))  # keycloak_sub
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    tickets = db.relationship('Ticket', backref='event', lazy=True, cascade='all, delete-orphan')

    def remaining_tickets(self) -> int:
        return max(self.total_tickets - self.tickets_sold, 0)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'location': self.location,
            'starts_at': self.starts_at.isoformat() if self.starts_at else None,
            'total_tickets': self.total_tickets,
            'tickets_sold': self.tickets_sold,
            'remaining_tickets': self.remaining_tickets(),
            'created_by': self.created_by,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }


class Ticket(db.Model):
    __tablename__ = 'tickets'

    id = db.Column(db.Integer, primary_key=True)
    event_id = db.Column(db.Integer, db.ForeignKey('events.id', ondelete='CASCADE'), nullable=False)
    keycloak_sub = db.Column(db.String(255), nullable=False)
    purchased_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'event_id': self.event_id,
            'keycloak_sub': self.keycloak_sub,
            'purchased_at': self.purchased_at.isoformat() if self.purchased_at else None,
            'event': self.event.to_dict() if self.event else None,
        }


# Auth helpers (copiat și simplificat din User Profile Service)
def verify_token(f):
    """Decorator pentru verificarea JWT token-ului de la Keycloak"""

    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization')

        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'No token provided'}), 401

        token = auth_header.split(' ')[1]

        try:
            jwks_url = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/certs"
            jwks_response = requests.get(jwks_url)
            jwks = jwks_response.json()

            unverified_header = jwt.get_unverified_header(token)
            kid = unverified_header.get('kid')

            key = None
            for jwk in jwks.get('keys', []):
                if jwk.get('kid') == kid:
                    key = jwt.algorithms.RSAAlgorithm.from_jwk(jwk)
                    break

            if not key:
                return jsonify({'error': 'Invalid token key'}), 401

            decoded = jwt.decode(
                token,
                key,
                algorithms=['RS256'],
                options={'verify_aud': False},
                issuer=f"{KEYCLOAK_PUBLIC_URL}/realms/{KEYCLOAK_REALM}",
            )

            request.user = decoded
            request.user_roles = decoded.get('realm_access', {}).get('roles', [])
            request.user_sub = decoded.get('sub')

        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token expired'}), 401
        except jwt.InvalidTokenError as e:
            return jsonify({'error': f'Invalid token: {str(e)}'}), 401
        except Exception as e:
            return jsonify({'error': f'Token verification failed: {str(e)}'}), 401

        return f(*args, **kwargs)

    return decorated


def require_role(*allowed_roles):
    def decorator(f):
        @wraps(f)
        @verify_token
        def decorated(*args, **kwargs):
            user_roles = getattr(request, 'user_roles', [])
            if not any(role in user_roles for role in allowed_roles):
                return jsonify({'error': 'Insufficient permissions'}), 403
            return f(*args, **kwargs)

        return decorated

    return decorator


# Routes
@app.route('/health', methods=['GET'])
def health():
    return jsonify({'service': 'ticketing-service', 'status': 'ok'}), 200


@app.route('/events', methods=['GET'])
def list_events():
    """Listă toate evenimentele (public)."""
    events = Event.query.order_by(Event.starts_at.asc()).all()
    return jsonify([e.to_dict() for e in events]), 200


@app.route('/events', methods=['POST'])
@require_role('ADMIN', 'ORGANIZER')
def create_event():
    """Creează un nou eveniment (ADMIN / ORGANIZER)."""
    data = request.get_json() or {}

    try:
        name = data['name']
        starts_at_str = data['starts_at']
        total_tickets = int(data.get('total_tickets', 0))
    except (KeyError, ValueError):
        return jsonify({'error': 'name, starts_at, total_tickets sunt obligatorii'}), 400

    try:
        starts_at = datetime.fromisoformat(starts_at_str)
    except ValueError:
        return jsonify({'error': 'starts_at trebuie să fie ISO 8601 (ex: 2025-12-31T18:00:00)'}), 400

    event = Event(
        name=name,
        description=data.get('description'),
        location=data.get('location'),
        starts_at=starts_at,
        total_tickets=total_tickets,
        created_by=getattr(request, 'user_sub', None),
    )
    db.session.add(event)
    db.session.commit()

    return jsonify(event.to_dict()), 201


@app.route('/events/<int:event_id>', methods=['GET'])
def get_event(event_id):
    event = Event.query.get(event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404
    return jsonify(event.to_dict()), 200


@app.route('/events/<int:event_id>/tickets', methods=['POST'])
@verify_token
def buy_ticket(event_id):
    """Cumpără un bilet pentru utilizatorul curent."""
    event = Event.query.get(event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404

    if event.remaining_tickets() <= 0:
        return jsonify({'error': 'No tickets available'}), 400

    ticket = Ticket(
        event_id=event.id,
        keycloak_sub=request.user_sub,
    )
    event.tickets_sold += 1

    db.session.add(ticket)
    db.session.commit()

    return jsonify(ticket.to_dict()), 201


@app.route('/my-tickets', methods=['GET'])
@verify_token
def my_tickets():
    """Listează toate biletele utilizatorului curent."""
    tickets = Ticket.query.filter_by(keycloak_sub=request.user_sub).all()
    return jsonify([t.to_dict() for t in tickets]), 200


if __name__ == '__main__':
    with app.app_context():
        db.create_all()

    port = int(os.getenv('PORT', 3005))
    app.run(host='0.0.0.0', port=port, debug=False)




