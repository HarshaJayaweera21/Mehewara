import React, { useState } from 'react';
import type { RecommendationListItem } from '../../../types/dispatch';
import { approveRecommendation } from '../../../services/dispatchApi';

interface ApproveRecommendationModalProps {
  recommendation: RecommendationListItem;
  token: string;
  onClose: () => void;
  onSuccess: (workOrderId: string) => void;
}

export const ApproveRecommendationModal: React.FC<ApproveRecommendationModalProps> = ({
  recommendation,
  token,
  onClose,
  onSuccess,
}) => {
  const [reason, setReason] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setErrorMessage(null);

    try {
      const res = await approveRecommendation(token, recommendation.recommendationId, {
        reason: reason.trim() || undefined,
      });
      onSuccess(res.workOrder.id);
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Approval failed. Check the server response and retry.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="dispatch-modal-backdrop" onClick={onClose}>
      <div className="dispatch-modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="dispatch-modal-header">
          <div className="dispatch-modal-title-wrap">
            <span className="dispatch-modal-tag">Human-in-the-Loop Dispatch Approval</span>
            <h3 className="dispatch-modal-title">Authorize Municipal Work Order</h3>
          </div>
          <button type="button" className="dispatch-modal-close" onClick={onClose} aria-label="Close">
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit} className="dispatch-modal-form">
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

          <div className="dispatch-summary-box">
            <div className="summary-field">
              <span className="summary-label">Target Problem</span>
              <span className="summary-value">{recommendation.problemTitle}</span>
            </div>
            <div className="summary-field-row">
              <div className="summary-field">
                <span className="summary-label">Category</span>
                <span className="summary-badge">{recommendation.category}</span>
              </div>
              <div className="summary-field">
                <span className="summary-label">Assessed Priority</span>
                <span className={`summary-priority priority-${recommendation.priority.toLowerCase()}`}>
                  {recommendation.priority} ({recommendation.priorityScore}/100)
                </span>
              </div>
            </div>
            <div className="summary-field">
              <span className="summary-label">Assignee Crew</span>
              <span className="summary-crew-name">
                {recommendation.recommendedCrewName || 'No Crew Selected'}
              </span>
            </div>
          </div>

          <div
            style={{
              display: 'flex',
              alignItems: 'flex-start',
              gap: '10px',
              padding: '10px 12px',
              backgroundColor: '#e5f6ee',
              borderRadius: '6px',
              fontSize: '12px',
              color: '#123c32',
              marginBottom: '16px',
              border: '1px solid #c2ebd9',
              lineHeight: 1.4,
            }}
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              style={{ flexShrink: 0, marginTop: '1px' }}
            >
              <polyline points="9 11 12 14 22 4" />
              <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" />
            </svg>
            <div>
              <strong>Squad Priority Queue:</strong> Approving adds this work order to{' '}
              <strong>{recommendation.recommendedCrewName || 'the squad'}</strong>&apos;s mobile queue in priority order ({recommendation.priority}).
              Squads can safely stack up multiple assigned tasks and execute them sequentially.
            </div>
          </div>

          <div className="dispatch-form-group">
            <label htmlFor="approvalReason" className="dispatch-form-label">Approval reason (optional)</label>
            <textarea id="approvalReason" className="dispatch-form-textarea" value={reason} onChange={e => setReason(e.target.value)} rows={3} />
          </div>

          <div className="dispatch-modal-actions">
            <button
              type="button"
              className="dispatch-btn-secondary"
              onClick={onClose}
              disabled={isSubmitting}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="dispatch-btn-primary"
              disabled={isSubmitting}
            >
              {isSubmitting ? (
                <>
                  <span className="dispatch-btn-spinner" />
                  <span>Validating & Creating Work Order...</span>
                </>
              ) : (
                <>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                    <polyline points="20 6 9 17 4 12" />
                  </svg>
                  <span>Confirm & Issue Work Order</span>
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
