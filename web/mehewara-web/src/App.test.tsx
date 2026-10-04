import { beforeEach, afterEach, expect, it, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import App from './App';
import { crewRoles } from './types/access';
vi.mock('./pages/auth/LoginPage', () => ({ LoginPage: ({ onNavigateToReports }: { onNavigateToReports: () => void }) => <button onClick={onNavigateToReports}>Return from profile</button> }));
vi.mock('./pages/reports/ReportsPage', () => ({ ReportsPage: () => <div>Resident portal</div> }));
vi.mock('./pages/problems', () => ({ ProblemsPage: () => <div>Coordinator dashboard</div> }));
vi.mock('./pages/problems/UncertainReportsPage', () => ({ UncertainReportsPage: () => null }));
vi.mock('./pages/dispatch', () => ({ DispatchDashboardPage: () => null }));
vi.mock('./pages/crews', () => ({ CrewListPage: () => null }));
vi.mock('./pages/landing', () => ({ LandingPage: () => null }));
beforeEach(() => localStorage.clear());
afterEach(() => vi.unstubAllGlobals());
for (const role of crewRoles) {
  it(`${role} restores into My Jobs and returns there from profile`, async () => {
    const user = { id: 'leader', name: 'Leader', role, email: 'crew@example.com' };
    const token = `header.${btoa(JSON.stringify({ exp: Math.floor(Date.now() / 1000) + 3600 }))}.signature`;
    localStorage.setItem('mehewara_user', JSON.stringify(user)); localStorage.setItem('mehewara_token', token);
    vi.stubGlobal('fetch', vi.fn(async (url: string) => new Response(
      JSON.stringify(url.endsWith('/Auth/me') ? user : { items: [], totalItems: 0, totalPages: 0, page: 1, pageSize: 20 }),
      { headers: { 'Content-Type': 'application/json' } },
    )));
    render(<App />);
    expect(await screen.findByRole('heading', { name: 'My Jobs' })).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'My profile' }));
    fireEvent.click(screen.getByRole('button', { name: 'Return from profile' }));
    expect(await screen.findByRole('heading', { name: 'My Jobs' })).toBeInTheDocument();
    expect(screen.queryByText('Resident portal')).not.toBeInTheDocument();
  });
}
