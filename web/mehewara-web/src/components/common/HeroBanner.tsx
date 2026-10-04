import React from 'react';
import './HeroBanner.css';

export interface HeroBannerProps {
  badge?: string;
  title: React.ReactNode;
  subtitle: React.ReactNode;
  actions?: React.ReactNode;
  ariaLabel?: string;
  className?: string;
}

export const HeroBanner: React.FC<HeroBannerProps> = ({
  badge,
  title,
  subtitle,
  actions,
  ariaLabel,
  className = '',
}) => {
  return (
    <section
      className={`mw-hero-banner ${className}`.trim()}
      aria-label={ariaLabel || (typeof title === 'string' ? `${title} Banner` : 'Hero Banner')}
    >
      <div className="mw-hero-banner-content">
        {badge && <span className="mw-hero-banner-badge">{badge}</span>}
        <h1 className="mw-hero-banner-heading">{title}</h1>
        <p className="mw-hero-banner-subtitle">{subtitle}</p>
      </div>
      {actions && <div className="mw-hero-banner-actions">{actions}</div>}
    </section>
  );
};
