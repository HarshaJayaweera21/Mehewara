import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import React from 'react';
import { CoordinatorWelcomeBanner } from '../../../src/components/problems/CoordinatorWelcomeBanner';

describe('CoordinatorWelcomeBanner Component (Member 2)', () => {
  it('renders default role name "Coordinator" and welcome heading', () => {
    render(<CoordinatorWelcomeBanner />);

    const heading = screen.getByRole('heading', { level: 1 });
    expect(heading).toBeDefined();
    expect(heading.textContent).toContain('Coordinator');
  });

  it('renders customized role name when passed via props', () => {
    render(<CoordinatorWelcomeBanner roleName="Lead Municipal Officer" />);

    const heading = screen.getByRole('heading', { level: 1 });
    expect(heading.textContent).toContain('Lead Municipal Officer');
  });

  it('contains accessible section with aria-label', () => {
    render(<CoordinatorWelcomeBanner />);

    const section = screen.getByLabelText('Coordinator Welcome Workspace');
    expect(section).toBeDefined();
  });
});
