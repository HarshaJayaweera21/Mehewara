import React, { useMemo } from 'react';
import { HeroBanner } from '../common/HeroBanner';

export interface CoordinatorWelcomeBannerProps {
  roleName?: string;
  activeProblemsCount?: number;
}

export const CoordinatorWelcomeBanner: React.FC<CoordinatorWelcomeBannerProps> = ({
  roleName = 'Coordinator',
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
      badge="PROBLEMS BOARD"
      title={`${timeGreeting}, ${roleName} — Municipal Problems Board`}
      subtitle="Consolidated municipal infrastructure defects, spatial clustering, priority evaluation, and resolution tracking across all wards."
      ariaLabel="Coordinator Welcome Workspace"
    />
  );
};
