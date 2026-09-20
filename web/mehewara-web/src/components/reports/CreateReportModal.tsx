import React, { useState } from 'react';
import { uploadReportPhoto, createReport } from '../../services/reportApi';
import type { ReportResponse, ReportPhotoRequest } from '../../types/reports';
import { MapPicker } from '../common/MapPicker';

interface CreateReportModalProps {
  token: string;
  onClose: () => void;
  onSuccess: (report: ReportResponse) => void;
}

interface UploadedPhotoState extends ReportPhotoRequest {
  id: string;
  previewUrl: string;
  isUploading?: boolean;
}

const CATEGORIES = [
  { id: 'ROAD', label: 'Roads & Pavements', icon: '🛣️', desc: 'Potholes, broken curbs, damaged asphalt' },
  { id: 'DRAINAGE', label: 'Drainage & Flooding', icon: '🌊', desc: 'Blocked roadside drains, stagnant water, overflow' },
  { id: 'WASTE', label: 'Waste Management', icon: '🗑️', desc: 'Uncollected garbage, bin overflow, illegal dumping' },
  { id: 'ELECTRICAL', label: 'Electrical & Lighting', icon: '⚡', desc: 'Streetlights out, fallen cables, power hazards' },
  { id: 'ENVIRONMENT', label: 'Environment & Parks', icon: '🌳', desc: 'Overgrown trees, public park issues, pollution' },
];

const PRESET_LOCATIONS = [
  { name: 'Colombo Town Hall', lat: 6.9147, lng: 79.8656, address: 'F. R. Senanayake Mawatha, Colombo 07' },
  { name: 'Galle Face Green', lat: 6.9271, lng: 79.8454, address: 'Galle Road, Colombo 03' },
  { name: 'Kandy Clock Tower', lat: 7.2936, lng: 80.6350, address: 'Dalada Veediya, Kandy' },
  { name: 'Nugegoda Junction', lat: 6.8722, lng: 79.8997, address: 'High Level Road, Nugegoda' },
];

export const CreateReportModal: React.FC<CreateReportModalProps> = ({ token, onClose, onSuccess }) => {
  const [category, setCategory] = useState('ROAD');
  const [description, setDescription] = useState('');
  const [latitude, setLatitude] = useState<string>('6.9147');
  const [longitude, setLongitude] = useState<string>('79.8656');
  const [address, setAddress] = useState('F. R. Senanayake Mawatha, Colombo 07');

  const [photos, setPhotos] = useState<UploadedPhotoState[]>([]);
  const [uploadingCount, setUploadingCount] = useState(0);

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleApplyPreset = (preset: typeof PRESET_LOCATIONS[0]) => {
    setLatitude(preset.lat.toString());
    setLongitude(preset.lng.toString());
    setAddress(preset.address);
  };

  const handlePhotoFilesSelected = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    setError(null);
    const fileList = Array.from(files);

    for (const file of fileList) {
      if (file.size > 5 * 1024 * 1024) {
        setError(`File "${file.name}" exceeds 5MB limit.`);
        continue;
      }

      const tempId = Math.random().toString(36).substring(2);
      const localPreview = URL.createObjectURL(file);

      // Add temporary state
      setPhotos((prev) => [
        ...prev,
        {
          id: tempId,
          photoUrl: localPreview,
          previewUrl: localPreview,
          fileName: file.name,
          mimeType: file.type,
          isUploading: true,
        },
      ]);
      setUploadingCount((c) => c + 1);

      try {
        const uploaded = await uploadReportPhoto(token, file);
        setPhotos((prev) =>
          prev.map((p) =>
            p.id === tempId
              ? {
                  id: uploaded.photoId,
                  photoUrl: uploaded.photoUrl,
                  previewUrl: uploaded.photoUrl,
                  fileName: uploaded.fileName || file.name,
                  mimeType: uploaded.mimeType || file.type,
                  isUploading: false,
                }
              : p
          )
        );
      } catch (err: unknown) {
        setError(err instanceof Error ? err.message : `Failed to upload ${file.name}`);
        setPhotos((prev) => prev.filter((p) => p.id !== tempId));
      } finally {
        setUploadingCount((c) => Math.max(0, c - 1));
      }
    }

    e.target.value = '';
  };

  const handleRemovePhoto = (id: string) => {
    setPhotos((prev) => prev.filter((p) => p.id !== id));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    const latNum = parseFloat(latitude);
    const lngNum = parseFloat(longitude);

    if (isNaN(latNum) || latNum < -90 || latNum > 90) {
      setError('Please enter a valid Latitude between -90 and 90 degrees.');
      return;
    }

    if (isNaN(lngNum) || lngNum < -180 || lngNum > 180) {
      setError('Please enter a valid Longitude between -180 and 180 degrees.');
      return;
    }

    if (description.trim().length < 10) {
      setError('Description must be at least 10 characters long to provide sufficient detail.');
      return;
    }

    if (uploadingCount > 0) {
      setError('Please wait for photo uploads to finish before submitting.');
      return;
    }

    try {
      setIsSubmitting(true);

      const payload = {
        category,
        description: description.trim(),
        latitude: latNum,
        longitude: lngNum,
        address: address.trim() || undefined,
        photos: photos.map((p) => ({
          photoUrl: p.photoUrl,
          fileName: p.fileName,
          mimeType: p.mimeType,
        })),
      };

      const result = await createReport(token, payload);
      onSuccess(result);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to submit report.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div>
            <h2 className="modal-title">Submit New Municipal Report</h2>
            <p className="modal-subtitle">Report public infrastructure issues directly to the city council</p>
          </div>
          <button type="button" className="modal-close-btn" onClick={onClose} aria-label="Close">
            &times;
          </button>
        </div>

        {error && <div className="error-banner">{error}</div>}

        <form onSubmit={handleSubmit} className="report-form">
          {/* Category Picker */}
          <div className="form-section">
            <label className="section-label">1. Select Issue Category *</label>
            <div className="category-grid">
              {CATEGORIES.map((cat) => (
                <button
                  type="button"
                  key={cat.id}
                  className={`category-card-btn ${category === cat.id ? 'selected' : ''}`}
                  onClick={() => setCategory(cat.id)}
                >
                  <span className="cat-icon">{cat.icon}</span>
                  <div className="cat-text">
                    <span className="cat-name">{cat.label}</span>
                    <span className="cat-desc">{cat.desc}</span>
                  </div>
                </button>
              ))}
            </div>
          </div>

          {/* Description */}
          <div className="form-section">
            <label htmlFor="report-desc" className="section-label">
              2. Describe the Issue *
              <span className="char-count">({description.length}/2000 chars - min 10)</span>
            </label>
            <textarea
              id="report-desc"
              rows={4}
              className="form-textarea"
              placeholder="Provide specific details about the issue (e.g., Deep pothole causing damage to vehicles near the bus stand, approximately 2 feet wide...)"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              required
              minLength={10}
              maxLength={2000}
            />
          </div>

          {/* Location & Interactive Map Picker */}
          <div className="form-section">
            <label className="section-label">
              3. Pinpoint Location on Interactive Map *
              <span className="label-sub">(Click on the map or search — coordinates are picked automatically)</span>
            </label>

            <MapPicker
              initialLat={parseFloat(latitude) || 6.9271}
              initialLng={parseFloat(longitude) || 79.8612}
              onLocationSelect={(loc) => {
                setLatitude(loc.latitude.toString());
                setLongitude(loc.longitude.toString());
                setAddress(loc.address);
              }}
              height="280px"
            />

            {/* Quick Presets */}
            <div className="preset-chips" style={{ marginTop: '0.4rem' }}>
              <span className="preset-label">Quick Locations:</span>
              {PRESET_LOCATIONS.map((preset) => (
                <button
                  type="button"
                  key={preset.name}
                  className="preset-chip"
                  onClick={() => handleApplyPreset(preset)}
                >
                  {preset.name}
                </button>
              ))}
            </div>

            <div className="form-group" style={{ marginTop: '0.65rem' }}>
              <label htmlFor="report-address">Street Address / Landmark (Auto-filled from map, editable)</label>
              <input
                id="report-address"
                type="text"
                placeholder="e.g. Near St. Anthony's Church, Galle Road"
                value={address}
                onChange={(e) => setAddress(e.target.value)}
              />
            </div>
          </div>

          {/* Photo Upload to Cloudinary */}
          <div className="form-section">
            <label className="section-label">
              4. Evidence Photos
              <span className="label-sub"> (Uploaded to Cloudinary via backend)</span>
            </label>

            <div className="photo-upload-container">
              <label className="photo-dropzone">
                <input
                  type="file"
                  multiple
                  accept="image/png,image/jpeg,image/webp"
                  onChange={handlePhotoFilesSelected}
                  disabled={uploadingCount > 0}
                />
                <div className="dropzone-content">
                  <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
                    <polyline points="17 8 12 3 7 8"/>
                    <line x1="12" y1="3" x2="12" y2="15"/>
                  </svg>
                  <span>Click to select or drag photos</span>
                  <small>PNG, JPG, WEBP up to 5MB each</small>
                </div>
              </label>

              {uploadingCount > 0 && (
                <div className="uploading-indicator">
                  <span className="spinner"></span>
                  Uploading {uploadingCount} photo(s) to Cloudinary...
                </div>
              )}

              {photos.length > 0 && (
                <div className="photo-preview-grid">
                  {photos.map((p) => (
                    <div key={p.id} className="photo-preview-card">
                      <img src={p.previewUrl} alt="Report evidence" />
                      {p.isUploading && (
                        <div className="photo-uploading-overlay">
                          <span className="spinner"></span>
                        </div>
                      )}
                      <button
                        type="button"
                        className="photo-delete-btn"
                        onClick={() => handleRemovePhoto(p.id)}
                        title="Remove photo"
                      >
                        &times;
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          <div className="modal-footer">
            <button
              type="button"
              className="secondary-btn"
              onClick={onClose}
              disabled={isSubmitting}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="submit-btn"
              disabled={isSubmitting || uploadingCount > 0}
            >
              {isSubmitting ? (
                <>
                  <span className="spinner"></span> Submitting Report...
                </>
              ) : (
                'Submit Report to Council'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
