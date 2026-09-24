import React, { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import './MapPicker.css';

// Fix default marker icon issue in modern bundlers
delete (L.Icon.Default.prototype as unknown as { _getIconUrl?: unknown })._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

// Custom pulsing pin icon
const customPinIcon = L.divIcon({
  className: 'custom-map-pin-container',
  html: `
    <div class="custom-map-pin">
      <div class="pin-head"></div>
      <div class="pin-pulse"></div>
    </div>
  `,
  iconSize: [30, 42],
  iconAnchor: [15, 42],
});

interface MapPickerProps {
  initialLat?: number;
  initialLng?: number;
  onLocationSelect: (location: { latitude: number; longitude: number; address: string }) => void;
  height?: string;
}

const SRI_LANKA_CENTER = { lat: 6.9271, lng: 79.8612 }; // Colombo default

export const MapPicker: React.FC<MapPickerProps> = ({
  initialLat = SRI_LANKA_CENTER.lat,
  initialLng = SRI_LANKA_CENTER.lng,
  onLocationSelect,
  height = '320px',
}) => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<L.Map | null>(null);
  const markerRef = useRef<L.Marker | null>(null);

  const [currentCoords, setCurrentCoords] = useState<{ lat: number; lng: number }>({
    lat: initialLat,
    lng: initialLng,
  });
  const [addressPreview, setAddressPreview] = useState<string>('Fetching location details...');
  const [isGeocoding, setIsGeocoding] = useState<boolean>(false);
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [isSearching, setIsSearching] = useState<boolean>(false);

  // Reverse geocode latitude and longitude into human-readable address
  const reverseGeocode = async (lat: number, lng: number) => {
    setIsGeocoding(true);
    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&zoom=18&addressdetails=1`,
        {
          headers: {
            'Accept-Language': 'en',
          },
        }
      );
      if (!res.ok) throw new Error('Failed to reverse geocode');
      const data = await res.json();
      const displayName = data.display_name || `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
      setAddressPreview(displayName);
      onLocationSelect({
        latitude: parseFloat(lat.toFixed(6)),
        longitude: parseFloat(lng.toFixed(6)),
        address: displayName,
      });
    } catch {
      const fallback = `Coordinates: ${lat.toFixed(5)}, ${lng.toFixed(5)}`;
      setAddressPreview(fallback);
      onLocationSelect({
        latitude: parseFloat(lat.toFixed(6)),
        longitude: parseFloat(lng.toFixed(6)),
        address: fallback,
      });
    } finally {
      setIsGeocoding(false);
    }
  };

  // Move marker & update
  const updatePosition = (lat: number, lng: number, zoomTo = false) => {
    setCurrentCoords({ lat, lng });

    if (markerRef.current) {
      markerRef.current.setLatLng([lat, lng]);
    } else if (mapInstanceRef.current) {
      markerRef.current = L.marker([lat, lng], {
        icon: customPinIcon,
        draggable: true,
      }).addTo(mapInstanceRef.current);

      markerRef.current.on('dragend', (e) => {
        const marker = e.target;
        const position = marker.getLatLng();
        updatePosition(position.lat, position.lng);
      });
    }

    if (zoomTo && mapInstanceRef.current) {
      mapInstanceRef.current.setView([lat, lng], 16);
    }

    reverseGeocode(lat, lng);
  };

  // Initialize Leaflet Map
  useEffect(() => {
    if (!mapContainerRef.current || mapInstanceRef.current) return;

    const map = L.map(mapContainerRef.current, {
      center: [initialLat, initialLng],
      zoom: 14,
      scrollWheelZoom: true,
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19,
    }).addTo(map);

    // Initial marker
    const marker = L.marker([initialLat, initialLng], {
      icon: customPinIcon,
      draggable: true,
    }).addTo(map);

    marker.on('dragend', (e) => {
      const pos = e.target.getLatLng();
      updatePosition(pos.lat, pos.lng);
    });

    // Map click event
    map.on('click', (e: L.LeafletMouseEvent) => {
      updatePosition(e.latlng.lat, e.latlng.lng);
    });

    mapInstanceRef.current = map;
    markerRef.current = marker;

    // Trigger initial geocode
    reverseGeocode(initialLat, initialLng);

    // Invalidate size after modal transition
    setTimeout(() => {
      map.invalidateSize();
    }, 200);

    return () => {
      map.remove();
      mapInstanceRef.current = null;
      markerRef.current = null;
    };
  }, []);

  // Handle GPS Locate Me
  const handleLocateMe = () => {
    if (!navigator.geolocation) {
      alert('Geolocation is not supported by your browser.');
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const { latitude, longitude } = pos.coords;
        updatePosition(latitude, longitude, true);
      },
      (err) => {
        alert(`Location detection failed: ${err.message}`);
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  };

  // Search places via Nominatim
  const handleSearchSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!searchQuery.trim()) return;

    try {
      setIsSearching(true);
      const query = encodeURIComponent(`${searchQuery}, Sri Lanka`);
      const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${query}&limit=1`);
      if (!res.ok) throw new Error('Search failed');
      const results = await res.json();

      if (results && results.length > 0) {
        const first = results[0];
        const lat = parseFloat(first.lat);
        const lng = parseFloat(first.lon);
        updatePosition(lat, lng, true);
      } else {
        alert(`Location "${searchQuery}" not found. Try clicking directly on the map.`);
      }
    } catch {
      alert('Location search failed. Please click directly on the map.');
    } finally {
      setIsSearching(false);
    }
  };

  return (
    <div className="map-picker-container">
      {/* Top Map Controls */}
      <div className="map-picker-controls">
        <form onSubmit={handleSearchSubmit} className="map-search-form">
          <input
            type="text"
            placeholder="Search town, street, landmark (e.g. Galle Face, Kandy)..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="map-search-input"
          />
          <button type="submit" className="map-search-btn" disabled={isSearching}>
            {isSearching ? 'Searching...' : '🔍 Search'}
          </button>
        </form>

        <button
          type="button"
          className="map-locate-me-btn"
          onClick={handleLocateMe}
          title="Zoom to my GPS location"
        >
          📍 Locate Me
        </button>
      </div>

      {/* Map Element */}
      <div
        ref={mapContainerRef}
        style={{ height, width: '100%', borderRadius: '10px', overflow: 'hidden' }}
        className="map-viewport"
      />

      {/* Dynamic Location Card */}
      <div className="map-selected-location-box">
        <div className="location-box-header">
          <span className="pin-indicator">📍 Selected Map Coordinates:</span>
          <span className="coords-display">
            <strong>{currentCoords.lat.toFixed(5)}</strong>, <strong>{currentCoords.lng.toFixed(5)}</strong>
          </span>
        </div>

        <div className="detected-address-row">
          <span className="address-label">Auto-Detected Address:</span>
          <span className="address-value">
            {isGeocoding ? (
              <span style={{ color: '#38bdf8' }}>Fetching street name from map...</span>
            ) : (
              addressPreview
            )}
          </span>
        </div>
        <div className="map-instructions">
          💡 Click anywhere on the map or drag the pin to position the exact location.
        </div>
      </div>
    </div>
  );
};
