import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { getHomePathForRole } from '../../types/access';
import { ROUTES } from '../../routes/paths';
import './NotFoundPage.css';

export const NotFoundPage: React.FC = () => {
  const { currentUser, isAuthenticated } = useAuth();
  const navigate = useNavigate();

  const homePath = isAuthenticated && currentUser ? getHomePathForRole(currentUser.role) : ROUTES.HOME;

  return (
    <div className="not-found-container">
      <div className="not-found-card">
        <span className="not-found-code">404</span>
        <h1>Page Not Found</h1>
        <p>The municipal workspace or report route you requested does not exist or has been moved.</p>
        <div className="not-found-actions">
          <button type="button" onClick={() => navigate(-1)} className="btn-secondary">
            Go Back
          </button>
          <Link to={homePath} className="btn-primary">
            {isAuthenticated ? 'Return to Workspace' : 'Return to Home'}
          </Link>
        </div>
      </div>
    </div>
  );
};
