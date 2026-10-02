import { request } from './api';
import type { WorkOrder, WorkOrderQuery } from '../types/workOrders';
import type { PagedResult } from '../types/problems';

export function getWorkOrders(token: string, admin: boolean, filters: WorkOrderQuery) {
  const query = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== undefined && value !== '') query.set(key, String(value));
  });
  return request<PagedResult<WorkOrder>>(`${admin ? '/work-orders' : '/crew/work-orders'}?${query}`, token);
}
export const getWorkOrder = (token: string, id: string) => request<WorkOrder>(`/work-orders/${id}`, token);
export const startWorkOrder = (token: string, id: string) => request<WorkOrder>(`/work-orders/${id}/start`, token, { method: 'POST' });
export const completeWorkOrder = (token: string, id: string, notes: string) => request<WorkOrder>(`/work-orders/${id}/complete`, token, {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(notes.trim() ? { completionNotes: notes.trim() } : {}),
});
