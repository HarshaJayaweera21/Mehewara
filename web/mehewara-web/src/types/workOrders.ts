export interface WorkOrderActivity {
  id: string; action: string; actorUserId: string; note: string | null; createdAt: string;
}
export interface WorkOrder {
  id: string; problemId: string; crewId: string; recommendationId: string | null;
  crewName: string; problemTitle: string; title: string; instructions: string | null;
  priority: string; status: string; latitude: number; longitude: number; address: string | null;
  assignedAt: string | null; startedAt: string | null; completedAt: string | null;
  completionNotes: string | null; createdAt: string; updatedAt: string; history: WorkOrderActivity[];
}
export interface WorkOrderQuery {
  page?: number; pageSize?: number; status?: string; priority?: string;
  crewId?: string; problemId?: string; from?: string; to?: string;
}
