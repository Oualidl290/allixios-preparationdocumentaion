/**
 * Health Check Routes
 * System health and readiness endpoints
 */

import { Router } from 'express';
import { DatabaseManager } from '../database/DatabaseManager';
import { RedisManager } from '../cache/RedisManager';
import { ElasticsearchManager } from '../search/ElasticsearchManager';
import { getMetrics } from '../middleware/metrics';
import { config } from '../config';

const router = Router();

/**
 * Health check endpoint
 */
router.get('/', async (req, res) => {
  try {
    const health = await DatabaseManager.healthCheck();
    
    const status = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'content-service',
      version: '1.0.0',
      environment: config.nodeEnv,
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      databases: health,
    };

    // Check if any database is unhealthy
    const isUnhealthy = Object.values(health).some((db: any) => db.status !== 'healthy');
    
    if (isUnhealthy) {
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
    // Check database connections
    const dbHealth = await DatabaseManager.healthCheck();
    
    const readiness = {
      ready: true,
      timestamp: new Date().toISOString(),
      checks: {
        database: dbHealth.postgresql.status === 'healthy' && dbHealth.mongodb.status === 'healthy',
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

/**
 * Metrics endpoint
 */
router.get('/metrics', getMetrics);

export { router as healthRouter };