import React, { useEffect, useState } from 'react';
import type { CrewDetail } from '../../../types/crew';
import { getCrewById } from '../../../services/crewApi';

interface CrewDetailModalProps {
  crewId: string | null;
  token: string;
  onClose: () => void;
}

export const CrewDetailModal: React.FC<CrewDetailModalProps> = ({
  crewId,
  token,
  onClose,
}) => {
  const [crew, setCrew] = useState<CrewDetail | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!crewId) return;

    let ignore = false;
    setIsLoading(true);
    setErrorMessage(null);

    getCrewById(token, crewId)
      .then((data) => {
        if (!ignore) {
          setCrew(data);
          setIsLoading(false);
        }
      })
      .catch((err) => {
        if (!ignore) {
          setErrorMessage(err instanceof Error ? err.message : 'Failed to load crew profile.');
          setIsLoading(false);
        }
      });

    return () => {
      ignore = true;
    };
  }, [crewId, token]);

  if (!crewId) return null;

  return (
    <div className="dispatch-modal-backdrop" onClick={onClose}>
      <div className="dispatch-modal-card crew-modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="dispatch-modal-header">
          <div className="dispatch-modal-title-wrap">
            <span className="dispatch-modal-tag tag-crew">Municipal Crew Profile</span>
            <h3 className="dispatch-modal-title">{crew?.name || 'Municipal Operations Crew'}</h3>
          </div>
          <button type="button" className="dispatch-modal-close" onClick={onClose} aria-label="Close">
            ✕
          </button>
        </div>

        <div className="crew-modal-content">
          {isLoading && (
            <div className="crew-modal-loading">
              <div className="dispatch-spinner-pip" />
              <span>Loading crew specifications & telemetry...</span>
            </div>
          )}

          {errorMessage && (
            <div className="dispatch-modal-error">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10" />
                <line x1="12" y1="8" x2="12" y2="12" />
                <line x1="12" y1="16" x2="12.01" y2="16" />
              </svg>
              <span>{errorMessage}</span>
            </div>
          )}

          {!isLoading && crew && (
            <div className="crew-detail-body">
              {/* Status & Category Banner */}
              <div className="crew-detail-banner-row">
                <div className="crew-category-badge">
                  <span className="crew-badge-dot" />
                  <span>{crew.crewType} SPECIALIZATION</span>
                </div>
                <div className={`crew-status-pill status-${crew.status.toLowerCase()}`}>
                  <span className="status-dot" />
                  <span>{crew.status}</span>
                </div>
              </div>

              {/* Description */}
              {crew.description && (
                <div className="crew-description-block">
                  <span className="detail-section-label">Operational Mandate</span>
                  <p className="crew-description-text">{crew.description}</p>
                </div>
              )}

              {/* Operational Metadata Grid */}
              <div className="crew-meta-grid">
                <div className="crew-meta-item">
                  <span className="meta-item-label">Crew Leader</span>
                  <span className="meta-item-val">{crew.crewLeaderName || 'Municipal Supervisor Assigned'}</span>
                </div>
                <div className="crew-meta-item">
                  <span className="meta-item-label">Emergency Contact</span>
                  <span className="meta-item-val font-mono">{crew.contactNumber || '+94 11 269 1111'}</span>
                </div>
                <div className="crew-meta-item">
                  <span className="meta-item-label">Current Work Order</span>
                  <span className="meta-item-val font-mono">
                    {crew.activeWorkOrderId ? (
                      <span className="active-wo-link">{crew.activeWorkOrderId.substring(0, 8)}...</span>
                    ) : (
                      <span className="text-muted">None (Standing By)</span>
                    )}
                  </span>
                </div>
                <div className="crew-meta-item">
                  <span className="meta-item-label">Municipal Registry ID</span>
                  <span className="meta-item-val font-mono">{crew.id.substring(0, 13)}...</span>
                </div>
              </div>

              {/* Real-time Readiness Notice */}
              <div className={`crew-readiness-notice ${crew.status === 'AVAILABLE' ? 'ready' : 'busy'}`}>
                {crew.status === 'AVAILABLE' ? (
                  <>
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
                      <polyline points="22 4 12 14.01 9 11.01" />
                    </svg>
                    <span>This crew is available for immediate automated dispatch assignment via Agent 3 recommendation.</span>
                  </>
                ) : (
                  <>
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                      <circle cx="12" cy="12" r="10" />
                      <line x1="12" y1="8" x2="12" y2="12" />
                      <line x1="12" y1="16" x2="12.01" y2="16" />
                    </svg>
                    <span>Crew is currently deployed on an active remediation work order. AI dispatch prioritizes available units.</span>
                  </>
                )}
              </div>
            </div>
          )}
        </div>

        <div className="dispatch-modal-actions">
          <button type="button" className="dispatch-btn-secondary" onClick={onClose}>
            Close Profile
          </button>
        </div>
      </div>
    </div>
  );
};
