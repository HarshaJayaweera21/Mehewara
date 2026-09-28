import React, { useState, useEffect } from 'react';
import type { RecommendationListItem, PriorityLevel } from '../../../types/dispatch';
import type { CrewListItem } from '../../../types/crew';
import { editRecommendation } from '../../../services/dispatchApi';
import { getCrews } from '../../../services/crewApi';

interface EditRecommendationModalProps {
  recommendation: RecommendationListItem;
  token: string;
  onClose: () => void;
  onSuccess: (updated: RecommendationListItem) => void;
}

const PRIORITIES: PriorityLevel[] = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];

export const EditRecommendationModal: React.FC<EditRecommendationModalProps> = ({
  recommendation,
  token,
  onClose,
  onSuccess,
}) => {
  const [priority, setPriority] = useState<PriorityLevel>(recommendation.priority);
  const [priorityScore, setPriorityScore] = useState<number>(recommendation.priorityScore);
  const [selectedCrewId, setSelectedCrewId] = useState<string>(recommendation.recommendedCrewId || '');
  const [reason, setReason] = useState<string>(recommendation.recommendationReason);
  const [notes, setNotes] = useState<string>('');
  const [availableCrews, setAvailableCrews] = useState<CrewListItem[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isLoadingCrews, setIsLoadingCrews] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    let ignore = false;
    getCrews(token, { pageSize: 50 })
      .then((res) => {
        if (!ignore && res?.items) {
          setAvailableCrews(res.items);
        }
      })
      .catch((err) => {
        if (!ignore) {
          setErrorMessage(err instanceof Error ? err.message : 'Failed to load crews.');
        }
      })
      .finally(() => {
        if (!ignore) setIsLoadingCrews(false);
      });

    return () => {
      ignore = true;
    };
  }, [token]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setErrorMessage(null);

    try {
      const updated = await editRecommendation(token, recommendation.recommendationId, {
        priority,
        priorityScore,
        recommendedCrewId: selectedCrewId || undefined,
        recommendationReason: reason.trim(),
        notes: notes.trim() || undefined,
      });
      onSuccess(updated);
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Failed to update recommendation.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="dispatch-modal-backdrop" onClick={onClose}>
      <div className="dispatch-modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="dispatch-modal-header">
          <div className="dispatch-modal-title-wrap">
            <span className="dispatch-modal-tag">Human-in-the-Loop Override</span>
            <h3 className="dispatch-modal-title">Edit Recommendation & Reassign</h3>
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

          <div className="dispatch-form-group">
            <label className="dispatch-form-label">Priority Tier</label>
            <div className="priority-pill-selector">
              {PRIORITIES.map((p) => (
                <button
                  key={p}
                  type="button"
                  className={`priority-pill-btn priority-${p.toLowerCase()} ${priority === p ? 'active' : ''}`}
                  onClick={() => setPriority(p)}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>

          <div className="dispatch-form-group">
            <div className="score-label-row">
              <label htmlFor="priorityScore" className="dispatch-form-label">
                Priority Urgency Score (0 - 100)
              </label>
              <span className="score-display-pill">{priorityScore} / 100</span>
            </div>
            <input
              id="priorityScore"
              type="range"
              min="0"
              max="100"
              step="1"
              className="dispatch-score-slider"
              value={priorityScore}
              onChange={(e) => setPriorityScore(parseInt(e.target.value, 10))}
            />
          </div>

          <div className="dispatch-form-group">
            <label htmlFor="assignedCrew" className="dispatch-form-label">
              Assignee Municipal Crew
            </label>
            <select
              id="assignedCrew"
              className="dispatch-form-select"
              value={selectedCrewId}
              onChange={(e) => setSelectedCrewId(e.target.value)}
              disabled={isLoadingCrews}
            >
              <option value="">-- No Crew Selected (Deferred) --</option>
              {availableCrews.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name} ({c.crewType}) — [{c.status}]
                </option>
              ))}
            </select>
            <span className="dispatch-form-hint">
              Assigning a BUSY crew will be flagged by the 10-point deterministic validation engine.
            </span>
          </div>

          <div className="dispatch-form-group">
            <label htmlFor="reason" className="dispatch-form-label">
              Reasoning / Justification <span className="required-star">*</span>
            </label>
            <textarea
              id="reason"
              rows={3}
              className="dispatch-form-textarea"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="State the justification for this priority adjustment or reassignment..."
              required
            />
          </div>

          <div className="dispatch-form-group">
            <label htmlFor="editNotes" className="dispatch-form-label">
              Coordinator Audit Log Notes (Optional)
            </label>
            <input
              id="editNotes"
              type="text"
              className="dispatch-form-input"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="e.g., Coordinator manual override following site inspection"
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
              disabled={isSubmitting || !reason.trim()}
            >
              {isSubmitting ? (
                <>
                  <span className="dispatch-btn-spinner" />
                  <span>Saving Override...</span>
                </>
              ) : (
                <span>Save Overrides</span>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
