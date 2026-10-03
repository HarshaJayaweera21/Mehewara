import React from 'react';
import { Header } from './Header';
import { OpsNavStrip, type OpsNavPage } from './OpsNavStrip';
import type { User } from '../../types/auth';
import './AdminPageLayout.css';

export interface AdminPageLayoutProps {
  currentUser?: User | null;
  onLogout?: () => void;
  onOpenProfile?: () => void;
  onBrandClick?: () => void;
  activeNavPage: OpsNavPage;
  pendingDispatchCount?: number;
  className?: string;
  children: React.ReactNode;
}

export const AdminPageLayout: React.FC<AdminPageLayoutProps> = ({
  currentUser,
  onLogout,
  onOpenProfile,
  onBrandClick,
  activeNavPage,
  pendingDispatchCount,
  className = '',
  children,
}) => {
  return (
    <div className="mw-admin-layout">
      <Header
        currentUser={currentUser}
        onLogout={onLogout}
        onOpenProfile={onOpenProfile}
        onBrandClick={onBrandClick}
      />
      <OpsNavStrip
        activePage={activeNavPage}
        pendingDispatchCount={pendingDispatchCount}
      />
      <main className={`mw-admin-content ${className}`.trim()}>
        {children}
      </main>
    </div>
  );
};
