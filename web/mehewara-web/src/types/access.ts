import { ROUTES } from '../routes/paths';

export const crewRoles = [
  'CREW_LEADER_DRAINAGE',
  'CREW_LEADER_ROAD',
  'CREW_LEADER_WASTE',
  'CREW_LEADER_ELECTRICAL',
  'CREW_LEADER_ENVIRONMENT',
];

export const isCrewLeader = (role?: string | null) => Boolean(role && crewRoles.includes(role));

export const getHomePathForRole = (role?: string | null): string => {
  if (role === 'ADMIN') return ROUTES.OPERATIONS;
  if (isCrewLeader(role)) return ROUTES.MY_JOBS;
  return ROUTES.REPORTS;
};

export const homeView = (role: string) => (role === 'ADMIN' ? 'operations' : isCrewLeader(role) ? 'my-jobs' : 'reports');
