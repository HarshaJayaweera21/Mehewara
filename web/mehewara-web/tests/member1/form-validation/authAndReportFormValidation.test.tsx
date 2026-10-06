import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';
import { MemoryRouter } from 'react-router-dom';
import { LoginPage } from '../../../src/pages/auth/LoginPage';
import { CreateReportModal } from '../../../src/components/reports/CreateReportModal';
import * as api from '../../../src/services/api';
import * as reportApi from '../../../src/services/reportApi';

vi.mock('../../../src/components/common/MapPicker', () => ({
  MapPicker: ({ onLocationSelect }: { onLocationSelect: (loc: { latitude: number; longitude: number; address: string }) => void }) => (
    <button
      type="button"
      data-testid="mock-map-picker"
      onClick={() => onLocationSelect({ latitude: 120, longitude: 79.86, address: 'Out of range test pin' })}
    >
      Simulate out-of-range map pin
    </button>
  ),
}));

describe('Auth & Report Form Validation Tests (Member 1)', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    localStorage.clear();
  });

  it('Sign In form marks email and password as required and blocks submission when they are empty', () => {
    render(
      <MemoryRouter initialEntries={['/login']}>
        <LoginPage />
      </MemoryRouter>
    );

    const loginSpy = vi.spyOn(api, 'loginWithCredentials');
    const emailInput = screen.getByLabelText('Email address') as HTMLInputElement;
    const passwordInput = screen.getByLabelText('Password') as HTMLInputElement;
    expect(emailInput.required).toBe(true);
    expect(passwordInput.required).toBe(true);

    fireEvent.click(screen.getByRole('button', { name: 'Sign in to Mehewara' }));

    expect(loginSpy).not.toHaveBeenCalled();
  });

  it('Sign In form submits trimmed credentials once both fields are filled', async () => {
    const loginSpy = vi.spyOn(api, 'loginWithCredentials').mockResolvedValue({
      accessToken: 'token-1',
      user: { id: 'user-1', name: 'Kamal', email: 'resident@example.com', role: 'RESIDENT' },
    } as never);

    render(
      <MemoryRouter initialEntries={['/login']}>
        <LoginPage />
      </MemoryRouter>
    );

    fireEvent.change(screen.getByLabelText('Email address'), { target: { value: 'resident@example.com' } });
    fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'Resident@123' } });
    await act(async () => {
      fireEvent.click(screen.getByRole('button', { name: 'Sign in to Mehewara' }));
    });

    await waitFor(() => expect(loginSpy).toHaveBeenCalledWith('resident@example.com', 'Resident@123'));
  });

  it('Sign Up form marks first name, last name, email and password as required and blocks empty submission', () => {
    const registerSpy = vi.spyOn(api, 'registerResident');

    render(
      <MemoryRouter initialEntries={['/register']}>
        <LoginPage />
      </MemoryRouter>
    );

    expect((screen.getByLabelText('First name') as HTMLInputElement).required).toBe(true);
    expect((screen.getByLabelText('Last name') as HTMLInputElement).required).toBe(true);
    expect((screen.getByLabelText('Email address') as HTMLInputElement).required).toBe(true);
    expect((screen.getByLabelText('Password') as HTMLInputElement).required).toBe(true);

    fireEvent.click(screen.getByRole('button', { name: 'Create resident account' }));

    expect(registerSpy).not.toHaveBeenCalled();
  });

  it('Sign Up form submits registration once first name, last name, email and password are provided', async () => {
    const registerSpy = vi.spyOn(api, 'registerResident').mockResolvedValue({
      accessToken: 'token-2',
      user: { id: 'user-2', name: 'Kasun Perera', email: 'kasun@example.com', role: 'RESIDENT' },
    } as never);

    render(
      <MemoryRouter initialEntries={['/register']}>
        <LoginPage />
      </MemoryRouter>
    );

    fireEvent.change(screen.getByLabelText('First name'), { target: { value: 'Kasun' } });
    fireEvent.change(screen.getByLabelText('Last name'), { target: { value: 'Perera' } });
    fireEvent.change(screen.getByLabelText('Email address'), { target: { value: 'kasun@example.com' } });
    fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'Secret@123' } });
    await act(async () => {
      fireEvent.click(screen.getByRole('button', { name: 'Create resident account' }));
    });

    await waitFor(() =>
      expect(registerSpy).toHaveBeenCalledWith({
        firstName: 'Kasun',
        lastName: 'Perera',
        email: 'kasun@example.com',
        password: 'Secret@123',
        phoneNumber: undefined,
      })
    );
  });

  it('Create Report Form rejects a description shorter than 10 characters', async () => {
    render(<CreateReportModal token="token" onClose={vi.fn()} onSuccess={vi.fn()} />);

    fireEvent.change(screen.getByLabelText(/Describe the Issue/), { target: { value: 'Too short' } });
    fireEvent.click(screen.getByRole('button', { name: 'Submit Report to Council' }));

    expect(await screen.findByText(/Description must be at least 10 characters long/)).toBeInTheDocument();
  });

  it('Create Report Form rejects an out-of-range latitude selected from the map before calling createReport', async () => {
    const createSpy = vi.spyOn(reportApi, 'createReport');

    render(<CreateReportModal token="token" onClose={vi.fn()} onSuccess={vi.fn()} />);

    fireEvent.click(screen.getByTestId('mock-map-picker'));
    fireEvent.change(screen.getByLabelText(/Describe the Issue/), {
      target: { value: 'Deep pothole causing damage to passing vehicles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Submit Report to Council' }));

    expect(await screen.findByText(/valid Latitude between -90 and 90/)).toBeInTheDocument();
    expect(createSpy).not.toHaveBeenCalled();
  });

  it('Create Report Form submits a valid report with the selected category and trimmed description', async () => {
    const createSpy = vi.spyOn(reportApi, 'createReport').mockResolvedValue({ id: 'rep-1' } as never);
    const onSuccess = vi.fn();

    render(<CreateReportModal token="token" onClose={vi.fn()} onSuccess={onSuccess} />);

    fireEvent.click(screen.getByRole('button', { name: /Waste Management/ }));
    fireEvent.change(screen.getByLabelText(/Describe the Issue/), {
      target: { value: '  Overflowing bin blocking the pavement for days  ' },
    });
    await act(async () => {
      fireEvent.click(screen.getByRole('button', { name: 'Submit Report to Council' }));
    });

    await waitFor(() => expect(onSuccess).toHaveBeenCalledWith({ id: 'rep-1' }));
    expect(createSpy).toHaveBeenCalledWith(
      'token',
      expect.objectContaining({ category: 'WASTE', description: 'Overflowing bin blocking the pavement for days' })
    );
  });
});
