import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
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

vi.mock('../../src/services/api', async () => {
  const actual = await vi.importActual('../../src/services/api');
  return {
    ...actual,
    getCurrentUser: vi.fn(async () => null),
    updateUserProfile: vi.fn(async (_token, data) => ({
      id: 'a0000000-0000-0000-0000-000000000002',
      name: `${data.firstName} ${data.lastName}`,
      firstName: data.firstName,
      lastName: data.lastName,
      phoneNumber: data.phoneNumber,
      email: 'resident@example.com',
      role: 'RESIDENT',
      profileImageUrl: null,
    })),
    uploadProfilePhoto: vi.fn(async () => ({
      id: 'a0000000-0000-0000-0000-000000000002',
      name: 'Kamal Perera',
      firstName: 'Kamal',
      lastName: 'Perera',
      email: 'resident@example.com',
      role: 'RESIDENT',
      phoneNumber: '+94 77 123 4567',
      profileImageUrl: 'https://example.com/photo.jpg',
    })),
    removeProfilePhoto: vi.fn(async () => ({
      id: 'a0000000-0000-0000-0000-000000000002',
      name: 'Kamal Perera',
      firstName: 'Kamal',
      lastName: 'Perera',
      email: 'resident@example.com',
      role: 'RESIDENT',
      phoneNumber: '+94 77 123 4567',
      profileImageUrl: null,
    })),
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

const mockResidentUser: User = {
  id: 'a0000000-0000-0000-0000-000000000002',
  name: 'Kamal Perera',
  firstName: 'Kamal',
  lastName: 'Perera',
  email: 'resident@example.com',
  phoneNumber: '+94 77 123 4567',
  role: 'RESIDENT',
  profileImageUrl: null,
};

describe('ProfilePage Component', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('Coordinator Profile (Read-Only Mode)', () => {
    it('renders coordinator profile details, municipal authority data, and read-only notice', () => {
      render(
        <AuthProvider>
          <MemoryRouter>
            <ProfilePage
              currentUser={mockCoordinatorUser}
              token="test-token"
              onNavigateBack={vi.fn()}
            />
          </MemoryRouter>
        </AuthProvider>
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
      expect(screen.getByText(/Municipal Council Authority/i)).toBeInTheDocument();
      expect(screen.getByText(/Colombo Municipal Council \(CMC\)/i)).toBeInTheDocument();
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
      expect(screen.queryByRole('button', { name: /Save Profile Changes/i })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: /Edit Profile/i })).not.toBeInTheDocument();
      expect(screen.queryByRole('textbox')).not.toBeInTheDocument();
    });

    it('triggers back navigation callback when clicking Back button', () => {
      const onNavigateBack = vi.fn();

      render(
        <AuthProvider>
          <MemoryRouter>
            <ProfilePage
              currentUser={mockCoordinatorUser}
              token="test-token"
              onNavigateBack={onNavigateBack}
            />
          </MemoryRouter>
        </AuthProvider>
      );

      const backButton = screen.getByRole('button', { name: /Return from profile/i });
      fireEvent.click(backButton);
      expect(onNavigateBack).toHaveBeenCalledTimes(1);
    });
  });

  describe('Resident Profile (Self-Service Editable Mode)', () => {
    it('renders resident details, civic services, and allows editing contact details', async () => {
      render(
        <AuthProvider>
          <MemoryRouter>
            <ProfilePage
              currentUser={mockResidentUser}
              token="test-token"
              onNavigateBack={vi.fn()}
            />
          </MemoryRouter>
        </AuthProvider>
      );

      // Hero banner
      expect(screen.getByRole('heading', { name: /Citizen Profile & Municipal Account/i })).toBeInTheDocument();
      expect(screen.getByText(/RESIDENT PROFILE/i)).toBeInTheDocument();

      // Citizen Identity details in read mode
      expect(screen.getAllByText('Kamal Perera').length).toBeGreaterThan(0);
      expect(screen.getAllByText('resident@example.com').length).toBeGreaterThan(0);
      expect(screen.getByText('+94 77 123 4567')).toBeInTheDocument();
      expect(screen.getByText('a0000000-0000-0000-0000-000000000002')).toBeInTheDocument();
      expect(screen.getByText(/Verified Municipal Resident/i)).toBeInTheDocument();

      // Municipal Authority details
      expect(screen.getByText(/Municipal Council Authority/i)).toBeInTheDocument();
      expect(screen.getByText(/Colombo Municipal Council \(CMC\)/i)).toBeInTheDocument();

      // Click Edit Profile button
      const editButton = screen.getByRole('button', { name: /Edit Profile/i });
      expect(editButton).toBeInTheDocument();
      fireEvent.click(editButton);

      // Verify form fields are shown
      const firstNameInput = screen.getByLabelText(/First Name/i) as HTMLInputElement;
      const lastNameInput = screen.getByLabelText(/Last Name/i) as HTMLInputElement;
      const phoneInput = screen.getByLabelText(/Contact Phone Number/i) as HTMLInputElement;

      expect(firstNameInput.value).toBe('Kamal');
      expect(lastNameInput.value).toBe('Perera');
      expect(phoneInput.value).toBe('+94 77 123 4567');

      // Change input values and submit
      fireEvent.change(firstNameInput, { target: { value: 'Kasun' } });
      fireEvent.change(lastNameInput, { target: { value: 'Silva' } });
      fireEvent.change(phoneInput, { target: { value: '+94 71 999 8888' } });

      const saveButton = screen.getByRole('button', { name: /Save Profile Changes/i });
      fireEvent.click(saveButton);

      // Expect success banner and updated values
      await waitFor(() => {
        expect(
          screen.getByText(/Your citizen profile details have been successfully updated/i)
        ).toBeInTheDocument();
      });
    });

    it('triggers back navigation to resident reports when clicking Back button', () => {
      const onNavigateBack = vi.fn();

      render(
        <AuthProvider>
          <MemoryRouter>
            <ProfilePage
              currentUser={mockResidentUser}
              token="test-token"
              onNavigateBack={onNavigateBack}
            />
          </MemoryRouter>
        </AuthProvider>
      );

      const backButton = screen.getByRole('button', { name: /Return from profile/i });
      fireEvent.click(backButton);
      expect(onNavigateBack).toHaveBeenCalledTimes(1);
    });
  });
});
