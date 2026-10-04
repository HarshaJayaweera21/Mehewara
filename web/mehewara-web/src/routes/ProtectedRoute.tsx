import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { ROUTES } from './paths';
import { getHomePathForRole, isCrewLeader } from '../types/access';

interface ProtectedRouteProps {
  children: React.ReactElement;
  allowedRoles?: string[];
  requireCrewLeader?: boolean;
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  children,
  allowedRoles,
  requireCrewLeader = false,
}) => {
  const { isAuthenticated, isLoading, currentUser } = useAuth();
  const location = useLocation();

  if (isLoading) {
    return (
      <div
        style={{
          minHeight: '100vh',
          display: 'grid',
          placeItems: 'center',
          background: '#091E19',
          color: '#6EE7B7',
          fontFamily: 'system-ui, sans-serif',
        }}
      >
        <p>Verifying municipal credentials…</p>
      </div>
    );
  }

  if (!isAuthenticated || !currentUser) {
    return <Navigate to={ROUTES.LOGIN} state={{ from: location }} replace />;
  }

  if (requireCrewLeader && !isCrewLeader(currentUser.role) && currentUser.role !== 'ADMIN') {
    return <Navigate to={getHomePathForRole(currentUser.role)} replace />;
  }

  if (allowedRoles && allowedRoles.length > 0 && !allowedRoles.includes(currentUser.role)) {
    return <Navigate to={getHomePathForRole(currentUser.role)} replace />;
  }

  return children;
};

export const PublicOnlyRoute: React.FC<{ children: React.ReactElement }> = ({ children }) => {
  const { isAuthenticated, isLoading, currentUser } = useAuth();
  const location = useLocation();

  if (isLoading) {
    return null;
  }

  if (isAuthenticated && currentUser) {
    const fromPath = (location.state as { from?: { pathname: string } })?.from?.pathname;
    const destination = fromPath && fromPath !== ROUTES.LOGIN && fromPath !== ROUTES.REGISTER
      ? fromPath
      : getHomePathForRole(currentUser.role);
    return <Navigate to={destination} replace />;
  }

  return children;
};
