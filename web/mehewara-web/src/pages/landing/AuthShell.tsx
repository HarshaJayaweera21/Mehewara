import type { ReactNode } from 'react';
import { Icon, mehewaraAssets } from '../../design-system/mehewara';
import './AuthShell.css';

interface AuthShellProps {
  mode: 'signin' | 'signup';
  onBack: () => void;
  onSwitch: () => void;
  children: ReactNode;
}

export function AuthShell({ mode, onBack, onSwitch, children }: AuthShellProps) {
  const isSignIn = mode === 'signin';

  return (
    <main className="auth-shell">
      <header className="auth-shell-header">
        <button type="button" className="auth-shell-logo" onClick={onBack} aria-label="Back to Mehewara home">
          <img src={mehewaraAssets.mehewaraLogoCompact} alt="Mehewara" width="520" height="144" />
        </button>
        <button type="button" className="auth-back-button" onClick={onBack}>
          Back to site <Icon name="arrow-right" size={16} />
        </button>
      </header>

      <section className="auth-shell-content" aria-labelledby="auth-page-heading">
        <span className="auth-page-kicker">Community portal</span>
        <h1 id="auth-page-heading">{isSignIn ? 'Log in to Mehewara' : 'Create your Mehewara account'}</h1>
        <p>{isSignIn ? 'Continue to your municipal services workspace.' : 'Report local concerns. Follow the response.'}</p>
        <div className="auth-shell-form">{children}</div>
        <div className="auth-switch-copy">
          {isSignIn ? 'New to Mehewara?' : 'Already have an account?'}
          <button type="button" onClick={onSwitch}>{isSignIn ? 'Create an account' : 'Log in'}</button>
        </div>
      </section>

      <footer className="auth-shell-footer">
        <span>© {new Date().getFullYear()} Mehewara Municipal Services</span>
        <span>Cleaner cities · Stronger communities</span>
      </footer>
    </main>
  );
}
