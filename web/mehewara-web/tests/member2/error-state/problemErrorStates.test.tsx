import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor, fireEvent, act } from '@testing-library/react';
import React from 'react';
import { getProblems, linkUncertainReport } from '../../../src/services/problemApi';
import { ProblemsPage } from '../../../src/pages/problems/ProblemsPage';
import * as problemApi from '../../../src/services/problemApi';

// Mock Header and other child components if needed
vi.mock('../../../src/components/common', () => ({
  Header: () => <div data-testid="mock-header">Header</div>,
}));

describe('Problem Error States Tests (Member 2)', () => {
  const originalFetch = globalThis.fetch;

  beforeEach(() => {
    vi.restoreAllMocks();
    localStorage.clear();
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('handleResponse handles 401 Unauthorized by clearing storage and dispatching event', async () => {
    localStorage.setItem('mehewara_token', 'expired-token');
    localStorage.setItem('mehewara_user', JSON.stringify({ id: 'user-1' }));

    let authEventFired = false;
    window.addEventListener('auth:unauthorized', () => {
      authEventFired = true;
    });

    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      json: async () => ({ error: { message: 'Token has expired' } }),
    } as unknown as Response);

    await expect(getProblems('expired-token')).rejects.toThrow('Token has expired');

    expect(localStorage.getItem('mehewara_token')).toBeNull();
    expect(localStorage.getItem('mehewara_user')).toBeNull();
    expect(authEventFired).toBe(true);
  });

  it('handleResponse parses backend error payload message on 400 Bad Request', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 400,
      json: async () => ({
        error: { message: 'Report is already linked to another problem' },
      }),
    } as unknown as Response);

    await expect(
      linkUncertainReport('token', {
        reportId: 'rep-1',
        problemId: 'prob-1',
      })
    ).rejects.toThrow('Report is already linked to another problem');
  });

  it('handleResponse falls back to status error string when response is not JSON', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 500,
      json: async () => {
        throw new Error('Not JSON');
      },
    } as unknown as Response);

    await expect(getProblems('token')).rejects.toThrow('Request failed with status 500');
  });

  it('ProblemsPage displays error surface with message and Try Again button on API failure', async () => {
    vi.spyOn(problemApi, 'getProblems').mockRejectedValue(
      new Error('Unable to connect to municipal database')
    );
    vi.spyOn(problemApi, 'getUncertainReports').mockResolvedValue([]);

    render(<ProblemsPage token="valid-token" />);

    // Expect loading state first or wait for error state
    await waitFor(() => {
      const alertSurface = screen.getByRole('alert');
      expect(alertSurface).toBeDefined();
    });

    expect(screen.getByText("We couldn't load problems")).toBeDefined();
    expect(screen.getByText('Unable to connect to municipal database')).toBeDefined();

    // Verify retry button exists and is clickable
    const retryBtn = screen.getByRole('button', { name: /try again/i });
    expect(retryBtn).toBeDefined();

    const initialCalls = vi.mocked(problemApi.getProblems).mock.calls.length;
    await act(async () => {
      fireEvent.click(retryBtn);
    });
    expect(vi.mocked(problemApi.getProblems).mock.calls.length).toBeGreaterThan(initialCalls);
  });
});
