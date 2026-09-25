import React, { useMemo } from 'react';

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
    <section aria-label="Coordinator Welcome Workspace" className="problems-welcome-banner">
      {/* Strongly Centered Welcome Content Stack */}
      <div className="welcome-banner-center-content">
        {/* Main Heading */}
        <h1 className="welcome-banner-heading">
          {timeGreeting}, {roleName} !
        </h1>
      </div>
    </section>
  );
};
