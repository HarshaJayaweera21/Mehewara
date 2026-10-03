import React, { useMemo } from 'react';
import { HeroBanner } from '../common/HeroBanner';

export interface CoordinatorWelcomeBannerProps {
  roleName?: string;
  activeProblemsCount?: number;
}

export const CoordinatorWelcomeBanner: React.FC<CoordinatorWelcomeBannerProps> = ({
  roleName = 'Coordinator',
  activeProblemsCount,
}) => {
  // Determine appropriate greeting based on actual local time of day
  const timeGreeting = useMemo(() => {
    const hour = new Date().getHours();
    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }, []);

  return (
    <HeroBanner
      badge="AI Agent 2 : Consolidation & Geo-Clustering"
      title={`${timeGreeting}, ${roleName} — Municipal Problems Board`}
      subtitle={`Consolidated public infrastructure problems, spatial clustering, priority assessment, and automated dispatch triage.${
        activeProblemsCount != null ? ` Currently tracking ${activeProblemsCount} active problems across wards.` : ''
      }`}
      ariaLabel="Coordinator Welcome Workspace"
    />
  );
};
