import type { LoginResponse, User, RegisterRequest, UpdateProfileRequest, ApiError } from '../types/auth';

const API_BASE = 'http://localhost:5194/api';

async function handleResponse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    let errorData: ApiError | null = null;
    try {
      errorData = await res.json();
    } catch {
      // response wasn't JSON
    }
    const message = errorData?.error?.message || `Request failed with status ${res.status}`;
    throw new Error(message);
  }
  return res.json();
}

export async function loginWithCredentials(email: string, password: string): Promise<LoginResponse> {
  const res = await fetch(`${API_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  return handleResponse<LoginResponse>(res);
}

export async function registerResident(data: RegisterRequest): Promise<LoginResponse> {
  const res = await fetch(`${API_BASE}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  return handleResponse<LoginResponse>(res);
}

export async function loginWithGoogle(idToken: string): Promise<LoginResponse> {
  const res = await fetch(`${API_BASE}/auth/google`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken }),
  });
  return handleResponse<LoginResponse>(res);
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
