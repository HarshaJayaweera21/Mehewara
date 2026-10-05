import React from 'react';
import { Routes, Route, Navigate, useSearchParams, useNavigate } from 'react-router-dom';
import { ROUTES } from './paths';
import { ProtectedRoute, PublicOnlyRoute } from './ProtectedRoute';
import { useAuth } from '../context/AuthContext';
import { getHomePathForRole } from '../types/access';

// Pages
import { LandingPage } from '../pages/landing/LandingPage';
import { LoginPage } from '../pages/auth/LoginPage';
import { ProfilePage } from '../pages/auth/ProfilePage';
import { OperationsDashboardPage } from '../pages/operations/OperationsDashboardPage';
import { ReportsPage } from '../pages/reports/ReportsPage';
import { ProblemsPage } from '../pages/problems/ProblemsPage';
import { UncertainReportsPage } from '../pages/problems/UncertainReportsPage';
import { DispatchDashboardPage } from '../pages/dispatch/DispatchDashboardPage';
import { CrewListPage } from '../pages/crews/CrewListPage';
import { WorkOrdersPage } from '../pages/workOrders/WorkOrdersPage';
import { NotFoundPage } from '../pages/common/NotFoundPage';

function WorkOrdersRouteWrapper() {
  const { currentUser, token, logout } = useAuth();
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const workOrderId = searchParams.get('id') || undefined;

  if (!currentUser || !token) return null;

  return (
    <WorkOrdersPage
      user={currentUser}
      token={token}
      initialId={workOrderId}
      onLogout={logout}
      onProfile={() => navigate(ROUTES.PROFILE)}
      onCoordinator={() => navigate(ROUTES.PROBLEMS)}
      onNavigateToProblems={() => navigate(ROUTES.PROBLEMS)}
      onNavigateToDispatch={() => navigate(ROUTES.DISPATCH)}
      onNavigateToCrews={() => navigate(ROUTES.CREWS)}
    />
  );
}

export const AppRoutes: React.FC = () => {
  const { currentUser, token, logout, login, sessionMessage } = useAuth();
  const navigate = useNavigate();

  return (
    <Routes>
      {/* 1. Public Landing Page / Redirect to role workspace if authenticated */}
      <Route
        path={ROUTES.HOME}
        element={
          currentUser && token ? (
            <Navigate to={getHomePathForRole(currentUser.role)} replace />
          ) : (
            <LandingPage
              currentUser={currentUser}
              onLogout={logout}
              onOpenProfile={() => navigate(ROUTES.PROFILE)}
              onNavigateToLogin={() => navigate(ROUTES.LOGIN)}
              onNavigateToReports={() => {
                if (currentUser && token) {
                  navigate(getHomePathForRole(currentUser.role));
                } else {
                  navigate(ROUTES.LOGIN);
                }
              }}
              onNavigateToProblems={() => {
                if (currentUser?.role === 'ADMIN') {
                  navigate(ROUTES.PROBLEMS);
                } else {
                  navigate(ROUTES.LOGIN);
                }
              }}
            />
          )
        }
      />

      {/* 2. Public Auth Routes */}
      <Route
        path={ROUTES.LOGIN}
        element={
          <PublicOnlyRoute>
            <>
              {sessionMessage && (
                <div
                  role="alert"
                  style={{
                    background: '#FEE2E2',
                    color: '#991B1B',
                    padding: '0.75rem',
                    textAlign: 'center',
                    fontWeight: 500,
                  }}
                >
                  {sessionMessage}
                </div>
              )}
              <LoginPage
                onLoginSuccess={(user, accessToken) => {
                  login(user, accessToken);
                  navigate(getHomePathForRole(user.role));
                }}
                onNavigateToLanding={() => navigate(ROUTES.HOME)}
                onNavigateToReports={() => navigate(ROUTES.REPORTS)}
              />
            </>
          </PublicOnlyRoute>
        }
      />

      <Route
        path={ROUTES.REGISTER}
        element={
          <PublicOnlyRoute>
            <LoginPage
              onLoginSuccess={(user, accessToken) => {
                login(user, accessToken);
                navigate(getHomePathForRole(user.role));
              }}
              onNavigateToLanding={() => navigate(ROUTES.HOME)}
              onNavigateToReports={() => navigate(ROUTES.REPORTS)}
            />
          </PublicOnlyRoute>
        }
      />

      {/* 3. Authenticated Profile View */}
      <Route
        path={ROUTES.PROFILE}
        element={
          <ProtectedRoute>
            <ProfilePage />
          </ProtectedRoute>
        }
      />

      {/* 4. Resident & Admin Reports Portal */}
      <Route
        path={ROUTES.REPORTS}
        element={
          <ProtectedRoute>
            <ReportsPage
              currentUser={currentUser!}
              token={token!}
              onLogout={logout}
              onOpenProfile={() => navigate(ROUTES.PROFILE)}
              onNavigateToProblems={() => navigate(ROUTES.PROBLEMS)}
            />
          </ProtectedRoute>
        }
      />

      {/* 5. Municipal Operations Dashboard (Admin Only) */}
      <Route
        path={ROUTES.OPERATIONS}
        element={
          <ProtectedRoute allowedRoles={['ADMIN']}>
            <OperationsDashboardPage
              currentUser={currentUser!}
              token={token!}
              onLogout={logout}
              onOpenProfile={() => navigate(ROUTES.PROFILE)}
              onNavigateToReports={() => navigate(ROUTES.REPORTS)}
              onNavigateToProblems={() => navigate(ROUTES.PROBLEMS)}
              onNavigateToUncertainReports={() => navigate(ROUTES.UNCERTAIN_REPORTS)}
              onNavigateToDispatch={() => navigate(ROUTES.DISPATCH)}
              onNavigateToCrews={() => navigate(ROUTES.CREWS)}
              onNavigateToWorkOrders={() => navigate(ROUTES.WORK_ORDERS)}
            />
          </ProtectedRoute>
        }
      />

      {/* 6. Municipal Problems Board (Admin Only) */}
      <Route
        path={ROUTES.PROBLEMS}
        element={
          <ProtectedRoute allowedRoles={['ADMIN']}>
            <ProblemsPage
              currentUser={currentUser!}
              token={token!}
              onLogout={logout}
              onOpenProfile={() => navigate(ROUTES.PROFILE)}
              onNavigateToLanding={() => navigate(ROUTES.HOME)}
              onNavigateToReports={() => navigate(ROUTES.REPORTS)}
              onNavigateToUncertainReports={() => navigate(ROUTES.UNCERTAIN_REPORTS)}
              onNavigateToDispatch={() => navigate(ROUTES.DISPATCH)}
              onNavigateToCrews={() => navigate(ROUTES.CREWS)}
              onNavigateToWorkOrders={() => navigate(ROUTES.WORK_ORDERS)}
            />
          </ProtectedRoute>
        }
      />

      {/* 7. Uncertain Reports Triage (Admin Only) */}
      <Route
        path={ROUTES.UNCERTAIN_REPORTS}
        element={
          <ProtectedRoute allowedRoles={['ADMIN']}>
            <UncertainReportsPage
              currentUser={currentUser!}
              token={token!}
              onLogout={logout}
              onOpenProfile={() => navigate(ROUTES.PROFILE)}
              onNavigateToProblems={() => navigate(ROUTES.PROBLEMS)}
              onNavigateToReports={() => navigate(ROUTES.REPORTS)}
            />
          </ProtectedRoute>
        }
      />
      {/* Alias for backward compatibility */}
      <Route
        path="/uncertain-reports"
        element={<Navigate to={ROUTES.UNCERTAIN_REPORTS} replace />}
      />

      {/* 8. Dispatch & Crew Allocation Review (Admin Only) */}
      <Route
        path={ROUTES.DISPATCH}
        element={
          <ProtectedRoute allowedRoles={['ADMIN']}>
            <DispatchDashboardPage
              currentUser={currentUser!}
              token={token!}
              onLogout={logout}
              onOpenProfile={() => navigate(ROUTES.PROFILE)}
              onNavigateToOperations={() => navigate(ROUTES.OPERATIONS)}
              onNavigateToReports={() => navigate(ROUTES.REPORTS)}
              onNavigateToProblems={() => navigate(ROUTES.PROBLEMS)}
              onNavigateToCrews={() => navigate(ROUTES.CREWS)}
              onOpenWorkOrder={(id) =>
                navigate(id ? `${ROUTES.WORK_ORDERS}?id=${id}` : ROUTES.WORK_ORDERS)
              }
            />
          </ProtectedRoute>
        }
      />

      {/* 9. Municipal Crews Management (Admin Only) */}
      <Route
        path={ROUTES.CREWS}
        element={
          <ProtectedRoute allowedRoles={['ADMIN']}>
            <CrewListPage
              currentUser={currentUser!}
              token={token!}
              onLogout={logout}
              onOpenProfile={() => navigate(ROUTES.PROFILE)}
              onNavigateToProblems={() => navigate(ROUTES.PROBLEMS)}
              onNavigateToDispatch={() => navigate(ROUTES.DISPATCH)}
              onNavigateToReports={() => navigate(ROUTES.REPORTS)}
              onNavigateToWorkOrders={(id) =>
                navigate(id ? `${ROUTES.WORK_ORDERS}?id=${id}` : ROUTES.WORK_ORDERS)
              }
            />
          </ProtectedRoute>
        }
      />

      {/* 10. Work Orders Management (Admin Only) */}
      <Route
        path={ROUTES.WORK_ORDERS}
        element={
          <ProtectedRoute allowedRoles={['ADMIN']}>
            <WorkOrdersRouteWrapper />
          </ProtectedRoute>
        }
      />

      {/* 11. My Jobs (Crew Leaders) */}
      <Route
        path={ROUTES.MY_JOBS}
        element={
          <ProtectedRoute requireCrewLeader>
            <WorkOrdersRouteWrapper />
          </ProtectedRoute>
        }
      />

      {/* 12. Catch-All 404 Route */}
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
};
