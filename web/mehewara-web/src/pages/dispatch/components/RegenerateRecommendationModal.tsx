import React, { useState } from 'react';
import type { RecommendationListItem } from '../../../types/dispatch';
import { regenerateRecommendation } from '../../../services/dispatchApi';

interface RegenerateRecommendationModalProps {
  recommendation: RecommendationListItem;
  token: string;
  onClose: () => void;
  onSuccess: () => void;
}

export const RegenerateRecommendationModal: React.FC<RegenerateRecommendationModalProps> = ({
  recommendation,
  token,
  onClose,
  onSuccess,
}) => {
  const [feedback, setFeedback] = useState('');
  const [requestId] = useState(() => crypto.randomUUID());
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setErrorMessage(null);

    try {
      await regenerateRecommendation(token, recommendation.recommendationId, {
        reason: feedback.trim(),
        expectedRevision: recommendation.revision,
        requestId,
      });
      onSuccess();
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Failed to regenerate dispatch recommendation.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="dispatch-modal-backdrop" onClick={onClose}>
      <div className="dispatch-modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="dispatch-modal-header regenerate-header">
          <div className="dispatch-modal-title-wrap">
            <span className="dispatch-modal-tag tag-regenerate">Dispatch Optimization</span>
            <h3 className="dispatch-modal-title">Regenerate AI Recommendation</h3>
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
                <span className="summary-label">Current Priority</span>
                <span className={`summary-priority priority-${recommendation.priority.toLowerCase()}`}>
                  {recommendation.priority} ({recommendation.priorityScore}/100)
                </span>
              </div>
              <div className="summary-field">
                <span className="summary-label">Current Crew</span>
                <span className="summary-crew-name">
                  {recommendation.recommendedCrewName || 'None'}
                </span>
              </div>
            </div>
          </div>

          <p className="modal-description-subtle">
            Regeneration uses current Problem and crew information to produce a new recommendation, then validates it. You will review the result before approving dispatch.
          </p>

          <div className="dispatch-form-group">
            <label htmlFor="coordinator-feedback" className="dispatch-form-label">
              Reason and review feedback (required)
            </label>
            <textarea
              id="coordinator-feedback"
              rows={3}
              required
              maxLength={4000}
              className="dispatch-form-textarea"
              placeholder="Explain what should be reconsidered, such as an unavailable crew or an unsupported priority reason."
              value={feedback}
              onChange={(e) => setFeedback(e.target.value)}
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
              disabled={isSubmitting}
            >
              {isSubmitting ? (
                <>
                  <span className="dispatch-spinner-pip" />
                  Queuing review...
                </>
              ) : (
                'Regenerate Assessment'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
