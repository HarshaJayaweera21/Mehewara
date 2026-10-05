import React, { useEffect, useState } from 'react';
import type { CrewDetail, CrewType } from '../../../types/crew';
import { getCrewById } from '../../../services/crewApi';
import '../../dispatch/DispatchDashboardPage.css';

const CREW_EQUIPMENT_SPECS: Record<
  CrewType,
  {
    baseDepot: string;
    vehicleUnit: string;
    equipment: string[];
    memberCount: number;
  }
> = {
  DRAINAGE: {
    baseDepot: 'Central Colombo Depot — Ward 07 (Cinnamon Gardens)',
    vehicleUnit: 'Heavy Jetting Unit WP-LB-4091',
    equipment: [
      'High-pressure sewer jetter (250 bar)',
      'Submersible trash pump (4-inch)',
      'Four-gas atmospheric detection monitors',
      'Hydraulic trench shoring safety set',
    ],
    memberCount: 6,
  },
  ROAD: {
    baseDepot: 'Central Colombo Depot — Ward 03 (Kollupitiya)',
    vehicleUnit: 'Asphalt Patching Truck WP-GA-8112',
    equipment: [
      'Vibratory dual-drum asphalt compactor',
      'Infrared pavement joint heater',
      'Pneumatic demolition jackhammers',
      'Solar-powered traffic diversion arrow board',
    ],
    memberCount: 5,
  },
  WASTE: {
    baseDepot: 'North Colombo Depot — Ward 12 (Kotahena)',
    vehicleUnit: 'Hydraulic Compactor WP-NA-2234',
    equipment: [
      'Rear-loading hydraulic waste compactor',
      'Dual-bin mechanical lifter & tipper',
      'Chemical spill containment barrier kit',
      'Industrial sanitization & pressure wash rig',
    ],
    memberCount: 4,
  },
  ELECTRICAL: {
    baseDepot: 'Central Colombo Depot — Ward 05 (Havelock Town)',
    vehicleUnit: 'Insulated Aerial Boom Lift WP-QA-5067',
    equipment: [
      '14m insulated cherry picker bucket',
      '1000V rated live-line dielectric tools',
      'Digital street illumination lux meter',
      'Mobile emergency grid generator (15 kVA)',
    ],
    memberCount: 4,
  },
  ENVIRONMENT: {
    baseDepot: 'South Colombo Depot — Ward 06 (Wellawatte)',
    vehicleUnit: 'Arboricultural Flatbed WP-LA-3389',
    equipment: [
      'High-capacity hydraulic wood chipper',
      'Heavy commercial chainsaws (24" & 36")',
      'Arborist rigging blocks and friction brakes',
      'Hydraulic knuckle-boom debris crane',
    ],
    memberCount: 5,
  },
};

interface CrewDetailModalProps {
  crewId: string | null;
  token: string;
  onClose: () => void;
  onNavigateToWorkOrder?: (workOrderId?: string) => void;
}

export const CrewDetailModal: React.FC<CrewDetailModalProps> = ({
  crewId,
  token,
  onClose,
  onNavigateToWorkOrder,
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
                  <span className="meta-item-label">Assigned Base Depot</span>
                  <span className="meta-item-val">
                    {CREW_EQUIPMENT_SPECS[crew.crewType]?.baseDepot || 'Municipal Central Depot'}
                  </span>
                </div>
                <div className="crew-meta-item">
                  <span className="meta-item-label">Vehicle Fleet ID</span>
                  <span className="meta-item-val font-mono">
                    {CREW_EQUIPMENT_SPECS[crew.crewType]?.vehicleUnit || 'Municipal Unit'}
                  </span>
                </div>
                <div className="crew-meta-item">
                  <span className="meta-item-label">Current Work Order</span>
                  <span className="meta-item-val font-mono">
                    {crew.activeWorkOrderId ? (
                      <span className="active-wo-link">WO: {crew.activeWorkOrderId.substring(0, 8)}...</span>
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

              {/* Standard Equipment Inventory */}
              {CREW_EQUIPMENT_SPECS[crew.crewType]?.equipment && (
                <div className="crew-equipment-section" style={{ marginTop: '16px' }}>
                  <span className="detail-section-label" style={{ display: 'block', marginBottom: '8px', fontSize: '0.78rem', fontWeight: 700, color: '#68736E', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                    Certified Equipment & Heavy Machinery
                  </span>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: '8px' }}>
                    {CREW_EQUIPMENT_SPECS[crew.crewType].equipment.map((item, idx) => (
                      <div
                        key={idx}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '6px',
                          padding: '6px 10px',
                          background: '#F9FBFA',
                          border: '1px solid #EBEFEA',
                          borderRadius: '6px',
                          fontSize: '0.8rem',
                          color: '#18211E',
                        }}
                      >
                        <span style={{ color: '#4FD1A1', fontSize: '10px' }}>●</span>
                        <span>{item}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Real-time Readiness Notice */}
              <div className={`crew-readiness-notice ${crew.status === 'AVAILABLE' ? 'ready' : 'busy'}`} style={{ marginTop: '16px' }}>
                {crew.status === 'AVAILABLE' ? (
                  <>
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
                      <polyline points="22 4 12 14.01 9 11.01" />
                    </svg>
                    <span>This crew is available for immediate automated dispatch assignment via recommendation queue.</span>
                  </>
                ) : (
                  <>
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                      <circle cx="12" cy="12" r="10" />
                      <line x1="12" y1="8" x2="12" y2="12" />
                      <line x1="12" y1="16" x2="12.01" y2="16" />
                    </svg>
                    <span>Crew is currently deployed on an active remediation work order. Dispatch queue prioritizes available units.</span>
                  </>
                )}
              </div>
            </div>
          )}
        </div>

        <div className="dispatch-modal-actions">
          {crew?.activeWorkOrderId && onNavigateToWorkOrder && (
            <button
              type="button"
              className="dispatch-btn-primary"
              onClick={() => {
                onClose();
                onNavigateToWorkOrder(crew.activeWorkOrderId!);
              }}
            >
              <span>View Active Work Order</span>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="9 18 15 12 9 6" />
              </svg>
            </button>
          )}
          <button type="button" className="dispatch-btn-secondary" onClick={onClose}>
            Close Profile
          </button>
        </div>
      </div>
    </div>
  );
};
