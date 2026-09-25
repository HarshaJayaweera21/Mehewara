import { useState, useEffect, useCallback } from 'react';
import { LoginPage } from './pages/auth/LoginPage';
import { ReportsPage } from './pages/reports/ReportsPage';
import type { User } from './types/auth';

function App() {
  const [currentUser, setCurrentUser] = useState<User | null>(() => {
    try {
      const saved = localStorage.getItem('mehewara_user');
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });

  const [token, setToken] = useState<string | null>(() => {
    return localStorage.getItem('mehewara_token');
  });

  const [viewMode, setViewMode] = useState<'reports' | 'profile'>('reports');

  useEffect(() => {
    const handleStorageChange = () => {
      const savedUser = localStorage.getItem('mehewara_user');
      const savedToken = localStorage.getItem('mehewara_token');
      setCurrentUser(savedUser ? JSON.parse(savedUser) : null);
      setToken(savedToken);
    };

    window.addEventListener('storage', handleStorageChange);
    return () => window.removeEventListener('storage', handleStorageChange);
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('mehewara_token');
    localStorage.removeItem('mehewara_user');
    setCurrentUser(null);
    setToken(null);
    setViewMode('reports');
  };

  const handleLoginSuccess = useCallback((user: User, accessToken: string) => {
    setCurrentUser(user);
    setToken(accessToken);
    setViewMode('reports');
  }, []);

  // 1. Not Authenticated -> Show Login & Sign-up Portal
  if (!currentUser || !token) {
    return <LoginPage onLoginSuccess={handleLoginSuccess} />;
  }

  // 2. Authenticated Profile View -> Manage Profile & Photo
  if (viewMode === 'profile') {
    return (
      <div style={{ minHeight: '100vh', background: '#0f172a' }}>
        <div
          style={{
            background: 'rgba(30, 41, 59, 0.9)',
            padding: '0.85rem 2rem',
            borderBottom: '1px solid #334155',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <button
            type="button"
            onClick={() => setViewMode('reports')}
            style={{
              background: '#0f172a',
              color: '#38bdf8',
              border: '1px solid #334155',
              borderRadius: '8px',
              padding: '0.45rem 1rem',
              cursor: 'pointer',
              fontWeight: 600,
              fontSize: '0.875rem',
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
            }}
          >
            ← Back to Reports Portal
          </button>
          <span style={{ fontSize: '0.85rem', color: '#94a3b8' }}>
            Logged in as: <strong style={{ color: '#f8fafc' }}>{currentUser.name}</strong> ({currentUser.role})
          </span>
        </div>
        <LoginPage
          onNavigateToReports={() => setViewMode('reports')}
          onLoginSuccess={handleLoginSuccess}
        />
      </div>
    );
  }

  // 3. Authenticated Main View -> Reports Portal (List, Add Report, Details)
  return (
    <ReportsPage
      currentUser={currentUser}
      token={token}
      onLogout={handleLogout}
      onOpenProfile={() => setViewMode('profile')}
    />
  );
}

export default App;
