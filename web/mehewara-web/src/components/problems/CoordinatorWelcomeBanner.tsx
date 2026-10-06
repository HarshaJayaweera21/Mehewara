import React from 'react';
import { HeroBanner } from '../common/HeroBanner';

export interface CoordinatorWelcomeBannerProps {
  roleName?: string;
  activeProblemsCount?: number;
}

export const CoordinatorWelcomeBanner: React.FC<CoordinatorWelcomeBannerProps> = ({
  roleName = 'Coordinator',
}) => {
  return (
    <HeroBanner
      badge="PROBLEMS BOARD"
      title={`${roleName} — Municipal Problems Board`}
      subtitle="Consolidated municipal infrastructure defects, spatial clustering, priority evaluation, and resolution tracking across all wards."
      ariaLabel="Coordinator Welcome Workspace"
    />
  );
};
