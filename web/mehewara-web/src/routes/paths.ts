export const ROUTES = {
  HOME: '/',
  LOGIN: '/login',
  REGISTER: '/register',
  PROFILE: '/profile',
  OPERATIONS: '/operations',
  REPORTS: '/reports',
  PROBLEMS: '/problems',
  UNCERTAIN_REPORTS: '/problems/uncertain',
  DISPATCH: '/dispatch',
  CREWS: '/crews',
  WORK_ORDERS: '/work-orders',
  MY_JOBS: '/my-jobs',
} as const;

export type AppRoute = typeof ROUTES[keyof typeof ROUTES];
