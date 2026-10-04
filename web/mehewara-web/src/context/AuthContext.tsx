import React, { createContext, useContext, useState, useEffect, useCallback, useMemo } from 'react';
import type { User } from '../types/auth';
import { request, ApiRequestError } from '../services/api';

export interface AuthContextType {
  currentUser: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  sessionMessage: string;
  login: (user: User, accessToken: string) => void;
  logout: () => void;
  updateCurrentUser: (user: User) => void;
  clearSessionMessage: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

function isTokenExpired(token: string | null): boolean {
  if (!token) return true;
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return true;
    const payload = JSON.parse(atob(parts[1]));
    if (!payload.exp) return false;
    return Date.now() >= payload.exp * 1000;
  } catch {
    return true;
  }
}

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [token, setToken] = useState<string | null>(() => {
    const saved = localStorage.getItem('mehewara_token');
    if (isTokenExpired(saved)) {
      localStorage.removeItem('mehewara_token');
      localStorage.removeItem('mehewara_user');
      return null;
    }
    return saved;
  });

  const [currentUser, setCurrentUser] = useState<User | null>(() => {
    const savedToken = localStorage.getItem('mehewara_token');
    if (isTokenExpired(savedToken)) return null;
    try {
      const savedUser = localStorage.getItem('mehewara_user');
      return savedUser ? JSON.parse(savedUser) : null;
    } catch {
      return null;
    }
  });

  const [isLoading, setIsLoading] = useState<boolean>(Boolean(token));
  const [sessionMessage, setSessionMessage] = useState<string>('');

  const logout = useCallback(() => {
    localStorage.removeItem('mehewara_token');
    localStorage.removeItem('mehewara_user');
    setToken(null);
    setCurrentUser(null);
  }, []);

  const login = useCallback((user: User, accessToken: string) => {
    localStorage.setItem('mehewara_token', accessToken);
    localStorage.setItem('mehewara_user', JSON.stringify(user));
    setToken(accessToken);
    setCurrentUser(user);
    setSessionMessage('');
  }, []);

  const updateCurrentUser = useCallback((user: User) => {
    localStorage.setItem('mehewara_user', JSON.stringify(user));
    setCurrentUser(user);
  }, []);

  const clearSessionMessage = useCallback(() => setSessionMessage(''), []);

  // Listen to cross-tab storage changes & API 401 events
  useEffect(() => {
    const handleStorageChange = () => {
      const savedToken = localStorage.getItem('mehewara_token');
      if (isTokenExpired(savedToken)) {
        logout();
        return;
      }
      setToken(savedToken);
      try {
        const savedUser = localStorage.getItem('mehewara_user');
        setCurrentUser(savedUser ? JSON.parse(savedUser) : null);
      } catch {
        setCurrentUser(null);
      }
    };

    const handleUnauthorized = () => {
      logout();
      setSessionMessage('Your session expired. Please sign in again.');
    };

    window.addEventListener('storage', handleStorageChange);
    window.addEventListener('auth:unauthorized', handleUnauthorized);
    window.addEventListener('mehewara-session-expired', handleUnauthorized);

    return () => {
      window.removeEventListener('storage', handleStorageChange);
      window.removeEventListener('auth:unauthorized', handleUnauthorized);
      window.removeEventListener('mehewara-session-expired', handleUnauthorized);
    };
  }, [logout]);

  // Verify session on mount against /Auth/me
  useEffect(() => {
    if (!token) {
      setIsLoading(false);
      return;
    }

    let active = true;
    request<User>('/Auth/me', token)
      .then((user) => {
        if (active) {
          setCurrentUser(user);
          localStorage.setItem('mehewara_user', JSON.stringify(user));
        }
      })
      .catch((error) => {
        if (active && !(error instanceof ApiRequestError && error.status === 401)) {
          setSessionMessage('Unable to verify your session. Check your connection.');
        }
      })
      .finally(() => {
        if (active) {
          setIsLoading(false);
        }
      });

    return () => {
      active = false;
    };
  }, [token]);

  const value = useMemo(
    () => ({
      currentUser,
      token,
      isAuthenticated: Boolean(token && currentUser && !isTokenExpired(token)),
      isLoading,
      sessionMessage,
      login,
      logout,
      updateCurrentUser,
      clearSessionMessage,
    }),
    [currentUser, token, isLoading, sessionMessage, login, logout, updateCurrentUser, clearSessionMessage]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

// eslint-disable-next-line react-refresh/only-export-components
export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
