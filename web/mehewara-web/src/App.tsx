import { useState, useEffect } from 'react';
import { LoginPage } from './pages/auth/LoginPage';
import { ReportsPage } from './pages/reports/ReportsPage';
import { ProblemsPage } from './pages/problems';
import { LandingPage } from './pages/landing';
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

  const [viewMode, setViewMode] = useState<'landing' | 'reports' | 'problems' | 'profile' | 'login'>(() => {
    try {
      const saved = localStorage.getItem('mehewara_user');
      const savedToken = localStorage.getItem('mehewara_token');
      const user: User | null = saved ? JSON.parse(saved) : null;
      if (user && savedToken) {
        if (user.role === 'ADMIN') {
          return 'problems';
        }
        return 'reports';
      }
    } catch {
      // fallback to landing
    }
    return 'landing';
  });

  useEffect(() => {
    const handleStorageChange = () => {
      const savedUser = localStorage.getItem('mehewara_user');
      const savedToken = localStorage.getItem('mehewara_token');
      const user: User | null = savedUser ? JSON.parse(savedUser) : null;
      setCurrentUser(user);
      setToken(savedToken);
      if (user && savedToken) {
        if (user.role === 'ADMIN') {
          setViewMode('problems');
        }
      } else {
        setViewMode('landing');
      }
    };

    window.addEventListener('storage', handleStorageChange);
    return () => window.removeEventListener('storage', handleStorageChange);
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('mehewara_token');
    localStorage.removeItem('mehewara_user');
    setCurrentUser(null);
    setToken(null);
    setViewMode('landing');
  };

  const handleLoginSuccess = (user: User, accessToken: string) => {
    setCurrentUser(user);
    setToken(accessToken);
    if (user.role === 'ADMIN') {
      setViewMode('problems');
    } else {
      setViewMode('reports');
    }
  };

  // 1. Landing Page View (Public Entrance for All Visitors)
  if (viewMode === 'landing') {
    return (
      <LandingPage
        currentUser={currentUser}
        onLogout={handleLogout}
        onOpenProfile={() => setViewMode('profile')}
        onNavigateToLogin={() => setViewMode('login')}
        onNavigateToReports={() => {
          if (currentUser && token) {
            setViewMode('reports');
          } else {
            setViewMode('login');
          }
        }}
        onNavigateToProblems={() => setViewMode('problems')}
      />
    );
  }

  // 2. Login & Registration Portal
  if (viewMode === 'login' || (!currentUser || !token)) {
    return (
      <LoginPage
        onLoginSuccess={handleLoginSuccess}
        onNavigateToLanding={() => setViewMode('landing')}
        onNavigateToReports={() => setViewMode('reports')}
      />
    );
  }

  // 3. Authenticated Profile View -> Manage Profile & Photo
  if (viewMode === 'profile') {
    const returnDestination = currentUser.role === 'ADMIN' ? 'problems' : 'reports';
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
            onClick={() => setViewMode(returnDestination)}
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
            ← Back to {returnDestination === 'problems' ? 'Problems Dashboard' : 'Reports Portal'}
          </button>
          <span style={{ fontSize: '0.85rem', color: '#94a3b8' }}>
            Logged in as: <strong style={{ color: '#f8fafc' }}>{currentUser.name}</strong> ({currentUser.role})
          </span>
        </div>
        <LoginPage
          onNavigateToReports={() => setViewMode(returnDestination)}
          onLoginSuccess={handleLoginSuccess}
          onNavigateToLanding={() => setViewMode('landing')}
        />
      </div>
    );
  }

  // 4. Authenticated Problems Dashboard View (specifically redirected for ADMIN)
  if (viewMode === 'problems') {
    return (
      <ProblemsPage
        currentUser={currentUser}
        token={token}
        onLogout={handleLogout}
        onNavigateToReports={() => setViewMode('reports')}
        onNavigateToLanding={() => setViewMode('landing')}
        onOpenProfile={() => setViewMode('profile')}
      />
    );
  }

  // 5. Authenticated Reports View -> Resident Reports Portal
  return (
    <ReportsPage
      currentUser={currentUser}
      token={token}
      onLogout={handleLogout}
      onOpenProfile={() => setViewMode('profile')}
      onNavigateToProblems={() => setViewMode('problems')}
    />
  );
}

export default App;
