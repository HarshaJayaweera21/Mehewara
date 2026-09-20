import React, { useEffect, useState } from 'react';
import { getReportById } from '../../services/reportApi';
import type { ReportResponse } from '../../types/reports';
import { ReportLocationMap } from '../common/ReportLocationMap';

interface ReportDetailModalProps {
  token: string;
  reportId: string;
  onClose: () => void;
}

const CATEGORY_NAMES: Record<string, string> = {
  ROAD: 'Roads & Pavements',
  DRAINAGE: 'Drainage & Flooding',
  WASTE: 'Waste Management',
  ELECTRICAL: 'Electrical & Lighting',
  ENVIRONMENT: 'Environment & Parks',
};

export const ReportDetailModal: React.FC<ReportDetailModalProps> = ({ token, reportId, onClose }) => {
  const [report, setReport] = useState<ReportResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showRawJson, setShowRawJson] = useState(false);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    let isMounted = true;

    async function fetchReport() {
      try {
        setLoading(true);
        setError(null);
        const data = await getReportById(token, reportId);
        if (isMounted) {
          setReport(data);
        }
      } catch (err: unknown) {
        if (isMounted) {
          setError(err instanceof Error ? err.message : 'Failed to load report details.');
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    fetchReport();

    return () => {
      isMounted = false;
    };
  }, [token, reportId]);

  const handleCopyId = () => {
    if (!report) return;
    navigator.clipboard.writeText(report.id);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const formatDate = (dateStr: string) => {
    try {
      return new Date(dateStr).toLocaleString('en-US', {
        dateStyle: 'medium',
        timeStyle: 'short',
      });
    } catch {
      return dateStr;
    }
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-dialog modal-large" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div className="modal-header-left">
            <h2 className="modal-title">Report Details & Workflow Status</h2>
            <div className="report-id-badge" onClick={handleCopyId} title="Click to copy Report UUID">
              <span>ID: {reportId}</span>
              <button type="button" className="copy-btn">{copied ? '✓ Copied' : '📋'}</button>
            </div>
          </div>
          <button type="button" className="modal-close-btn" onClick={onClose} aria-label="Close">
            &times;
          </button>
        </div>

        {loading && (
          <div className="modal-loading-state">
            <span className="spinner"></span>
            <span>Loading report from Mehewara API...</span>
          </div>
        )}

        {error && (
          <div className="error-banner" style={{ margin: '1.5rem' }}>
            {error}
          </div>
        )}

        {report && !loading && (
          <div className="report-detail-content">
            {/* Top Status & Category Banner */}
            <div className="detail-status-banner">
              <div className="status-banner-left">
                <span className="detail-category-badge">{CATEGORY_NAMES[report.category] || report.category}</span>
                <span className={`detail-status-pill status-${report.status.toLowerCase()}`}>
                  ● Status: {report.status}
                </span>
              </div>
              <div className="status-banner-right">
                <span>Submitted: {formatDate(report.createdAt)}</span>
              </div>
            </div>

            {/* Resident Info */}
            <div className="detail-section">
              <h3 className="detail-section-title">Citizen Submitter</h3>
              <div className="resident-info-card">
                <div className="resident-avatar">
                  {report.residentName ? report.residentName.charAt(0).toUpperCase() : 'U'}
                </div>
                <div className="resident-meta">
                  <div className="resident-name">{report.residentName || 'Registered Resident'}</div>
                  <div className="resident-email">{report.residentEmail || `User ID: ${report.residentId}`}</div>
                </div>
              </div>
            </div>

            {/* Description */}
            <div className="detail-section">
              <h3 className="detail-section-title">Citizen's Description</h3>
              <div className="description-box">{report.description}</div>
            </div>

            {/* Location & GPS */}
            <div className="detail-section">
              <div className="section-header-row">
                <h3 className="detail-section-title">Location & Coordinates</h3>
                <a
                  href={`https://www.google.com/maps?q=${report.latitude},${report.longitude}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="google-maps-link"
                >
                  🗺️ Open in Google Maps
                </a>
              </div>
              <div className="location-info-grid">
                <div className="location-item">
                  <span className="loc-label">Latitude:</span>
                  <span className="loc-val">{report.latitude}</span>
                </div>
                <div className="location-item">
                  <span className="loc-label">Longitude:</span>
                  <span className="loc-val">{report.longitude}</span>
                </div>
                {report.address && (
                  <div className="location-item full-width">
                    <span className="loc-label">Address / Landmark:</span>
                    <span className="loc-val">{report.address}</span>
                  </div>
                )}
              </div>

              {/* Pinned Map */}
              <ReportLocationMap
                latitude={report.latitude}
                longitude={report.longitude}
                label={`${report.category.replace('_', ' ')} Issue`}
                height="220px"
              />
            </div>

            {/* Photos */}
            <div className="detail-section">
              <h3 className="detail-section-title">
                Attached Photos ({report.photos.length})
              </h3>
              {report.photos.length > 0 ? (
                <div className="detail-photos-grid">
                  {report.photos.map((p) => (
                    <a
                      key={p.photoId}
                      href={p.photoUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="photo-card-link"
                      title="Click to view full size"
                    >
                      <img src={p.photoUrl} alt="Report evidence" className="detail-photo-img" />
                      <div className="photo-info-overlay">
                        <span>{p.fileName || 'Photo'}</span>
                      </div>
                    </a>
                  ))}
                </div>
              ) : (
                <div className="empty-sub-state">No photos were uploaded with this report.</div>
              )}
            </div>

            {/* Linked Problems (Consolidation status) */}
            <div className="detail-section">
              <h3 className="detail-section-title">
                Municipal Work Order / Problem Consolidation ({report.linkedProblems.length})
              </h3>
              {report.linkedProblems.length > 0 ? (
                <div className="linked-problems-list">
                  {report.linkedProblems.map((prob) => (
                    <div key={prob.problemId} className="linked-problem-card">
                      <div className="problem-card-top">
                        <span className="problem-title">{prob.title}</span>
                        <span className="problem-status-pill">{prob.workStatus}</span>
                      </div>
                      <div className="problem-meta-row">
                        <span>Category: {prob.category}</span>
                        {prob.priority && <span>Priority: <strong>{prob.priority}</strong></span>}
                        <span>Linked On: {formatDate(prob.linkedAt)}</span>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="empty-sub-state info-pill">
                  ℹ️ This report is currently in <strong>{report.status}</strong> status and has not yet been linked to an active municipal work crew problem ticket.
                </div>
              )}
            </div>

            {/* Developer Raw JSON Inspector */}
            <div className="detail-section">
              <button
                type="button"
                className="toggle-json-btn"
                onClick={() => setShowRawJson(!showRawJson)}
              >
                {showRawJson ? '▼ Hide Raw JSON Response' : '► Inspect Raw JSON API Response'}
              </button>
              {showRawJson && (
                <pre className="raw-json-viewer">
                  {JSON.stringify(report, null, 2)}
                </pre>
              )}
            </div>
          </div>
        )}

        <div className="modal-footer">
          <button type="button" className="secondary-btn" onClick={onClose}>
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
