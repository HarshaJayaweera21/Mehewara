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
  const [instructions, setInstructions] = useState(
    `Deploy to ${recommendation.problemTitle}. Implement standard municipal safety perimeter and execute ${recommendation.category} repairs.`
  );
  const [notes, setNotes] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setErrorMessage(null);

    try {
      const res = await approveRecommendation(token, recommendation.recommendationId, {
        instructions: instructions.trim(),
        notes: notes.trim() || undefined,
      });
      onSuccess(res.workOrderId);
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Approval failed. 10-point validation checklist blocked dispatch.');
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

          <div className="dispatch-form-group">
            <label htmlFor="instructions" className="dispatch-form-label">
              Work Order Instructions <span className="required-star">*</span>
            </label>
            <textarea
              id="instructions"
              rows={3}
              className="dispatch-form-textarea"
              value={instructions}
              onChange={(e) => setInstructions(e.target.value)}
              placeholder="Specify crew dispatch instructions..."
              required
            />
            <span className="dispatch-form-hint">
              These operational instructions are stored in the WorkOrder and displayed on the Crew Leader mobile terminal.
            </span>
          </div>

          <div className="dispatch-form-group">
            <label htmlFor="notes" className="dispatch-form-label">
              Internal Coordinator Approval Notes (Optional)
            </label>
            <input
              id="notes"
              type="text"
              className="dispatch-form-input"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="e.g., Authorized after reviewing stormwater drainage canal capacity"
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
              className="dispatch-btn-primary"
              disabled={isSubmitting || !instructions.trim()}
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
