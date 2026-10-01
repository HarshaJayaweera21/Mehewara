import { useState, useEffect } from 'react';
import { LoginPage } from './pages/auth/LoginPage';
import { ReportsPage } from './pages/reports/ReportsPage';
import { ProblemsPage } from './pages/problems';
import { UncertainReportsPage } from './pages/problems/UncertainReportsPage';
import { DispatchDashboardPage } from './pages/dispatch';
import { CrewListPage } from './pages/crews';
import { LandingPage } from './pages/landing';
import type { User } from './types/auth';
import { WorkOrdersPage } from './pages/workOrders/WorkOrdersPage';
import { OperationsDashboardPage } from './pages/operations/OperationsDashboardPage';
import { homeView, isCrewLeader } from './types/access';
import { request, ApiRequestError } from './services/api';

function isTokenExpired(token: string | null): boolean {
  if (!token) return true;
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return true;
    const payload = JSON.parse(atob(parts[1]));
    if (!payload.exp) return false;
    return Date.now() >= payload.exp * 1000;
  } catch {
    return true;
  }
}

function App() {
  const [token, setToken] = useState<string | null>(() => {
    const savedToken = localStorage.getItem('mehewara_token');
    if (isTokenExpired(savedToken)) {
      localStorage.removeItem('mehewara_token');
      localStorage.removeItem('mehewara_user');
      return null;
    }
    return savedToken;
  });

  const [currentUser, setCurrentUser] = useState<User | null>(() => {
    const savedToken = localStorage.getItem('mehewara_token');
    if (isTokenExpired(savedToken)) {
      return null;
    }
    try {
      const saved = localStorage.getItem('mehewara_user');
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });

  const [workOrderId, setWorkOrderId] = useState<string>();
  const [sessionMessage, setSessionMessage] = useState('');
  const [viewMode, setViewMode] = useState<
    'landing' | 'operations' | 'reports' | 'problems' | 'uncertain-reports' | 'dispatch' | 'crews' | 'profile' | 'login' | 'work-orders' | 'my-jobs'
  >(() => {
    try {
      const savedToken = localStorage.getItem('mehewara_token');
      if (isTokenExpired(savedToken)) {
        return 'landing';
      }
      const saved = localStorage.getItem('mehewara_user');
      const user: User | null = saved ? JSON.parse(saved) : null;
      if (user && savedToken) {
        return homeView(user.role);
      }
    } catch {
      // fallback to landing
    }
    return 'landing';
  });

  useEffect(() => {
    const handleStorageChange = () => {
      const savedToken = localStorage.getItem('mehewara_token');
      if (isTokenExpired(savedToken)) {
        localStorage.removeItem('mehewara_token');
        localStorage.removeItem('mehewara_user');
        setCurrentUser(null);
        setToken(null);
        setViewMode('landing');
        return;
      }
      const savedUser = localStorage.getItem('mehewara_user');
      const user: User | null = savedUser ? JSON.parse(savedUser) : null;
      setCurrentUser(user);
      setToken(savedToken);
      if (user && savedToken) {
        setViewMode(homeView(user.role));
      } else {
        setViewMode('landing');
      }
    };

    const handleUnauthorized = () => {
      setCurrentUser(null);
      setToken(null);
      setViewMode('login');
    };

    window.addEventListener('storage', handleStorageChange);
    window.addEventListener('auth:unauthorized', handleUnauthorized);
    return () => {
      window.removeEventListener('storage', handleStorageChange);
      window.removeEventListener('auth:unauthorized', handleUnauthorized);
    };
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
    setSessionMessage('');
    setViewMode(homeView(user.role));
  };

  useEffect(() => {
    const expire = () => {
      localStorage.removeItem('mehewara_token'); localStorage.removeItem('mehewara_user');
      setCurrentUser(null); setToken(null); setViewMode('login');
      setSessionMessage('Your session expired. Please sign in again.');
    };
    window.addEventListener('mehewara-session-expired', expire);
    return () => window.removeEventListener('mehewara-session-expired', expire);
  }, []);

  useEffect(() => {
    if (!token) return;
    let active = true;
    request<User>('/Auth/me', token).then(user => {
      if (active) { setCurrentUser(user); localStorage.setItem('mehewara_user', JSON.stringify(user)); }
    }).catch(error => {
      if (active && !(error instanceof ApiRequestError && error.status === 401))
        setSessionMessage('Unable to verify your session. Check your connection and refresh.');
    });
    return () => { active = false; };
  }, [token]);

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
            setViewMode(homeView(currentUser.role));
          } else {
            setViewMode('login');
          }
        }}
        onNavigateToProblems={() => {
          if (currentUser && token && !isTokenExpired(token)) {
            setViewMode('problems');
          } else {
            setViewMode('login');
          }
        }}
      />
    );
  }

  // 2. Login & Registration Portal
  if (viewMode === 'login' || (!currentUser || !token)) {
    return (
      <> {sessionMessage && <p role="alert">{sessionMessage}</p>}<LoginPage
        onLoginSuccess={handleLoginSuccess}
        onNavigateToLanding={() => setViewMode('landing')}
        onNavigateToReports={() => setViewMode('reports')}
      /></>
    );
  }

  // 3. Authenticated Profile View -> Manage Profile & Photo
  if (viewMode === 'profile') {
    const returnDestination = homeView(currentUser.role);
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
            ← Back to {returnDestination === 'operations' ? 'Operations' : returnDestination === 'my-jobs' ? 'My Jobs' : 'Reports Portal'}
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

  if (isCrewLeader(currentUser.role)) {
    return <WorkOrdersPage user={currentUser} token={token} onLogout={handleLogout} onProfile={() => setViewMode('profile')} onCoordinator={() => setViewMode('my-jobs')} />;
  }
  if (currentUser.role === 'ADMIN' && viewMode === 'work-orders') {
    return (
      <WorkOrdersPage
        user={currentUser}
        token={token}
        initialId={workOrderId}
        onLogout={handleLogout}
        onProfile={() => setViewMode('profile')}
        onCoordinator={() => setViewMode('problems')}
        onNavigateToProblems={() => setViewMode('problems')}
        onNavigateToDispatch={() => setViewMode('dispatch')}
        onNavigateToCrews={() => setViewMode('crews')}
      />
    );
  }
  if (currentUser.role !== 'ADMIN') {
    return <ReportsPage currentUser={currentUser} token={token} onLogout={handleLogout} onOpenProfile={() => setViewMode('profile')} />;
  }

  if (viewMode === 'operations') {
    return <OperationsDashboardPage
      currentUser={currentUser}
      token={token}
      onLogout={handleLogout}
      onOpenProfile={() => setViewMode('profile')}
      onNavigateToReports={() => setViewMode('reports')}
      onNavigateToProblems={() => setViewMode('problems')}
      onNavigateToUncertainReports={() => setViewMode('uncertain-reports')}
      onNavigateToDispatch={() => setViewMode('dispatch')}
      onNavigateToCrews={() => setViewMode('crews')}
      onNavigateToWorkOrders={() => { setWorkOrderId(undefined); setViewMode('work-orders'); }}
    />;
  }

  // 4. Authenticated Problems Dashboard View
  if (viewMode === 'problems') {
    return (
      <ProblemsPage
        currentUser={currentUser}
        token={token}
        onLogout={handleLogout}
        onNavigateToReports={() => setViewMode('reports')}
        onNavigateToLanding={() => setViewMode('landing')}
        onOpenProfile={() => setViewMode('profile')}
        onNavigateToUncertainReports={() => setViewMode('uncertain-reports')}
        onNavigateToWorkOrders={() => { setWorkOrderId(undefined); setViewMode('work-orders'); }}
        onNavigateToDispatch={() => setViewMode('dispatch')}
        onNavigateToCrews={() => setViewMode('crews')}
      />
    );
  }

  // 4b. Authenticated Uncertain Reports Triage View (Coordinator HITL Review)
  if (viewMode === 'uncertain-reports') {
    return (
      <UncertainReportsPage
        currentUser={currentUser}
        token={token}
        onNavigateToProblems={() => setViewMode('problems')}
        onNavigateToReports={() => setViewMode('reports')}
        onLogout={handleLogout}
        onOpenProfile={() => setViewMode('profile')}
      />
    );
  }

  // 4c. Authenticated Dispatch Queue View (Agent 3 Prioritization & Dispatch HITL)
  if (viewMode === 'dispatch') {
    return (
      <DispatchDashboardPage
        onOpenWorkOrder={id => { setWorkOrderId(id || undefined); setViewMode('work-orders'); }}
        currentUser={currentUser}
        token={token}
        onLogout={handleLogout}
        onOpenProfile={() => setViewMode('profile')}
        onNavigateToProblems={() => setViewMode('problems')}
        onNavigateToCrews={() => setViewMode('crews')}
        onNavigateToReports={() => setViewMode('reports')}
      />
    );
  }

  // 4d. Authenticated Municipal Crews Management View
  if (viewMode === 'crews') {
    return (
      <CrewListPage
        currentUser={currentUser}
        token={token}
        onLogout={handleLogout}
        onOpenProfile={() => setViewMode('profile')}
        onNavigateToProblems={() => setViewMode('problems')}
        onNavigateToDispatch={() => setViewMode('dispatch')}
        onNavigateToReports={() => setViewMode('reports')}
        onNavigateToWorkOrders={() => { setWorkOrderId(undefined); setViewMode('work-orders'); }}
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
