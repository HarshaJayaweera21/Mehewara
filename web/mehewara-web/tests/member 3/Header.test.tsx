import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';
import { MemoryRouter } from 'react-router-dom';
import { Header } from '../../src/components/common/Header';
import { ROUTES } from '../../src/routes/paths';
import type { User } from '../../src/types/auth';

const mockNavigate = vi.fn();
vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom');
  return {
    ...actual,
    useNavigate: () => mockNavigate,
  };
});

describe('Header component', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const residentUser: User = {
    id: 'res-1',
    name: 'Kasun Bandara',
    firstName: 'Kasun',
    lastName: 'Bandara',
    email: 'kasun@example.com',
    role: 'RESIDENT',
  };

  const coordinatorUser: User = {
    id: 'coord-1',
    name: 'Municipal Coordinator',
    firstName: 'Municipal',
    lastName: 'Coordinator',
    email: 'coord@mehewara.gov.lk',
    role: 'ADMIN',
  };

  it('renders Reports button next to header-profile-wrap for resident on /profile page', () => {
    render(
      <MemoryRouter initialEntries={[ROUTES.PROFILE]}>
        <Header currentUser={residentUser} roleBadgeText="Resident" />
      </MemoryRouter>
    );

    const reportsBtn = screen.getByRole('button', { name: /Reports/i });
    expect(reportsBtn).toBeInTheDocument();
    expect(reportsBtn).toHaveClass('header-reports-btn');

    const profileTrigger = screen.getByTitle('User Account Menu');
    expect(profileTrigger).toBeInTheDocument();

    // Verify reports button is placed next to profile trigger inside header-right
    const headerRight = reportsBtn.parentElement;
    expect(headerRight).toHaveClass('header-right');
    expect(headerRight?.contains(profileTrigger)).toBe(true);
  });

  it('navigates to /reports when resident clicks the Reports button on /profile', () => {
    render(
      <MemoryRouter initialEntries={[ROUTES.PROFILE]}>
        <Header currentUser={residentUser} roleBadgeText="Resident" />
      </MemoryRouter>
    );

    const reportsBtn = screen.getByRole('button', { name: /Reports/i });
    fireEvent.click(reportsBtn);

    expect(mockNavigate).toHaveBeenCalledWith(ROUTES.REPORTS);
  });

  it('calls onNavigateToReports when provided on Reports button click', () => {
    const handleNavigateToReports = vi.fn();
    render(
      <MemoryRouter initialEntries={[ROUTES.PROFILE]}>
        <Header
          currentUser={residentUser}
          roleBadgeText="Resident"
          onNavigateToReports={handleNavigateToReports}
        />
      </MemoryRouter>
    );

    const reportsBtn = screen.getByRole('button', { name: /Reports/i });
    fireEvent.click(reportsBtn);

    expect(handleNavigateToReports).toHaveBeenCalledTimes(1);
    expect(mockNavigate).not.toHaveBeenCalled();
  });

  it('does NOT render Reports button for resident when on /reports page', () => {
    render(
      <MemoryRouter initialEntries={[ROUTES.REPORTS]}>
        <Header currentUser={residentUser} roleBadgeText="Resident" />
      </MemoryRouter>
    );

    expect(screen.queryByRole('button', { name: /Reports/i })).not.toBeInTheDocument();
    expect(screen.getByTitle('User Account Menu')).toBeInTheDocument();
  });

  it('does NOT render Reports button for coordinator on /profile page', () => {
    render(
      <MemoryRouter initialEntries={[ROUTES.PROFILE]}>
        <Header currentUser={coordinatorUser} roleBadgeText="Municipal Coordinator" />
      </MemoryRouter>
    );

    expect(screen.queryByRole('button', { name: /Reports/i })).not.toBeInTheDocument();
    expect(screen.getByTitle('User Account Menu')).toBeInTheDocument();
  });

  it('does NOT render Reports button for unauthenticated guest', () => {
    render(
      <MemoryRouter initialEntries={[ROUTES.HOME]}>
        <Header currentUser={null} />
      </MemoryRouter>
    );

    expect(screen.queryByRole('button', { name: /Reports/i })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Sign In \/ Sign Up/i })).toBeInTheDocument();
  });
});
