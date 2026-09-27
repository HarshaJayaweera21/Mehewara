import type { LoginResponse, User, RegisterRequest, UpdateProfileRequest } from '../types/auth';
export const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5194/api').replace(/\/$/, '');

export class ApiRequestError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string, message: string) { super(message); this.status = status; this.code = code; }
}

export async function handleResponse<T>(response: Response, notifyExpired = true): Promise<T> {
  if (!response.ok) {
    const body = await response.json().catch(() => null);
    if (response.status === 401 && notifyExpired) window.dispatchEvent(new Event('mehewara-session-expired'));
    throw new ApiRequestError(response.status, body?.error?.code || 'REQUEST_FAILED',
      body?.error?.message || `Request failed (${response.status}).`);
  }
  return response.json() as Promise<T>;
}

export async function request<T>(path: string, token: string, init?: RequestInit): Promise<T> {
  return handleResponse<T>(await fetch(`${API_BASE}${path}`, {
    ...init, headers: { Authorization: `Bearer ${token}`, ...init?.headers },
  }));
}

export async function loginWithCredentials(email: string, password: string): Promise<LoginResponse> {
  const res = await fetch(`${API_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  return handleResponse<LoginResponse>(res, false);
}

export async function registerResident(data: RegisterRequest): Promise<LoginResponse> {
  const res = await fetch(`${API_BASE}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  return handleResponse<LoginResponse>(res, false);
}

export async function loginWithGoogle(idToken: string): Promise<LoginResponse> {
  const res = await fetch(`${API_BASE}/auth/google`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken }),
  });
  return handleResponse<LoginResponse>(res, false);
}

export async function getCurrentUser(token: string): Promise<User> {
  const res = await fetch(`${API_BASE}/auth/me`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
  return handleResponse<User>(res);
}

export async function updateUserProfile(token: string, data: UpdateProfileRequest): Promise<User> {
  const res = await fetch(`${API_BASE}/auth/profile`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(data),
  });
  return handleResponse<User>(res);
}

export async function uploadProfilePhoto(token: string, file: File): Promise<User> {
  const formData = new FormData();
  formData.append('file', file);

  const res = await fetch(`${API_BASE}/auth/profile/photo`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: formData,
  });
  return handleResponse<User>(res);
}

export async function removeProfilePhoto(token: string): Promise<User> {
  const res = await fetch(`${API_BASE}/auth/profile/photo`, {
    method: 'DELETE',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
  return handleResponse<User>(res);
}
