import React, { useState } from 'react';
import type { RecommendationListItem } from '../../../types/dispatch';
import { rejectRecommendation } from '../../../services/dispatchApi';

interface RejectRecommendationModalProps {
  recommendation: RecommendationListItem;
  token: string;
  onClose: () => void;
  onSuccess: () => void;
}

export const RejectRecommendationModal: React.FC<RejectRecommendationModalProps> = ({
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
    if (!reason.trim()) {
      setErrorMessage('A rejection reason is required for administrative audit trail.');
      return;
    }

    setIsSubmitting(true);
    setErrorMessage(null);

    try {
      await rejectRecommendation(token, recommendation.recommendationId, {
        reason: reason.trim(),
      });
      onSuccess();
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Failed to reject recommendation.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="dispatch-modal-backdrop" onClick={onClose}>
      <div className="dispatch-modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="dispatch-modal-header reject-header">
          <div className="dispatch-modal-title-wrap">
            <span className="dispatch-modal-tag tag-reject">Coordinator Rejection</span>
            <h3 className="dispatch-modal-title">Reject Dispatch Recommendation</h3>
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
                <span className="summary-label">Proposed Crew</span>
                <span className="summary-crew-name">
                  {recommendation.recommendedCrewName || 'None'}
                </span>
              </div>
            </div>
          </div>

          <p className="modal-description-subtle">
            Rejecting this recommendation marks it as <strong>REJECTED</strong>. No crew will be dispatched, and this action is permanently recorded for municipal compliance audit trails.
          </p>

          <div className="dispatch-form-group">
            <label htmlFor="rejection-reason" className="dispatch-form-label">
              Reason for Rejection <span className="required-star">*</span>
            </label>
            <textarea
              id="rejection-reason"
              rows={3}
              className="dispatch-form-textarea"
              placeholder="e.g. Requires preliminary environmental clearance before deployment; or crew reassigned to emergency ward."
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              required
            />
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
              className="dispatch-btn-danger"
              disabled={isSubmitting || !reason.trim()}
            >
              {isSubmitting ? (
                <>
                  <span className="dispatch-spinner-pip" />
                  Rejecting...
                </>
              ) : (
                'Confirm Rejection'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
