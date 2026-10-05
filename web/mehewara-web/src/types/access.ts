import { ROUTES } from '../routes/paths';

export const crewRoles = [
  'CREW_LEADER_DRAINAGE',
  'CREW_LEADER_ROAD',
  'CREW_LEADER_WASTE',
  'CREW_LEADER_ELECTRICAL',
  'CREW_LEADER_ENVIRONMENT',
];

export const isCrewLeader = (role?: string | null) =>
  Boolean(role && crewRoles.includes(role.toUpperCase()));

export const isCoordinator = (role?: string | null) => {
  const normalized = role?.toUpperCase();
  return normalized === 'ADMIN' || normalized === 'COORDINATOR';
};

export const isResident = (role?: string | null) => {
  const normalized = role?.toUpperCase();
  return normalized === 'RESIDENT';
};

export const getHomePathForRole = (role?: string | null): string => {
  const normalized = role?.toUpperCase();
  if (normalized === 'ADMIN' || normalized === 'COORDINATOR') return ROUTES.OPERATIONS;
  if (isCrewLeader(role)) return ROUTES.MY_JOBS;
  if (normalized === 'RESIDENT') return ROUTES.REPORTS;
  return ROUTES.REPORTS;
};

export const homeView = (role: string) =>
  isCoordinator(role) ? 'operations' : isCrewLeader(role) ? 'my-jobs' : 'reports';

