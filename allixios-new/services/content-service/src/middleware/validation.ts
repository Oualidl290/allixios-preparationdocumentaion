/**
 * Validation Middleware
 * Express validator middleware for request validation
 */

import { Request, Response, NextFunction } from 'express';
import { validationResult } from 'express-validator';

export const validateRequest = (req: Request, res: Response, next: NextFunction) => {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      message: 'The request contains invalid data.',
      details: errors.array().map(error => ({
        field: error.type === 'field' ? error.path : error.type,
        message: error.msg,
        value: error.type === 'field' ? error.value : undefined,
      })),
      meta: {
        requestId: req.id,
        timestamp: new Date().toISOString(),
      }
    });
  }
  
  next();
};