import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';
import { MemoryRouter } from 'react-router-dom';
import { AuthProvider } from '../../src/context/AuthContext';
import { ProfilePage } from '../../src/pages/auth/ProfilePage';
import type { User } from '../../src/types/auth';

const mockNavigate = vi.fn();
vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom');
  return {
    ...actual,
    useNavigate: () => mockNavigate,
  };
});

const mockCoordinatorUser: User = {
  id: 'a0000000-0000-0000-0000-000000000001',
  name: 'Municipal Coordinator',
  firstName: 'Municipal',
  lastName: 'Coordinator',
  email: 'admin@mehewara.gov.lk',
  phoneNumber: '+94 11 234 5670',
  role: 'ADMIN',
  profileImageUrl: null,
};

describe('Coordinator ProfilePage Component', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders coordinator profile details, municipal authority data, and read-only notice', () => {
    render(
      <MemoryRouter>
        <ProfilePage
          currentUser={mockCoordinatorUser}
          token="test-token"
          onNavigateBack={vi.fn()}
        />
      </MemoryRouter>
    );

    // Hero banner and titles
    expect(screen.getByRole('heading', { name: /Municipal Coordinator Profile/i })).toBeInTheDocument();
    expect(screen.getByText(/OFFICIAL PERSONNEL DOSSIER/i)).toBeInTheDocument();

    // Officer credentials
    expect(screen.getAllByText('Municipal Coordinator').length).toBeGreaterThan(0);
    expect(screen.getAllByText('admin@mehewara.gov.lk').length).toBeGreaterThan(0);
    expect(screen.getByText('+94 11 234 5670')).toBeInTheDocument();
    expect(screen.getByText('a0000000-0000-0000-0000-000000000001')).toBeInTheDocument();
    expect(screen.getByText(/Lead Operations & Dispatch Coordinator/i)).toBeInTheDocument();

    // Read-only advisory notice
    expect(
      screen.getByText(/Centralized Municipal Registry — Read-Only Official Record/i)
    ).toBeInTheDocument();
    expect(
      screen.getByText(/Direct self-service modifications are restricted to safeguard chain-of-command integrity/i)
    ).toBeInTheDocument();

    // Municipal Council Authority information
    expect(screen.getByText(/Colombo Municipal Council Authority/i)).toBeInTheDocument();
    expect(screen.getByText(/Town Hall, F. R. Senanayake Mawatha, Colombo 07/i)).toBeInTheDocument();
    expect(screen.getByText(/47 Wards across 5 Electoral Districts/i)).toBeInTheDocument();
    expect(screen.getByText(/1919 \(Toll-Free 24\/7\)/i)).toBeInTheDocument();

    // Operational Scope
    expect(screen.getByText(/Coordinator Operational Scope & Powers/i)).toBeInTheDocument();
    expect(screen.getByText(/Municipal Defect Triage & Categorization/i)).toBeInTheDocument();
    expect(screen.getByText(/Crew Mobilization & Dispatch Assignment/i)).toBeInTheDocument();

    // Regional Depots
    expect(screen.getByText(/Regional Municipal Depots & Fleet Stations/i)).toBeInTheDocument();
    expect(screen.getByText(/Ward 07 \(Cinnamon Gardens\)/i)).toBeInTheDocument();
    expect(screen.getByText(/Ward 03 \(Kollupitiya\)/i)).toBeInTheDocument();

    // Read-only guarantee: no edit/save/update buttons or form inputs
    expect(screen.queryByRole('button', { name: /Save Profile/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Update Profile/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('textbox')).not.toBeInTheDocument();
  });

  it('triggers back navigation callback when clicking Back button', () => {
    const onNavigateBack = vi.fn();

    render(
      <MemoryRouter>
        <ProfilePage
          currentUser={mockCoordinatorUser}
          token="test-token"
          onNavigateBack={onNavigateBack}
        />
      </MemoryRouter>
    );

    const backButton = screen.getByRole('button', { name: /Return from profile/i });
    fireEvent.click(backButton);
    expect(onNavigateBack).toHaveBeenCalledTimes(1);
  });
});
