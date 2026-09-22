import React from 'react';
import type { User } from '../../types/auth';
import { Header } from '../../components/common/Header';
import './LandingPage.css';

export interface LandingPageProps {
  currentUser?: User | null;
  onLogout?: () => void;
  onOpenProfile?: () => void;
  onNavigateToLogin: () => void;
  onNavigateToReports: () => void;
  onNavigateToProblems?: () => void;
}

// ─── Kinetic Letter Animation Helper ──────────────────────────────────────────
const renderAnimatedLetters = (text: string, baseDelay = 0) => {
  let charCounter = 0;
  return text.split(' ').map((word, wordIndex) => (
    <span key={`word-${wordIndex}`} className="landing-char-word">
      {word.split('').map((char, charIdx) => {
        const delay = baseDelay + charCounter * 22;
        charCounter++;
        return (
          <span
            key={`char-${wordIndex}-${charIdx}`}
            className="landing-char"
            style={{ animationDelay: `${delay}ms` }}
          >
            {char}
          </span>
        );
      })}
    </span>
  ));
};

export const LandingPage: React.FC<LandingPageProps> = ({
  currentUser,
  onLogout,
  onOpenProfile,
  onNavigateToLogin,
  onNavigateToReports,
  onNavigateToProblems,
}) => {
  const handleReportClick = () => {
    if (currentUser) {
      onNavigateToReports();
    } else {
      onNavigateToLogin();
    }
  };

  return (
    <div className="landing-container">
      {/* Universal Adaptive Top Navigation Header */}
      <div className="landing-header-wrap">
        <Header
          currentUser={currentUser}
          onLogout={onLogout}
          onOpenProfile={onOpenProfile}
          onLoginClick={onNavigateToLogin}
          onBrandClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
          roleBadgeText={currentUser?.role === 'ADMIN' ? 'Municipal Coordinator' : 'Citizen Resident'}
        />
      </div>

      {/* ====================================================================
          1. Hero Section
          ==================================================================== */}
      <section className="landing-hero">
        <div className="landing-hero-grid">
          {/* Left Column: Narrative, Kinetic Letters & Primary CTA */}
          <div className="landing-hero-content">
            {/* Agentic AI System Badge */}
            <div className="landing-ai-badge">
              <span className="landing-ai-badge-icon" aria-hidden="true">✦</span>
              <span className="landing-ai-badge-text">
                An Agentic AI-Powered Municipal Works Management and Dispatch System
              </span>
            </div>

            {/* Kinetic Letter Animated Title */}
            <h1 className="landing-hero-title">
              <span className="landing-title-row">
                {renderAnimatedLetters('Empowering Citizens.', 100)}
              </span>
              <span className="landing-title-row landing-highlight-text">
                {renderAnimatedLetters('Resolving Municipal Problems.', 450)}
              </span>
            </h1>

            {/* Professional Civic Description */}
            <p className="landing-hero-desc">
              Mehewara connects residents directly with local municipal councils across Sri Lanka.
              Submit geotagged civic issues with photo evidence, while our autonomous agentic AI
              clusters neighborhood reports into prioritized work orders for municipal field crews.
            </p>

            {/* Single Primary Call to Action Button */}
            <div className="landing-hero-actions">
              <button
                type="button"
                className="landing-cta-btn"
                onClick={handleReportClick}
                title={currentUser ? 'Open Citizen Reports Portal' : 'Sign in to submit a report'}
              >
                <svg className="landing-cta-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                  <path d="M12 5v14M5 12h14" />
                </svg>
                <span>Report an Issue</span>
              </button>

              {currentUser?.role === 'ADMIN' && onNavigateToProblems && (
                <button
                  type="button"
                  className="landing-coordinator-link"
                  onClick={onNavigateToProblems}
                  title="Switch to Coordinator Problems Dashboard"
                >
                  <span>Operations Dashboard</span>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                    <polyline points="9 18 15 12 9 6" />
                  </svg>
                </button>
              )}
            </div>

            {/* Metrics & Impact Bar */}
            <div className="landing-hero-stats">
              <div className="landing-stat-item">
                <span className="landing-stat-number">5</span>
                <span className="landing-stat-label">Civic Sectors</span>
              </div>
              <div className="landing-stat-item">
                <span className="landing-stat-number">100%</span>
                <span className="landing-stat-label">Geo-Verified</span>
              </div>
              <div className="landing-stat-item">
                <span className="landing-stat-number">Agentic</span>
                <span className="landing-stat-label">AI Clustering</span>
              </div>
              <div className="landing-stat-item">
                <span className="landing-stat-number">Real-Time</span>
                <span className="landing-stat-label">Field Dispatch</span>
              </div>
            </div>
          </div>

          {/* Right Column: Floating Real-Time Incident Simulation Card */}
          <div className="landing-hero-visual">
            <div className="landing-showcase-card">
              <div className="showcase-header">
                <div className="showcase-badge">
                  <span className="showcase-pulse-dot" />
                  <span>Agentic AI Dispatch</span>
                </div>
                <span className="showcase-time">Just Now • Live</span>
              </div>

              <div className="showcase-incident">
                <div className="showcase-incident-meta">
                  <span className="showcase-pill showcase-pill-critical">HIGH PRIORITY</span>
                  <span className="showcase-pill showcase-pill-category">DRAINAGE & ROADS</span>
                </div>
                <div className="showcase-incident-title">
                  Main Canal Overflow & Road Cavity at Galle Road
                </div>

                <div className="showcase-cluster-box">
                  <div className="showcase-cluster-title">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                      <polygon points="12 2 2 7 12 12 22 7 12 2" />
                      <polyline points="2 17 12 22 22 17" />
                      <polyline points="2 12 12 17 22 12" />
                    </svg>
                    <span>Spatial Cluster: 4 Reports Synthesized into 1 Problem</span>
                  </div>
                  <div className="showcase-cluster-items">
                    <div className="showcase-cluster-item">
                      <span>• Report ID: d0000000-0005</span>
                      <strong>Drainage clog</strong>
                    </div>
                    <div className="showcase-cluster-item">
                      <span>• Report ID: d0000000-0006</span>
                      <strong>Stagnant road flood</strong>
                    </div>
                  </div>
                </div>

                <div className="showcase-progress-wrap">
                  <div className="showcase-progress-header">
                    <span>Field Crew #04 • In Progress</span>
                    <span>75% Resolved</span>
                  </div>
                  <div className="showcase-progress-bar">
                    <div className="showcase-progress-fill" />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ====================================================================
          2. How It Works Section (Timeline-like Architectural Design)
          ==================================================================== */}
      <section className="landing-section">
        <div className="landing-section-header">
          <span className="landing-section-eyebrow">Municipal Workflow</span>
          <h2 className="landing-section-title">How Mehewara Works</h2>
          <p className="landing-section-desc">
            A seamless timeline from the moment a citizen spots an issue to its permanent resolution
            by municipal engineering divisions.
          </p>
        </div>

        <div className="landing-timeline">
          {/* Step 1 */}
          <div className="timeline-step-card">
            <div className="timeline-node-header">
              <div className="timeline-step-number">01</div>
              <div className="timeline-step-icon">📸</div>
            </div>
            <span className="timeline-step-badge">Resident Submission</span>
            <h3 className="timeline-step-title">Snap & Pinpoint</h3>
            <p className="timeline-step-desc">
              Citizens capture photos of the local issue, describe what needs repair, and pinpoint
              the exact geographic coordinates on an interactive map.
            </p>
          </div>

          {/* Step 2 */}
          <div className="timeline-step-card">
            <div className="timeline-node-header">
              <div className="timeline-step-number">02</div>
              <div className="timeline-step-icon">🤖</div>
            </div>
            <span className="timeline-step-badge">Agentic AI Processing</span>
            <h3 className="timeline-step-title">Automated AI Clustering</h3>
            <p className="timeline-step-desc">
              Mehewara's autonomous agents cluster multiple resident reports from the same vicinity,
              deduplicate overlapping entries, and assign severity priority based on civic impact.
            </p>
          </div>

          {/* Step 3 */}
          <div className="timeline-step-card">
            <div className="timeline-node-header">
              <div className="timeline-step-number">03</div>
              <div className="timeline-step-icon">👷</div>
            </div>
            <span className="timeline-step-badge">Council Action</span>
            <h3 className="timeline-step-title">Field Crew Dispatch</h3>
            <p className="timeline-step-desc">
              Municipal coordinators assign verified work orders directly to specialized engineering
              crews, updating residents transparently as the problem is inspected and resolved.
            </p>
          </div>
        </div>
      </section>

      {/* ====================================================================
          3. Municipal Problem Categories Section
          ==================================================================== */}
      <section className="landing-section" style={{ paddingTop: '1rem' }}>
        <div className="landing-section-header">
          <span className="landing-section-eyebrow">Civic Jurisdictions</span>
          <h2 className="landing-section-title">Common Municipal Categories</h2>
          <p className="landing-section-desc">
            Mehewara is structured around the five key municipal infrastructure services maintained
            by local councils.
          </p>
        </div>

        <div className="landing-categories-grid">
          <div className="category-card">
            <div className="category-icon-wrap" style={{ background: '#FEE2E2', color: '#991B1B' }}>
              🛣️
            </div>
            <h3 className="category-title">Roads & Pavements</h3>
            <p className="category-desc">
              Potholes, asphalt damage, broken sidewalks, hazardous curbs, and unpaved road surfaces.
            </p>
          </div>

          <div className="category-card">
            <div className="category-icon-wrap" style={{ background: '#CCFBF1', color: '#115E59' }}>
              🌊
            </div>
            <h3 className="category-title">Drainage & Flooding</h3>
            <p className="category-desc">
              Blocked roadside drains, monsoon stormwater overflow, stagnant puddles, and broken culverts.
            </p>
          </div>

          <div className="category-card">
            <div className="category-icon-wrap" style={{ background: '#F3E8FF', color: '#6B21A8' }}>
              🗑️
            </div>
            <h3 className="category-title">Waste Management</h3>
            <p className="category-desc">
              Uncollected roadside garbage, overflowing public dumpsters, and illegal neighborhood dumping.
            </p>
          </div>

          <div className="category-card">
            <div className="category-icon-wrap" style={{ background: '#FEF3C7', color: '#92400E' }}>
              ⚡
            </div>
            <h3 className="category-title">Electrical & Lighting</h3>
            <p className="category-desc">
              Dark streetlights, damaged lamp posts, hanging power cables, and public electrical hazards.
            </p>
          </div>

          <div className="category-card">
            <div className="category-icon-wrap" style={{ background: '#DCFCE7', color: '#166534' }}>
              🌳
            </div>
            <h3 className="category-title">Environment & Parks</h3>
            <p className="category-desc">
              Fallen tree branches, overgrown public vegetation, park maintenance, and safety concerns.
            </p>
          </div>
        </div>
      </section>

      {/* ====================================================================
          4. Agentic AI Platform Capabilities (Why Mehewara)
          ==================================================================== */}
      <section className="landing-section" style={{ paddingTop: '1rem' }}>
        <div className="landing-section-header">
          <span className="landing-section-eyebrow">Platform Intelligence</span>
          <h2 className="landing-section-title">Built for Real Civic Impact</h2>
          <p className="landing-section-desc">
            Engineered with modern civic-tech standards to eliminate bureaucracy and speed up council response.
          </p>
        </div>

        <div className="landing-pillars-grid">
          <div className="pillar-card">
            <span className="pillar-badge">Spatial Intelligence</span>
            <h3 className="pillar-title">Automated Deduplication</h3>
            <p className="pillar-desc">
              When 10 neighbors report the same damaged road, Mehewara doesn't create 10 disconnected tickets.
              It clusters them into a single high-priority work order with combined citizen evidence.
            </p>
          </div>

          <div className="pillar-card">
            <span className="pillar-badge">End-to-End Tracking</span>
            <h3 className="pillar-title">Transparent Governance</h3>
            <p className="pillar-desc">
              Every report receives a unique tracking ID. Citizens can verify when the council logged the issue,
              when an engineer was assigned, and when the field team resolved it.
            </p>
          </div>

          <div className="pillar-card">
            <span className="pillar-badge">Engineering Coordination</span>
            <h3 className="pillar-title">Council Field Dispatch</h3>
            <p className="pillar-desc">
              Direct municipal integration ensures problem details, GPS locations, and photo documentation
              reach the correct department without middleman delays.
            </p>
          </div>
        </div>
      </section>

      {/* ====================================================================
          5. Bottom Civic Call to Action Banner
          ==================================================================== */}
      <div className="landing-cta-section">
        <div className="landing-cta-card">
          <div className="landing-cta-content">
            <h2 className="landing-cta-title">Help Shape a Cleaner, Safer Sri Lanka</h2>
            <p className="landing-cta-subtitle">
              Your reports provide the vital data municipal councils need to deploy maintenance crews
              effectively. Start reporting civic issues today.
            </p>
          </div>
          <button
            type="button"
            className="landing-cta-white-btn"
            onClick={handleReportClick}
          >
            <span>Report an Issue</span>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <polyline points="9 18 15 12 9 6" />
            </svg>
          </button>
        </div>
      </div>

      {/* ====================================================================
          6. Municipal Footer
          ==================================================================== */}
      <footer className="landing-footer">
        <div className="landing-footer-inner">
          <div className="landing-footer-top">
            <div className="footer-brand-col">
              <div className="footer-brand-title">මෙහෙවර • Mehewara</div>
              <p className="footer-brand-desc">
                An Agentic AI-Powered Municipal Works Management and Dispatch System designed for
                seamless public engagement and rapid civic maintenance across Sri Lanka.
              </p>
            </div>

            <div className="footer-links-grid">
              <div className="footer-col">
                <span className="footer-col-title">Municipal Categories</span>
                <span className="footer-link-item">Roads & Pavements</span>
                <span className="footer-link-item">Drainage & Flooding</span>
                <span className="footer-link-item">Waste Management</span>
                <span className="footer-link-item">Electrical & Lighting</span>
                <span className="footer-link-item">Environment & Parks</span>
              </div>

              <div className="footer-col">
                <span className="footer-col-title">Public Portal</span>
                <span
                  className="footer-link-item"
                  style={{ cursor: 'pointer' }}
                  onClick={handleReportClick}
                >
                  Report a Problem
                </span>
                <span
                  className="footer-link-item"
                  style={{ cursor: 'pointer' }}
                  onClick={onNavigateToLogin}
                >
                  Resident Login / Sign Up
                </span>
                {currentUser?.role === 'ADMIN' && onNavigateToProblems && (
                  <span
                    className="footer-link-item"
                    style={{ cursor: 'pointer' }}
                    onClick={onNavigateToProblems}
                  >
                    Coordinator Dashboard
                  </span>
                )}
              </div>

              <div className="footer-col">
                <span className="footer-col-title">Civic Hotlines</span>
                <span className="footer-link-item">Emergency Services: 119</span>
                <span className="footer-link-item">Disaster Management: 117</span>
                <span className="footer-link-item">Municipal Council Dispatch: 1990</span>
              </div>
            </div>
          </div>

          <div className="landing-footer-bottom">
            <span>© {new Date().getFullYear()} Mehewara Municipal Public Operations. All rights reserved.</span>
            <span>Agentic AI Powered Civic Infrastructure Platform</span>
          </div>
        </div>
      </footer>
    </div>
  );
};
