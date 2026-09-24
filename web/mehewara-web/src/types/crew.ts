/**
 * Municipal Crew Types & Contracts for Member 3
 */

export type CrewType = 'DRAINAGE' | 'ROAD' | 'WASTE' | 'ELECTRICAL' | 'ENVIRONMENT';

export type CrewStatus = 'AVAILABLE' | 'BUSY' | 'UNAVAILABLE';

export interface CrewListItem {
  id: string;
  name: string;
  crewType: CrewType;
  status: CrewStatus;
  crewLeaderUserId: string | null;
  activeWorkOrderId: string | null;
}

export interface CrewDetail extends CrewListItem {
  description: string | null;
  contactNumber: string | null;
  crewLeaderName: string | null;
}

export interface CrewQueryParams {
  page?: number;
  pageSize?: number;
  crewType?: string;
  status?: string;
  search?: string;
}

export interface CrewAvailabilityItem {
  id: string;
  name: string;
  crewType: CrewType;
  status: CrewStatus;
  activeWorkOrderId: string | null;
}

export interface CrewAvailabilityResponse {
  items: CrewAvailabilityItem[];
}
