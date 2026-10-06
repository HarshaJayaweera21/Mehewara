import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor, fireEvent, act } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { getResidentReports } from '../../../src/services/reportApi';
import { loginWithCredentials } from '../../../src/services/api';
import { ReportsPage } from '../../../src/pages/reports/ReportsPage';
import * as reportApi from '../../../src/services/reportApi';

vi.mock('../../../src/components/common', async (importOriginal) => {
  const actual = await importOriginal<Record<string, unknown>>();
  return {
    ...actual,
    Header: () => <div data-testid="mock-header">Header</div>,
  };
});

describe('Report & Auth Error States Tests (Member 1)', () => {
  const originalFetch = globalThis.fetch;
  const resident = { id: 'user-1', name: 'Kamal Perera', email: 'kamal@example.com', role: 'RESIDENT' };

  beforeEach(() => {
    vi.restoreAllMocks();
    localStorage.clear();
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('handleResponse handles 401 Unauthorized from getResidentReports by clearing storage and dispatching events', async () => {
    localStorage.setItem('mehewara_token', 'expired-token');
    localStorage.setItem('mehewara_user', JSON.stringify(resident));

    let expiredEventFired = false;
    window.addEventListener('mehewara-session-expired', () => {
      expiredEventFired = true;
    });

    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      json: async () => ({ error: { message: 'Session expired. Please log in again.' } }),
    } as unknown as Response);

    await expect(getResidentReports('expired-token')).rejects.toThrow('Session expired. Please log in again.');

    expect(localStorage.getItem('mehewara_token')).toBeNull();
    expect(localStorage.getItem('mehewara_user')).toBeNull();
    expect(expiredEventFired).toBe(true);
  });

  it('handleResponse parses the backend error payload message on a failed login attempt', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 400,
      json: async () => ({ error: { message: 'Invalid email or password.' } }),
    } as unknown as Response);

    await expect(loginWithCredentials('resident@example.com', 'wrong-password')).rejects.toThrow(
      'Invalid email or password.'
    );
  });

  it('handleResponse falls back to a status error string when the response body is not JSON', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 500,
      json: async () => {
        throw new Error('Not JSON');
      },
    } as unknown as Response);

    await expect(getResidentReports('token')).rejects.toThrow('Request failed with status 500');
  });

  it('ReportsPage displays an error banner with the backend message when fetching reports fails', async () => {
    vi.spyOn(reportApi, 'getResidentReports').mockRejectedValue(
      new Error('Failed to fetch reports from backend.')
    );

    render(
      <MemoryRouter>
        <ReportsPage currentUser={resident as never} token="valid-token" />
      </MemoryRouter>
    );

    expect(await screen.findByText('Failed to fetch reports from backend.')).toBeInTheDocument();
  });

  it('ReportsPage retries fetching reports when the status filter is changed after an error', async () => {
    const getReportsSpy = vi
      .spyOn(reportApi, 'getResidentReports')
      .mockRejectedValueOnce(new Error('Failed to fetch reports from backend.'))
      .mockResolvedValueOnce({ items: [], totalItems: 0, page: 1, pageSize: 12, totalPages: 1 } as never);

    render(
      <MemoryRouter>
        <ReportsPage currentUser={resident as never} token="valid-token" />
      </MemoryRouter>
    );

    await screen.findByText('Failed to fetch reports from backend.');

    await act(async () => {
      fireEvent.click(screen.getByRole('button', { name: 'PENDING' }));
    });

    await waitFor(() => expect(getReportsSpy).toHaveBeenCalledTimes(2));
  });
});
