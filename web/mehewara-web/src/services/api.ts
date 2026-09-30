import type { LoginResponse, User, RegisterRequest, UpdateProfileRequest } from '../types/auth';
import { API_BASE, getAuthHeaders, handleResponse } from './httpClient';

export { API_BASE, ApiRequestError, handleResponse } from './httpClient';

export async function request<T>(path: string, token: string, init?: RequestInit): Promise<T> {
  const headers = new Headers(getAuthHeaders(token, false));
  new Headers(init?.headers).forEach((value, key) => headers.set(key, value));

  const response = await fetch(`${API_BASE}${path}`, { ...init, headers });
  return handleResponse<T>(response);
}

export async function loginWithCredentials(email: string, password: string): Promise<LoginResponse> {
  const res = await fetch(`${API_BASE}/auth/login`, {
    method: 'POST',
    headers: getAuthHeaders(undefined, true),
    body: JSON.stringify({ email, password }),
  });
  return handleResponse<LoginResponse>(res, false);
}

export async function registerResident(data: RegisterRequest): Promise<LoginResponse> {
  const res = await fetch(`${API_BASE}/auth/register`, {
    method: 'POST',
    headers: getAuthHeaders(undefined, true),
    body: JSON.stringify(data),
  });
  return handleResponse<LoginResponse>(res, false);
}

export async function loginWithGoogle(idToken: string): Promise<LoginResponse> {
  const res = await fetch(`${API_BASE}/auth/google`, {
    method: 'POST',
    headers: getAuthHeaders(undefined, true),
    body: JSON.stringify({ idToken }),
  });
  return handleResponse<LoginResponse>(res, false);
}

export async function getCurrentUser(token: string): Promise<User> {
  const res = await fetch(`${API_BASE}/auth/me`, {
    method: 'GET',
    headers: getAuthHeaders(token, false),
  });
  return handleResponse<User>(res);
}

export async function updateUserProfile(token: string, data: UpdateProfileRequest): Promise<User> {
  const res = await fetch(`${API_BASE}/auth/profile`, {
    method: 'PATCH',
    headers: getAuthHeaders(token, true),
    body: JSON.stringify(data),
  });
  return handleResponse<User>(res);
}

export async function uploadProfilePhoto(token: string, file: File): Promise<User> {
  const formData = new FormData();
  formData.append('file', file);

  const res = await fetch(`${API_BASE}/auth/profile/photo`, {
    method: 'PATCH',
    headers: getAuthHeaders(token, false), // let browser set boundary for multipart
    body: formData,
  });
  return handleResponse<User>(res);
}

export async function removeProfilePhoto(token: string): Promise<User> {
  const res = await fetch(`${API_BASE}/auth/profile/photo`, {
    method: 'DELETE',
    headers: getAuthHeaders(token, false),
  });
  return handleResponse<User>(res);
}
