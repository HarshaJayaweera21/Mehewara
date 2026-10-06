import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';
import { ReportCard } from '../../../src/components/reports/ReportCard';
import type { ReportSummaryResponse } from '../../../src/types/reports';

const baseReport: ReportSummaryResponse = {
  id: 'rep-1',
  description: 'Deep pothole near the bus stand',
  category: 'ROAD',
  latitude: 6.9271,
  longitude: 79.8612,
  address: 'Main Street, Pettah',
  status: 'PENDING',
  linkedProblemCount: 0,
  createdAt: '2026-09-27T10:00:00Z',
};

describe('ReportCard Component (Member 1)', () => {
  it('renders category label, status pill, description and formatted address', () => {
    render(<ReportCard report={baseReport} onViewDetails={vi.fn()} />);

    expect(screen.getByText(/Roads & Pavements/)).toBeInTheDocument();
    expect(screen.getByText('PENDING')).toBeInTheDocument();
    expect(screen.getByText('Deep pothole near the bus stand')).toBeInTheDocument();
    expect(screen.getByText('Main Street, Pettah')).toBeInTheDocument();
  });

  it('falls back to latitude/longitude when no address is present', () => {
    render(<ReportCard report={{ ...baseReport, address: undefined }} onViewDetails={vi.fn()} />);

    expect(screen.getByText('6.9271, 79.8612')).toBeInTheDocument();
  });

  it('shows the no-photo placeholder when firstPhotoUrl is absent', () => {
    render(<ReportCard report={baseReport} onViewDetails={vi.fn()} />);

    expect(screen.getByAltText('No photo attached')).toBeInTheDocument();
    expect(screen.getByText('No photo')).toBeInTheDocument();
  });

  it('renders the uploaded photo thumbnail when firstPhotoUrl is present', () => {
    render(<ReportCard report={{ ...baseReport, firstPhotoUrl: 'https://cdn.example.com/pothole.jpg' }} onViewDetails={vi.fn()} />);

    const img = screen.getByAltText('ROAD') as HTMLImageElement;
    expect(img.src).toBe('https://cdn.example.com/pothole.jpg');
  });

  it('shows the linked-problem badge only when linkedProblemCount is greater than zero', () => {
    const { rerender } = render(<ReportCard report={baseReport} onViewDetails={vi.fn()} />);
    expect(screen.queryByText('Linked to Work Order')).not.toBeInTheDocument();

    rerender(<ReportCard report={{ ...baseReport, linkedProblemCount: 1 }} onViewDetails={vi.fn()} />);
    expect(screen.getByText('Linked to Work Order')).toBeInTheDocument();
  });

  it('calls onViewDetails with the report id when the details button is clicked', () => {
    const onViewDetails = vi.fn();
    render(<ReportCard report={baseReport} onViewDetails={onViewDetails} />);

    fireEvent.click(screen.getByRole('button', { name: /View Details & Tracking/ }));

    expect(onViewDetails).toHaveBeenCalledWith('rep-1');
  });
});
