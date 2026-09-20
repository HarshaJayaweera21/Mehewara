import React from 'react';
import type { ReportSummaryResponse } from '../../types/reports';

interface ReportCardProps {
  report: ReportSummaryResponse;
  onViewDetails: (reportId: string) => void;
}

const CATEGORY_COLORS: Record<string, { bg: string; text: string; icon: string; label: string }> = {
  ROAD: { bg: '#fee2e2', text: '#991b1b', icon: '🛣️', label: 'Roads & Pavements' },
  DRAINAGE: { bg: '#ccfbf1', text: '#115e59', icon: '🌊', label: 'Drainage & Flooding' },
  WASTE: { bg: '#f3e8ff', text: '#6b21a8', icon: '🗑️', label: 'Waste Management' },
  ELECTRICAL: { bg: '#fef3c7', text: '#92400e', icon: '⚡', label: 'Electrical & Lighting' },
  ENVIRONMENT: { bg: '#dcfce7', text: '#166534', icon: '🌳', label: 'Environment & Parks' },
};

const DEFAULT_CATEGORY = { bg: '#f1f5f9', text: '#475569', icon: '📌', label: 'Municipal Issue' };

const STATUS_COLORS: Record<string, { bg: string; text: string; border: string }> = {
  PENDING: { bg: '#fef3c7', text: '#92400e', border: '#fde68a' },
  PROCESSING: { bg: '#e0f2fe', text: '#0369a1', border: '#bae6fd' },
  ASSIGNED: { bg: '#e0e7ff', text: '#3730a3', border: '#c7d2fe' },
  RESOLVED: { bg: '#dcfce7', text: '#166534', border: '#bbf7d0' },
  CANCELLED: { bg: '#fee2e2', text: '#991b1b', border: '#fecaca' },
};

export const ReportCard: React.FC<ReportCardProps> = ({ report, onViewDetails }) => {
  const cat = CATEGORY_COLORS[report.category] || DEFAULT_CATEGORY;
  const stat = STATUS_COLORS[report.status] || STATUS_COLORS.PENDING;

  const formatDate = (dateStr: string) => {
    try {
      return new Date(dateStr).toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return dateStr;
    }
  };

  return (
    <div className="report-summary-card">
      <div className="report-card-thumbnail-wrapper">
        {report.firstPhotoUrl ? (
          <img
            src={report.firstPhotoUrl}
            alt={report.category}
            className="report-card-thumbnail"
            loading="lazy"
          />
        ) : (
          <div className="report-card-no-thumbnail">
            <span className="no-thumbnail-icon">{cat.icon}</span>
            <span className="no-thumbnail-label">No photo</span>
          </div>
        )}
      </div>

      <div className="report-card-body">
        <div className="report-card-header">
          <span
            className="category-pill"
            style={{ backgroundColor: cat.bg, color: cat.text }}
          >
            {cat.icon} {cat.label || report.category}
          </span>

          <span
            className="status-pill"
            style={{
              backgroundColor: stat.bg,
              color: stat.text,
              borderColor: stat.border,
            }}
          >
            {report.status}
          </span>
        </div>

        <p className="report-card-description">{report.description}</p>

        <div className="report-card-meta">
          <div className="meta-item" title="Coordinates / Address">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M12 2a8 8 0 0 0-8 8c0 5.25 8 12 8 12s8-6.75 8-12a8 8 0 0 0-8-8z" />
              <circle cx="12" cy="10" r="3" />
            </svg>
            <span className="meta-text">
              {report.address || `${report.latitude.toFixed(4)}, ${report.longitude.toFixed(4)}`}
            </span>
          </div>

          <div className="meta-item" title="Submitted Date">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" />
              <polyline points="12 6 12 12 16 14" />
            </svg>
            <span className="meta-text">{formatDate(report.createdAt)}</span>
          </div>

          {report.linkedProblemCount > 0 && (
            <div className="meta-item problem-link-badge">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" />
                <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />
              </svg>
              <span>Linked to Work Order</span>
            </div>
          )}
        </div>

        <div className="report-card-footer">
          <button
            type="button"
            className="view-details-btn"
            onClick={() => onViewDetails(report.id)}
          >
            View Details & Tracking
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <polyline points="9 18 15 12 9 6" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  );
};
