import React, { useEffect, useState } from 'react';

const API_BASE = 'http://localhost:3005';

function getStoredToken() {
  return window.localStorage.getItem('eventflow_token') || '';
}

function setStoredToken(token) {
  window.localStorage.setItem('eventflow_token', token || '');
}

export default function App() {
  const [token, setToken] = useState(getStoredToken());
  const [tokenStatus, setTokenStatus] = useState(token ? 'token set' : 'no token');
  const [events, setEvents] = useState([]);
  const [loadingEvents, setLoadingEvents] = useState(false);
  const [createResult, setCreateResult] = useState('');
  const [myTickets, setMyTickets] = useState('');

  const [evName, setEvName] = useState('');
  const [evLocation, setEvLocation] = useState('');
  const [evStartsAt, setEvStartsAt] = useState('');
  const [evTickets, setEvTickets] = useState(100);
  const [evDescription, setEvDescription] = useState('');

  useEffect(() => {
    loadEvents();
  }, []);

  function handleSaveToken() {
    setStoredToken(token);
    setTokenStatus(token ? 'token set' : 'no token');
  }

  async function loadEvents() {
    setLoadingEvents(true);
    try {
      const res = await fetch(`${API_BASE}/events`);
      const data = await res.json();
      if (Array.isArray(data)) {
        setEvents(data);
      } else {
        setEvents([]);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoadingEvents(false);
    }
  }

  async function createEvent() {
    setCreateResult('Sending...');
    if (!token) {
      setCreateResult('Please paste an ADMIN / ORGANIZER token first.');
      return;
    }
    const body = {
      name: evName,
      location: evLocation,
      starts_at: evStartsAt,
      total_tickets: Number(evTickets || 0),
      description: evDescription,
    };
    try {
      const res = await fetch(`${API_BASE}/events`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      setCreateResult(JSON.stringify(data, null, 2));
      await loadEvents();
    } catch (e) {
      setCreateResult(String(e));
    }
  }

  async function buyTicket(eventId) {
    if (!token) {
      alert('Please paste your token first.');
      return;
    }
    try {
      const res = await fetch(`${API_BASE}/events/${eventId}/tickets`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });
      const data = await res.json();
      alert(`Ticket response:\n${JSON.stringify(data, null, 2)}`);
      await loadEvents();
    } catch (e) {
      alert(`Error: ${e}`);
    }
  }

  async function loadMyTickets() {
    if (!token) {
      setMyTickets('Please paste your token first.');
      return;
    }
    setMyTickets('Loading...');
    try {
      const res = await fetch(`${API_BASE}/my-tickets`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });
      const data = await res.json();
      setMyTickets(JSON.stringify(data, null, 2));
    } catch (e) {
      setMyTickets(String(e));
    }
  }

  return (
    <div style={{ fontFamily: 'system-ui, sans-serif', background: '#0f172a', minHeight: '100vh', color: '#e5e7eb', padding: '2rem' }}>
      <h1 style={{ color: '#f9fafb' }}>EventFlow – React Ticketing</h1>

      <div style={cardStyle}>
        <h2>1. JWT Token (lipit din terminal)</h2>
        <label style={labelStyle}>Access token (Bearer):</label>
        <textarea
          value={token}
          onChange={e => setToken(e.target.value)}
          rows={3}
          style={textareaStyle}
          placeholder="Lipește aici token-ul primit de la Keycloak..."
        />
        <button style={buttonStyle} onClick={handleSaveToken}>Save token</button>
        <span style={badgeStyle}>{tokenStatus}</span>
      </div>

      <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
        <div style={{ flex: '1 1 280px' }}>
          <div style={cardStyle}>
            <h2>2. Evenimente</h2>
            <button style={secondaryButtonStyle} onClick={loadEvents} disabled={loadingEvents}>
              {loadingEvents ? 'Loading...' : 'Refresh events'}
            </button>
            <div style={{ marginTop: '0.75rem' }}>
              {events.length === 0 && !loadingEvents && <p>No events yet.</p>}
              {events.map(ev => (
                <div key={ev.id} style={eventStyle}>
                  <div>
                    <strong>{ev.name}</strong>
                    <div style={metaStyle}>
                      {ev.location || ''} • {ev.starts_at || ''}
                      <br />
                      Tickets: {ev.tickets_sold} / {ev.total_tickets} (left {ev.remaining_tickets})
                    </div>
                  </div>
                  <button style={buttonStyle} onClick={() => buyTicket(ev.id)}>
                    Buy ticket
                  </button>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div style={{ flex: '1 1 280px' }}>
          <div style={cardStyle}>
            <h2>3. Creează eveniment (ADMIN / ORGANIZER)</h2>
            <label style={labelStyle}>Name</label>
            <input style={inputStyle} value={evName} onChange={e => setEvName(e.target.value)} />

            <label style={labelStyle}>Location</label>
            <input style={inputStyle} value={evLocation} onChange={e => setEvLocation(e.target.value)} />

            <label style={labelStyle}>Starts at (ISO 8601)</label>
            <input
              style={inputStyle}
              value={evStartsAt}
              onChange={e => setEvStartsAt(e.target.value)}
              placeholder="2025-12-31T20:00:00"
            />

            <label style={labelStyle}>Total tickets</label>
            <input
              style={inputStyle}
              type="number"
              min={1}
              value={evTickets}
              onChange={e => setEvTickets(e.target.value)}
            />

            <label style={labelStyle}>Description</label>
            <textarea
              style={textareaStyle}
              rows={2}
              value={evDescription}
              onChange={e => setEvDescription(e.target.value)}
            />

            <button style={buttonStyle} onClick={createEvent}>Create event</button>
            <pre style={preStyle}>{createResult}</pre>
          </div>

          <div style={cardStyle}>
            <h2>4. Biletele mele</h2>
            <button style={secondaryButtonStyle} onClick={loadMyTickets}>Load my tickets</button>
            <pre style={preStyle}>{myTickets}</pre>
          </div>
        </div>
      </div>
    </div>
  );
}

const cardStyle = {
  background: '#020617',
  borderRadius: '0.75rem',
  padding: '1.25rem 1.5rem',
  marginBottom: '1rem',
  border: '1px solid #1f2937',
  boxShadow: '0 10px 25px rgba(15,23,42,0.8)',
};

const labelStyle = {
  fontSize: '0.875rem',
  color: '#9ca3af',
  display: 'block',
  marginBottom: '0.25rem',
};

const inputStyle = {
  width: '100%',
  padding: '0.5rem 0.75rem',
  borderRadius: '0.5rem',
  border: '1px solid #374151',
  background: '#020617',
  color: '#e5e7eb',
  fontSize: '0.875rem',
  marginBottom: '0.75rem',
};

const textareaStyle = {
  ...inputStyle,
  minHeight: '3rem',
};

const buttonStyle = {
  border: 'none',
  borderRadius: '999px',
  padding: '0.45rem 0.9rem',
  fontSize: '0.85rem',
  cursor: 'pointer',
  background: '#3b82f6',
  color: 'white',
};

const secondaryButtonStyle = {
  ...buttonStyle,
  background: '#111827',
  color: '#e5e7eb',
  border: '1px solid #374151',
};

const badgeStyle = {
  fontSize: '0.7rem',
  padding: '0.1rem 0.45rem',
  borderRadius: '999px',
  border: '1px solid #4b5563',
  color: '#9ca3af',
  marginLeft: '0.5rem',
};

const eventStyle = {
  display: 'flex',
  justifyContent: 'space-between',
  alignItems: 'center',
  gap: '0.75rem',
  marginBottom: '0.5rem',
};

const metaStyle = {
  fontSize: '0.8rem',
  color: '#9ca3af',
};

const preStyle = {
  fontSize: '0.8rem',
  background: '#020617',
  padding: '0.75rem',
  borderRadius: '0.5rem',
  overflowX: 'auto',
  border: '1px solid #1f2937',
  marginTop: '0.75rem',
};


