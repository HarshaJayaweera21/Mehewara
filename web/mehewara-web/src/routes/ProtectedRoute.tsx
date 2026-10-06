import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { ROUTES } from './paths';
import { getHomePathForRole, isCrewLeader, isCoordinator, isResident } from '../types/access';

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

  if (requireCrewLeader && !isCrewLeader(currentUser.role) && !isCoordinator(currentUser.role)) {
    return <Navigate to={getHomePathForRole(currentUser.role)} replace />;
  }

  if (allowedRoles && allowedRoles.length > 0) {
    const userRole = currentUser.role?.toUpperCase();
    const hasRole = allowedRoles.some((r) => {
      const norm = r.toUpperCase();
      if (norm === 'ADMIN' || norm === 'COORDINATOR') {
        return userRole === 'ADMIN' || userRole === 'COORDINATOR';
      }
      return norm === userRole;
    });

    if (!hasRole) {
      return <Navigate to={getHomePathForRole(currentUser.role)} replace />;
    }
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
    const rawFromPath = (location.state as { from?: { pathname: string } })?.from?.pathname;
    const homePath = getHomePathForRole(currentUser.role);

    // If fromPath is login/register, root landing page, or root slash, default to role homePath
    const fromPath =
      rawFromPath &&
      rawFromPath !== ROUTES.LOGIN &&
      rawFromPath !== ROUTES.REGISTER &&
      rawFromPath !== ROUTES.HOME &&
      rawFromPath !== '/'
        ? rawFromPath
        : null;

    let destination = homePath;
    if (fromPath) {
      const isCoord = isCoordinator(currentUser.role);
      const isRes = isResident(currentUser.role);

      if (fromPath === ROUTES.PROFILE) {
        destination = ROUTES.PROFILE;
      } else if (
        isCoord &&
        (
          [
            ROUTES.OPERATIONS,
            ROUTES.PROBLEMS,
            ROUTES.UNCERTAIN_REPORTS,
            ROUTES.DISPATCH,
            ROUTES.CREWS,
            ROUTES.WORK_ORDERS,
          ] as readonly string[]
        ).includes(fromPath)
      ) {
        destination = fromPath;
      } else if (isRes && fromPath === ROUTES.REPORTS) {
        destination = ROUTES.REPORTS;
      }
    }

    return <Navigate to={destination} replace />;
  }

  return children;
};

