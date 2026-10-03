import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import React from 'react';
import { UncertainReportsPage } from '../../../src/pages/problems/UncertainReportsPage';
import * as problemApi from '../../../src/services/problemApi';
import type { UncertainReportResponse, ProblemResponse } from '../../../src/types/problems';

vi.mock('../../../src/components/common', () => ({
  Header: () => <div data-testid="mock-header">Header</div>,
}));

describe('Problem Form Validation Tests (Member 2)', () => {
  const mockUncertainReports: UncertainReportResponse[] = [
    {
      reportId: 'rep-test-01',
      description: 'Severe pipe rupture on Galle Road',
      category: 'DRAINAGE',
      latitude: 6.9100,
      longitude: 79.8500,
      address: 'Galle Road, Colombo 03',
      residentName: 'Kamal Perera',
      createdAt: '2026-03-29T10:00:00Z',
      aiUncertaintyReason: 'Conflicting category vs description',
      aiEvidence: ['Water pooling visible in gutter'],
      photoUrls: [],
      nearbyCandidates: [
        {
          problemId: 'prob-cand-01',
          title: 'Damaged Drainage System',
          category: 'DRAINAGE',
          address: 'Galle Road, Colombo 03',
          distanceMeters: 450,
          reportCount: 2,
        },
      ],
    },
  ];

  beforeEach(() => {
    vi.restoreAllMocks();
    vi.spyOn(problemApi, 'getUncertainReports').mockResolvedValue(mockUncertainReports);
  });

  it('Create Problem Form disables submit button when title is empty or whitespace', async () => {
    render(
      <UncertainReportsPage
        token="test-token"
        onNavigateToProblems={vi.fn()}
      />
    );

    // Wait for the report card description to render
    await waitFor(() => {
      expect(screen.getByText(/"Severe pipe rupture on Galle Road"/i)).toBeDefined();
    });

    // Click "+ Create New Problem" button to open modal
    const openCreateBtn = screen.getByRole('button', { name: /\+ Create New Problem/i });
    await act(async () => {
      fireEvent.click(openCreateBtn);
    });

    // Modal should now be open
    expect(screen.getByText('Create New Municipal Problem')).toBeDefined();

    const titleInput = screen.getByDisplayValue(/Issue at Galle Road, Colombo 03/i);
    const submitBtn = screen.getByRole('button', { name: /^Create Problem$/i });

    // Initially valid with pre-populated address title
    expect((submitBtn as HTMLButtonElement).disabled).toBe(false);

    // Clear title completely - submit must be disabled
    fireEvent.change(titleInput, { target: { value: '' } });
    expect((submitBtn as HTMLButtonElement).disabled).toBe(true);

    // Set title to whitespace only - submit must remain disabled
    fireEvent.change(titleInput, { target: { value: '    ' } });
    expect((submitBtn as HTMLButtonElement).disabled).toBe(true);

    // Enter a valid title - submit should be enabled
    fireEvent.change(titleInput, { target: { value: 'Ruptured Water Main Pipeline' } });
    expect((submitBtn as HTMLButtonElement).disabled).toBe(false);
  });

  it('Link Report Form validates that a target problem is selected', async () => {
    render(
      <UncertainReportsPage
        token="test-token"
        onNavigateToProblems={vi.fn()}
      />
    );

    await waitFor(() => {
      expect(screen.getByText(/"Severe pipe rupture on Galle Road"/i)).toBeDefined();
    });

    // Click "Link Here" next to candidate
    const linkHereBtn = screen.getByRole('button', { name: /link here/i });
    await act(async () => {
      fireEvent.click(linkHereBtn);
    });

    expect(screen.getByText('Link Report to Existing Problem')).toBeDefined();

    const problemSelect = screen.getByRole('combobox');
    const confirmBtn = screen.getByRole('button', { name: /confirm link/i });

    // When reset to empty selection - submit must be disabled
    fireEvent.change(problemSelect, { target: { value: '' } });
    expect((confirmBtn as HTMLButtonElement).disabled).toBe(true);

    // When selecting a problem candidate - submit must be enabled
    fireEvent.change(problemSelect, { target: { value: 'prob-cand-01' } });
    expect((confirmBtn as HTMLButtonElement).disabled).toBe(false);
  });

  it('Submits trimmed coordinator notes and validated form data', async () => {
    const mockProblemResponse: ProblemResponse = {
      id: 'prob-cand-01',
      title: 'Damaged Drainage System',
      description: 'Underground pipe rupture',
      category: 'DRAINAGE',
      latitude: 6.91,
      longitude: 79.85,
      address: 'Galle Road, Colombo 03',
      priority: 'HIGH',
      priorityScore: 80,
      status: 'IN_PROGRESS',
      relatedReportCount: 3,
      createdAt: '2026-03-29T08:00:00Z',
      updatedAt: '2026-03-29T08:00:00Z',
    };

    const linkSpy = vi.spyOn(problemApi, 'linkUncertainReport').mockResolvedValue(mockProblemResponse);

    render(
      <UncertainReportsPage
        token="test-token"
        onNavigateToProblems={vi.fn()}
      />
    );

    await waitFor(() => {
      expect(screen.getByText(/"Severe pipe rupture on Galle Road"/i)).toBeDefined();
    });

    const linkHereBtn = screen.getByRole('button', { name: /link here/i });
    await act(async () => {
      fireEvent.click(linkHereBtn);
    });

    const notesTextarea = screen.getByPlaceholderText(/explain why this report is linked/i);
    fireEvent.change(notesTextarea, { target: { value: '   Confirmed site duplicate by field inspection   ' } });

    const confirmBtn = screen.getByRole('button', { name: /confirm link/i });
    await act(async () => {
      fireEvent.click(confirmBtn);
    });

    expect(linkSpy).toHaveBeenCalledWith('test-token', {
      reportId: 'rep-test-01',
      problemId: 'prob-cand-01',
      coordinatorNotes: 'Confirmed site duplicate by field inspection',
    });
  });
});
