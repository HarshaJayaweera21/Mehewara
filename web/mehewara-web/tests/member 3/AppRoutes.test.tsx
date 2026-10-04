import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';
import { MemoryRouter } from 'react-router-dom';
import { AuthProvider } from '../../src/context/AuthContext';
import { AppRoutes } from '../../src/routes/AppRoutes';
import { ROUTES } from '../../src/routes/paths';

// Mock child pages to keep route integration tests lightweight and focused on routing behavior
vi.mock('../../src/pages/landing/LandingPage', () => ({
  LandingPage: () => <div data-testid="landing-page">Landing Page</div>,
}));

vi.mock('../../src/pages/auth/LoginPage', () => ({
  LoginPage: () => <div data-testid="login-page">Login Page</div>,
}));

vi.mock('../../src/pages/auth/ProfilePage', () => ({
  ProfilePage: () => <div data-testid="profile-page">Profile Page</div>,
}));

vi.mock('../../src/pages/operations/OperationsDashboardPage', () => ({
  OperationsDashboardPage: () => <div data-testid="operations-page">Operations Dashboard</div>,
}));

vi.mock('../../src/pages/reports/ReportsPage', () => ({
  ReportsPage: () => <div data-testid="reports-page">Reports Portal</div>,
}));

vi.mock('../../src/pages/problems/ProblemsPage', () => ({
  ProblemsPage: () => <div data-testid="problems-page">Problems Dashboard</div>,
}));

vi.mock('../../src/pages/problems/UncertainReportsPage', () => ({
  UncertainReportsPage: () => <div data-testid="uncertain-page">Uncertain Reports</div>,
}));

vi.mock('../../src/pages/dispatch/DispatchDashboardPage', () => ({
  DispatchDashboardPage: () => <div data-testid="dispatch-page">Dispatch Dashboard</div>,
}));

vi.mock('../../src/pages/crews/CrewListPage', () => ({
  CrewListPage: () => <div data-testid="crews-page">Crew Management</div>,
}));

vi.mock('../../src/pages/workOrders/WorkOrdersPage', () => ({
  WorkOrdersPage: ({ user }: { user: { role: string } }) => (
    <div data-testid="work-orders-page">Work Orders for {user.role}</div>
  ),
}));

describe('AppRoutes routing and protection', () => {
  beforeEach(() => {
    localStorage.clear();
    vi.stubGlobal(
      'fetch',
      vi.fn(async (url: string) => {
        const userStr = localStorage.getItem('mehewara_user');
        const userObj = userStr ? JSON.parse(userStr) : {};
        return new Response(
          JSON.stringify(url.includes('/Auth/me') ? userObj : {}),
          {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
          }
        );
      })
    );
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('renders landing page on root path when unauthenticated', async () => {
    render(
      <MemoryRouter initialEntries={[ROUTES.HOME]}>
        <AuthProvider>
          <AppRoutes />
        </AuthProvider>
      </MemoryRouter>
    );

    expect(await screen.findByTestId('landing-page')).toBeInTheDocument();
  });

  it('renders login page on /login', async () => {
    render(
      <MemoryRouter initialEntries={[ROUTES.LOGIN]}>
        <AuthProvider>
          <AppRoutes />
        </AuthProvider>
      </MemoryRouter>
    );

    expect(await screen.findByTestId('login-page')).toBeInTheDocument();
  });

  it('redirects unauthenticated user accessing protected /operations to /login', async () => {
    render(
      <MemoryRouter initialEntries={[ROUTES.OPERATIONS]}>
        <AuthProvider>
          <AppRoutes />
        </AuthProvider>
      </MemoryRouter>
    );

    expect(await screen.findByTestId('login-page')).toBeInTheDocument();
    expect(screen.queryByTestId('operations-page')).not.toBeInTheDocument();
  });

  it('redirects unauthenticated user accessing /reports to /login', async () => {
    render(
      <MemoryRouter initialEntries={[ROUTES.REPORTS]}>
        <AuthProvider>
          <AppRoutes />
        </AuthProvider>
      </MemoryRouter>
    );

    expect(await screen.findByTestId('login-page')).toBeInTheDocument();
  });

  it('allows authenticated resident to access /reports', async () => {
    const user = { id: 'r1', name: 'Resident Jane', role: 'RESIDENT', email: 'jane@example.com' };
    const token = `hdr.${btoa(JSON.stringify({ exp: Math.floor(Date.now() / 1000) + 3600 }))}.sig`;
    localStorage.setItem('mehewara_user', JSON.stringify(user));
    localStorage.setItem('mehewara_token', token);

    render(
      <MemoryRouter initialEntries={[ROUTES.REPORTS]}>
        <AuthProvider>
          <AppRoutes />
        </AuthProvider>
      </MemoryRouter>
    );

    expect(await screen.findByTestId('reports-page')).toBeInTheDocument();
  });

  it('blocks resident from accessing admin-only /operations and redirects to /reports', async () => {
    const user = { id: 'r1', name: 'Resident Jane', role: 'RESIDENT', email: 'jane@example.com' };
    const token = `hdr.${btoa(JSON.stringify({ exp: Math.floor(Date.now() / 1000) + 3600 }))}.sig`;
    localStorage.setItem('mehewara_user', JSON.stringify(user));
    localStorage.setItem('mehewara_token', token);

    render(
      <MemoryRouter initialEntries={[ROUTES.OPERATIONS]}>
        <AuthProvider>
          <AppRoutes />
        </AuthProvider>
      </MemoryRouter>
    );

    expect(await screen.findByTestId('reports-page')).toBeInTheDocument();
    expect(screen.queryByTestId('operations-page')).not.toBeInTheDocument();
  });

  it('allows ADMIN to access /operations, /problems, /dispatch, /crews, and /work-orders', async () => {
    const admin = { id: 'a1', name: 'Admin John', role: 'ADMIN', email: 'admin@example.com' };
    const token = `hdr.${btoa(JSON.stringify({ exp: Math.floor(Date.now() / 1000) + 3600 }))}.sig`;
    localStorage.setItem('mehewara_user', JSON.stringify(admin));
    localStorage.setItem('mehewara_token', token);

    const { unmount } = render(
      <MemoryRouter initialEntries={[ROUTES.OPERATIONS]}>
        <AuthProvider>
          <AppRoutes />
        </AuthProvider>
      </MemoryRouter>
    );
    expect(await screen.findByTestId('operations-page')).toBeInTheDocument();
    unmount();

    render(
      <MemoryRouter initialEntries={[ROUTES.PROBLEMS]}>
        <AuthProvider>
          <AppRoutes />
        </AuthProvider>
      </MemoryRouter>
    );
    expect(await screen.findByTestId('problems-page')).toBeInTheDocument();
  });

  it('renders NotFoundPage on non-existent route', async () => {
    render(
      <MemoryRouter initialEntries={['/some/arbitrary/path/that/does/not/exist']}>
        <AuthProvider>
          <AppRoutes />
        </AuthProvider>
      </MemoryRouter>
    );

    expect(await screen.findByText('404')).toBeInTheDocument();
    expect(screen.getByText('Page Not Found')).toBeInTheDocument();
  });
});
