import React from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { LoginPage } from './LoginPage';
import { getHomePathForRole } from '../../types/access';
import { ROUTES } from '../../routes/paths';

export const ProfilePage: React.FC = () => {
  const { currentUser, login } = useAuth();
  const navigate = useNavigate();

  if (!currentUser) return null;

  const returnPath = getHomePathForRole(currentUser.role);
  const destinationLabel =
    currentUser.role === 'ADMIN'
      ? 'Operations'
      : returnPath === ROUTES.MY_JOBS
      ? 'My Jobs'
      : 'Reports Portal';

  return (
    <div style={{ minHeight: '100vh', background: '#0f172a' }}>
      <header
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
          onClick={() => navigate(returnPath)}
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
          ← Back to {destinationLabel}
        </button>
        <span style={{ fontSize: '0.85rem', color: '#94a3b8' }}>
          Logged in as: <strong style={{ color: '#f8fafc' }}>{currentUser.name}</strong> ({currentUser.role})
        </span>
      </header>

      <LoginPage
        onNavigateToReports={() => navigate(returnPath)}
        onNavigateToLanding={() => navigate(ROUTES.HOME)}
        onLoginSuccess={(user, token) => {
          login(user, token);
          navigate(returnPath);
        }}
      />
    </div>
  );
};
