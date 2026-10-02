export const crewRoles = ['CREW_LEADER_DRAINAGE', 'CREW_LEADER_ROAD', 'CREW_LEADER_WASTE', 'CREW_LEADER_ELECTRICAL', 'CREW_LEADER_ENVIRONMENT'];
export const isCrewLeader = (role: string) => crewRoles.includes(role);
export const homeView = (role: string) => role === 'ADMIN' ? 'operations' : isCrewLeader(role) ? 'my-jobs' : 'reports';
