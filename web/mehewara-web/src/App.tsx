import React from 'react';
import { BrowserRouter, useInRouterContext } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { AppRoutes } from './routes/AppRoutes';

function AppContent() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  );
}

function App() {
  let inRouter = false;
  try {
    inRouter = useInRouterContext();
  } catch {
    inRouter = false;
  }

  if (inRouter) {
    return <AppContent />;
  }

  return (
    <BrowserRouter>
      <AppContent />
    </BrowserRouter>
  );
}

export default App;
