declare module 'pg' {
  export interface QueryResult<T = any> {
    rows: T[];
    rowCount?: number;
  }

  export class Pool {
    constructor(config: any);
    connect(): Promise<PoolClient>;
    query<T = any>(queryText: string, params?: readonly any[]): Promise<QueryResult<T>>;
    on(event: string, callback: (error: any) => void): void;
  }


  export class PoolClient {
    query<T = any>(queryText: string, params?: readonly any[]): Promise<{ rows: T[] }>;
    release(): void;
  }
}

