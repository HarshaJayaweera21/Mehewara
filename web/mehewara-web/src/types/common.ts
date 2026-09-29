export interface PagedResult<T> {
  items: T[];
  page: number;
  pageSize: number;
  totalItems: number;
  totalPages: number;
  hasNextPage?: boolean;
  hasPreviousPage?: boolean;
  sortBy?: string;
  sortDirection?: string;
}

export interface ApiError {
  error: {
    code: string;
    message: string;
    details?: string[];
  };
}
