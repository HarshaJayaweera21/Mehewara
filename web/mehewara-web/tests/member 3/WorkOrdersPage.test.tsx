import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { WorkOrdersPage } from '../../src/pages/workOrders/WorkOrdersPage';
import type { WorkOrder } from '../../src/types/workOrders';
import { completeWorkOrder, startWorkOrder } from '../../src/services/workOrdersApi';
import { handleResponse } from '../../src/services/api';
import { approveRecommendation, editRecommendation } from '../../src/services/dispatchApi';

const job: WorkOrder = { id: 'job-1', problemId: 'problem-1', crewId: 'crew-1', recommendationId: null,
  crewName: 'Road Crew', problemTitle: 'Drain blockage', title: 'Clear main drain', instructions: 'Work safely.',
  priority: 'HIGH', status: 'ASSIGNED', latitude: 7.2, longitude: 80.6, address: 'Main Street',
  assignedAt: '2026-09-27T10:00:00Z', startedAt: null, completedAt: null, completionNotes: null,
  createdAt: '2026-09-27T10:00:00Z', updatedAt: '2026-09-27T10:00:00Z', history: [] };
const props = { user: { id: 'leader', name: 'Crew leader', email: 'crew@example.com', role: 'CREW_LEADER_ROAD' }, token: 'token', onLogout: vi.fn(), onProfile: vi.fn(), onCoordinator: vi.fn() };
const reply = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: { 'Content-Type': 'application/json' },
});
beforeEach(() => { localStorage.clear(); });
afterEach(() => vi.unstubAllGlobals());

describe('WorkOrder screens and contracts', () => {
  it('starts then completes a job with notes and renders its history', async () => {
    let current = { ...job };
    const fetcher = vi.fn(async (url: string, options?: RequestInit) => {
      if (url.endsWith('/start')) { expect(options?.body).toBeUndefined(); current = { ...current, status: 'IN_PROGRESS' }; }
      if (url.endsWith('/complete')) {
        expect(JSON.parse(options?.body as string)).toEqual({ completionNotes: 'Repaired' });
        current = { ...current, status: 'COMPLETED', completionNotes: 'Repaired', history: [{ id: 'event', action: 'WORK_ORDER_COMPLETED', actorUserId: 'leader', note: 'Repaired', createdAt: job.createdAt }] };
      }
      return reply(url.includes('?') ? { items: [current], totalItems: 1, totalPages: 1, page: 1, pageSize: 20 } : current);
    });
    vi.stubGlobal('fetch', fetcher);
    render(<MemoryRouter><WorkOrdersPage {...props} /></MemoryRouter>);
    fireEvent.click(await screen.findByRole('button', { name: /Clear main drain/ }));
    fireEvent.click(await screen.findByRole('button', { name: 'Start Job' }));
    fireEvent.change(await screen.findByLabelText('Completion notes (optional)'), { target: { value: 'Repaired' } });
    fireEvent.click(screen.getByRole('button', { name: 'Complete Job' }));
    expect(await screen.findByText('WORK ORDER COMPLETED')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Complete Job' })).not.toBeInTheDocument();
    expect(fetcher.mock.calls.every(([, init]) => new Headers(init?.headers).get('Authorization') === 'Bearer token')).toBe(true);
  });

  it('reloads a stale job on 409 and retains typed notes', async () => {
    let conflict = false;
    vi.stubGlobal('fetch', vi.fn(async (url: string) => {
      if (url.endsWith('/complete')) { conflict = true; return reply({ error: { code: 'WORK_ORDER_STATE_CONFLICT', message: 'Changed' } }, 409); }
      return reply(url.includes('?') ? { items: [{ ...job, status: 'IN_PROGRESS' }], totalItems: 1, totalPages: 1 } : { ...job, status: 'IN_PROGRESS' });
    }));
    render(<MemoryRouter><WorkOrdersPage {...props} initialId={job.id} /></MemoryRouter>);
    fireEvent.change(await screen.findByLabelText('Completion notes (optional)'), { target: { value: 'Keep my note' } });
    fireEvent.click(screen.getByRole('button', { name: 'Complete Job' }));
    expect(await screen.findByText(/latest status has been loaded/)).toBeInTheDocument();
    expect(conflict).toBe(true); expect(screen.getByLabelText('Completion notes (optional)')).toHaveValue('Keep my note');
  });

  it('shows a missing crew error and does not offer job actions', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => reply({ error: { code: 'CREW_NOT_LINKED', message: 'No crew is linked to this leader account.' } }, 403)));
    render(<MemoryRouter><WorkOrdersPage {...props} /></MemoryRouter>);
    expect(await screen.findByRole('alert')).toHaveTextContent('No crew is linked');
    expect(screen.queryByText('Start Job')).not.toBeInTheDocument();
  });

  it('admin monitoring has filters and no execution actions', async () => {
    const fetcher = vi.fn(async (url: string) => reply(url.includes('?') ? { items: [job], totalItems: 1, totalPages: 1 } : job));
    vi.stubGlobal('fetch', fetcher);
    render(<MemoryRouter><WorkOrdersPage {...props} user={{ ...props.user, role: 'ADMIN' }} initialId={job.id} /></MemoryRouter>);
    await screen.findByRole('heading', { name: job.title, level: 2 });
    expect(screen.queryByText('Start Job')).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText('Created from'), { target: { value: '2026-09-01' } });
    fireEvent.click(screen.getByRole('button', { name: 'Apply filters' }));
    await waitFor(() => expect(fetcher.mock.calls.some(([url]) => url.includes('/work-orders?') && url.includes('from='))).toBe(true));
  });

  it('preserves HTTP error codes and notifies the app about expired sessions', async () => {
    const listener = vi.fn(); window.addEventListener('mehewara-session-expired', listener);
    await expect(handleResponse(reply({ error: { code: 'UNAUTHORIZED', message: 'Expired' } }, 401))).rejects.toMatchObject({ status: 401, code: 'UNAUTHORIZED' });
    expect(listener).toHaveBeenCalledOnce(); window.removeEventListener('mehewara-session-expired', listener);
  });

  it('uses the real approval/edit contracts and blank completion body', async () => {
    const fetcher = vi.fn(async () => reply({ workOrder: { id: 'created-job' } })); vi.stubGlobal('fetch', fetcher);
    expect((await approveRecommendation('token', 'rec', { reason: 'Reviewed', expectedRevision: 1 })).workOrder.id).toBe('created-job');
    await editRecommendation('token', 'rec', { priority: 'HIGH', editReason: 'Site visit', expectedRevision: 1 });
    await startWorkOrder('token', job.id); await completeWorkOrder('token', job.id, ' ');
    const calls = fetcher.mock.calls as unknown as [string, RequestInit][];
    expect(JSON.parse(calls[0][1].body as string)).toEqual({ reason: 'Reviewed', expectedRevision: 1 });
    expect(JSON.parse(calls[1][1].body as string)).toEqual({ priority: 'HIGH', editReason: 'Site visit', expectedRevision: 1 });
    expect(calls[2][1].body).toBeUndefined(); expect(calls[3][1].body).toBe('{}');
  });
});
