import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';
import { MemoryRouter } from 'react-router-dom';
import { OpsNavDrawer } from '../../src/components/common/OpsNavDrawer';

describe('OpsNavDrawer Component (Light Theme)', () => {
  it('renders all operations workflows and portal links when open', () => {
    const onClose = vi.fn();
    render(
      <MemoryRouter>
        <OpsNavDrawer
          isOpen={true}
          onClose={onClose}
          activePage="dashboard"
          pendingDispatchCount={5}
        />
      </MemoryRouter>
    );

    expect(screen.getByRole('dialog', { name: 'Operations Navigation Drawer' })).toBeInTheDocument();
    expect(screen.getByText('මෙහෙවර')).toBeInTheDocument();
    expect(screen.getByText('Operations Suite')).toBeInTheDocument();

    // Workflows
    expect(screen.getByRole('button', { name: /Operations Dashboard/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Problems Board/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Uncertain Reports/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Dispatch Queue/i })).toBeInTheDocument();
    // Verify Portals & Public / Resident Reports is completely removed for coordinators
    expect(screen.queryByRole('button', { name: /Resident Reports/i })).not.toBeInTheDocument();
    expect(screen.queryByText('Portals & Public')).not.toBeInTheDocument();

    // Check dispatch counter badge
    expect(screen.getByText('5')).toBeInTheDocument();

    // Check footer status
    expect(screen.getByText('Live Operations')).toBeInTheDocument();
    expect(screen.getByText('Coordinator')).toBeInTheDocument();
  });

  it('triggers onClose when close button is clicked', () => {
    const onClose = vi.fn();
    render(
      <MemoryRouter>
        <OpsNavDrawer
          isOpen={true}
          onClose={onClose}
          activePage="problems"
        />
      </MemoryRouter>
    );

    const closeBtn = screen.getByRole('button', { name: /Close navigation drawer/i });
    fireEvent.click(closeBtn);
    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it('calls navigation handler and closes drawer when a link is clicked', () => {
    const onClose = vi.fn();
    const onNavigateToDispatch = vi.fn();

    render(
      <MemoryRouter>
        <OpsNavDrawer
          isOpen={true}
          onClose={onClose}
          activePage="dashboard"
          onNavigateToDispatch={onNavigateToDispatch}
        />
      </MemoryRouter>
    );

    const dispatchBtn = screen.getByRole('button', { name: /Dispatch Queue/i });
    fireEvent.click(dispatchBtn);

    expect(onClose).toHaveBeenCalledTimes(1);
    expect(onNavigateToDispatch).toHaveBeenCalledTimes(1);
  });

  it('handles Escape key to close the drawer', () => {
    const onClose = vi.fn();
    render(
      <MemoryRouter>
        <OpsNavDrawer
          isOpen={true}
          onClose={onClose}
          activePage="dashboard"
        />
      </MemoryRouter>
    );

    fireEvent.keyDown(window, { key: 'Escape', code: 'Escape' });
    expect(onClose).toHaveBeenCalledTimes(1);
  });
});
