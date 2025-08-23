/**
 * Health Check Routes
 * System health and readiness endpoints
 */

import { Router } from 'express';
import { DatabaseManager } from '../database/DatabaseManager';
import { config } from '../config';

const router = Router();

/**
 * Health check endpoint
 */
router.get('/', async (req, res) => {
  try {
    const dbHealth = await DatabaseManager.healthCheck();
    
    const status = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'user-service',
      version: '1.0.0',
      environment: config.nodeEnv,
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      database: dbHealth,
    };

    if (dbHealth.status !== 'healthy') {
      status.status = 'unhealthy';
      return res.status(503).json(status);
    }

    res.json(status);
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message,
    });
  }
});

/**
 * Readiness check endpoint
 */
router.get('/ready', async (req, res) => {
  try {
    const dbHealth = await DatabaseManager.healthCheck();
    
    const readiness = {
      ready: true,
      timestamp: new Date().toISOString(),
      checks: {
        database: dbHealth.status === 'healthy',
      },
    };

    if (!readiness.checks.database) {
      readiness.ready = false;
      return res.status(503).json(readiness);
    }

    res.json(readiness);
  } catch (error) {
    res.status(503).json({
      ready: false,
      timestamp: new Date().toISOString(),
      error: error.message,
    });
  }
});

/**
 * Liveness check endpoint
 */
router.get('/live', (req, res) => {
  res.json({
    alive: true,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

export { router as healthRouter };