import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';
import { MemoryRouter } from 'react-router-dom';
import { CrewListPage } from '../../src/pages/crews/CrewListPage';
import type { CrewListItem } from '../../src/types/crew';

const mockCrewsList: CrewListItem[] = [
  {
    id: 'crew-001',
    name: 'Drainage Rapid Response Unit Alpha',
    crewType: 'DRAINAGE',
    status: 'AVAILABLE',
    crewLeaderName: 'Sunil Perera',
    contactNumber: '+94 11 269 1111',
    description: 'Specialized in storm drain clogs and pump operation',
    currentLatitude: 6.9271,
    currentLongitude: 79.8612,
    activeWorkOrdersCount: 0,
    completedWorkOrdersCount: 14,
    createdAt: '2026-09-01T00:00:00Z',
  },
  {
    id: 'crew-002',
    name: 'Road Engineering Unit Beta',
    crewType: 'ROAD',
    status: 'BUSY',
    crewLeaderName: 'Nimal Bandara',
    contactNumber: '+94 11 269 2222',
    description: 'Asphalt paving and emergency pothole remediation',
    currentLatitude: 6.915,
    currentLongitude: 79.87,
    activeWorkOrdersCount: 2,
    completedWorkOrdersCount: 28,
    createdAt: '2026-09-01T00:00:00Z',
  },
];

const mockUser = {
  id: 'coord-1',
  name: 'Coordinator Silva',
  email: 'silva@colombo.gov.lk',
  role: 'COORDINATOR',
};

const reply = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

beforeEach(() => {
  localStorage.clear();
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('CrewListPage Tests (Member 3)', () => {
  it('renders crew directory with squads and status indicators', async () => {
    const fetcher = vi.fn(async (url: string) => {
      if (url.includes('/api/crews')) {
        return reply({
          items: mockCrewsList,
          totalItems: 2,
          totalPages: 1,
          page: 1,
          pageSize: 20,
        });
      }
      return reply({});
    });
    vi.stubGlobal('fetch', fetcher);

    render(
      <MemoryRouter>
        <CrewListPage currentUser={mockUser} token="mock-coord-token" />
      </MemoryRouter>
    );

    // Verify squads are listed
    expect(await screen.findByText('Drainage Rapid Response Unit Alpha')).toBeInTheDocument();
    expect(screen.getByText('Road Engineering Unit Beta')).toBeInTheDocument();

    // Verify category and operational statuses
    expect(screen.getAllByText('DRAINAGE').length).toBeGreaterThan(0);
    expect(screen.getAllByText('ROAD').length).toBeGreaterThan(0);
    expect(screen.getAllByText('AVAILABLE').length).toBeGreaterThan(0);
    expect(screen.getAllByText('BUSY').length).toBeGreaterThan(0);
  });

  it('filters crews by specialization select', async () => {
    const fetcher = vi.fn(async (url: string) => {
      if (url.includes('/api/crews')) {
        return reply({
          items: mockCrewsList,
          totalItems: 2,
          totalPages: 1,
          page: 1,
          pageSize: 20,
        });
      }
      return reply({});
    });
    vi.stubGlobal('fetch', fetcher);

    render(
      <MemoryRouter>
        <CrewListPage currentUser={mockUser} token="mock-coord-token" />
      </MemoryRouter>
    );

    await screen.findByText('Drainage Rapid Response Unit Alpha');

    // Change Specialization select filter
    const select = screen.getByLabelText('Filter by Specialization');
    fireEvent.change(select, { target: { value: 'DRAINAGE' } });

    await waitFor(() => {
      expect(
        fetcher.mock.calls.some(([url]) => (url as string).includes('crewType=DRAINAGE'))
      ).toBe(true);
    });
  });

  it('opens crew detail modal upon clicking a squad card', async () => {
    const fetcher = vi.fn(async (url: string) => {
      if (url.includes('/api/crews/crew-001')) {
        return reply(mockCrewsList[0]);
      }
      if (url.includes('/api/crews')) {
        return reply({
          items: mockCrewsList,
          totalItems: 2,
          totalPages: 1,
          page: 1,
          pageSize: 20,
        });
      }
      return reply({});
    });
    vi.stubGlobal('fetch', fetcher);

    render(
      <MemoryRouter>
        <CrewListPage currentUser={mockUser} token="mock-coord-token" />
      </MemoryRouter>
    );

    const crewCard = await screen.findByText('Drainage Rapid Response Unit Alpha');
    fireEvent.click(crewCard);

    // Detail modal should display crew information
    expect(await screen.findByText('Specialized in storm drain clogs and pump operation')).toBeInTheDocument();
  });
});
