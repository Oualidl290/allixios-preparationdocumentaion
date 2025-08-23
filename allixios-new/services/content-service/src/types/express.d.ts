import { Request } from 'express';

declare global {
  namespace Express {
    interface Request {
      id: string;
      startTime: number;
      user?: {
        id: string;
        tenantId: string;
        authorId?: string;
        role: string;
        permissions: string[];
      };
      context: {
        requestId: string;
        userAgent?: string;
        ip: string;
        method: string;
        url: string;
      };
    }
  }
}