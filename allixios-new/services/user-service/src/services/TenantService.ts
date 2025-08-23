/**
 * Tenant Service
 * Multi-tenant management business logic
 */

import { v4 as uuidv4 } from 'uuid';
import { DatabaseManager } from '../database/DatabaseManager';
import { logger, logAudit } from '../utils/logger';
import { Tenant } from '../types';

export class TenantService {

  /**
   * Get tenants with pagination and filtering
   */
  async getTenants(options: {
    page?: number;
    limit?: number;
    search?: string;
    status?: string;
  }) {
    const {
      page = 1,
      limit = 20,
      search,
      status
    } = options;

    // Build WHERE clause
    const conditions: string[] = [];
    const params: any[] = [];
    let paramIndex = 1;

    if (status) {
      conditions.push(`status = $${paramIndex++}`);
      params.push(status);
    }

    if (search) {
      conditions.push(`(name ILIKE $${paramIndex} OR slug ILIKE $${paramIndex} OR domain ILIKE $${paramIndex})`);
      params.push(`%${search}%`);
      paramIndex++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const offset = (page - 1) * limit;

    // Get total count
    const countQuery = `SELECT COUNT(*) as total FROM tenants ${whereClause}`;
    const countResult = await DatabaseManager.query(countQuery, params);
    const total = parseInt(countResult.rows[0].total);

    // Get tenants
    const tenantsQuery = `
      SELECT 
        t.*,
        u.email as owner_email,
        u.first_name as owner_first_name,
        u.last_name as owner_last_name
      FROM tenants t
      LEFT JOIN users u ON t.owner_id = u.id
      ${whereClause}
      ORDER BY t.created_at DESC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;
    params.push(limit, offset);

    const tenantsResult = await DatabaseManager.query(tenantsQuery, params);

    return {
      tenants: tenantsResult.rows,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
        hasNext: page * limit < total,
        hasPrev: page > 1,
      },
    };
  }

  /**
   * Get tenant by ID
   */
  async getTenantById(id: string): Promise<Tenant | null> {
    const query = `
      SELECT 
        t.*,
        u.email as owner_email,
        u.first_name as owner_first_name,
        u.last_name as owner_last_name
      FROM tenants t
      LEFT JOIN users u ON t.owner_id = u.id
      WHERE t.id = $1
    `;

    const result = await DatabaseManager.query(query, [id]);
    return result.rows[0] || null;
  }

  /**
   * Create new tenant
   */
  async createTenant(data: {
    name: string;
    slug?: string;
    domain?: string;
    owner_id: string;
    settings?: Record<string, any>;
  }, createdBy: string): Promise<Tenant> {
    // Generate slug if not provided
    const slug = data.slug || this.generateSlug(data.name);

    // Check if tenant with same name or slug exists
    const existingQuery = `
      SELECT id FROM tenants 
      WHERE name = $1 OR slug = $2 OR ($3 IS NOT NULL AND domain = $3)
    `;
    const existingResult = await DatabaseManager.query(existingQuery, [
      data.name,
      slug,
      data.domain
    ]);

    if (existingResult.rows.length > 0) {
      throw new Error('Tenant with this name, slug, or domain already exists');
    }

    // Verify owner exists
    const ownerQuery = `SELECT id FROM users WHERE id = $1`;
    const ownerResult = await DatabaseManager.query(ownerQuery, [data.owner_id]);
    
    if (ownerResult.rows.length === 0) {
      throw new Error('Owner user not found');
    }

    const tenantId = uuidv4();

    // Create tenant
    const insertQuery = `
      INSERT INTO tenants (
        id, name, slug, domain, logo_url, settings,
        owner_id, status
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, 'active'
      ) RETURNING *
    `;

    const result = await DatabaseManager.query(insertQuery, [
      tenantId,
      data.name,
      slug,
      data.domain,
      null, // logo_url
      JSON.stringify(data.settings || {}),
      data.owner_id
    ]);

    const tenant = result.rows[0];

    // Update owner's tenant_id
    await DatabaseManager.query(
      `UPDATE users SET tenant_id = $1, updated_at = NOW() WHERE id = $2`,
      [tenantId, data.owner_id]
    );

    // Create default roles for the tenant
    await this.createDefaultRoles(tenantId);

    // Assign owner role to the owner
    await this.assignOwnerRole(tenantId, data.owner_id, createdBy);

    logAudit('tenant_created', createdBy, {
      tenantId,
      tenantName: data.name,
      ownerId: data.owner_id,
    });

    return tenant;
  }

  /**
   * Update tenant
   */
  async updateTenant(
    id: string,
    data: {
      name?: string;
      domain?: string;
      logo_url?: string;
      settings?: Record<string, any>;
    },
    updatedBy: string
  ): Promise<Tenant> {
    const updateFields: string[] = [];
    const params: any[] = [];
    let paramIndex = 1;

    if (data.name !== undefined) {
      updateFields.push(`name = $${paramIndex++}`);
      params.push(data.name);
    }

    if (data.domain !== undefined) {
      updateFields.push(`domain = $${paramIndex++}`);
      params.push(data.domain);
    }

    if (data.logo_url !== undefined) {
      updateFields.push(`logo_url = $${paramIndex++}`);
      params.push(data.logo_url);
    }

    if (data.settings !== undefined) {
      updateFields.push(`settings = $${paramIndex++}`);
      params.push(JSON.stringify(data.settings));
    }

    updateFields.push(`updated_at = NOW()`);
    params.push(id);

    const query = `
      UPDATE tenants 
      SET ${updateFields.join(', ')}
      WHERE id = $${paramIndex}
      RETURNING *
    `;

    const result = await DatabaseManager.query(query, params);
    const tenant = result.rows[0];

    if (!tenant) {
      throw new Error('Tenant not found');
    }

    logAudit('tenant_updated', updatedBy, {
      tenantId: id,
      updatedFields: Object.keys(data),
    });

    return tenant;
  }

  /**
   * Update tenant status
   */
  async updateTenantStatus(
    id: string,
    status: 'active' | 'inactive' | 'suspended',
    updatedBy: string,
    reason?: string
  ): Promise<Tenant> {
    const query = `
      UPDATE tenants 
      SET status = $1, updated_at = NOW()
      WHERE id = $2
      RETURNING *
    `;

    const result = await DatabaseManager.query(query, [status, id]);
    const tenant = result.rows[0];

    if (!tenant) {
      throw new Error('Tenant not found');
    }

    logAudit('tenant_status_changed', updatedBy, {
      tenantId: id,
      newStatus: status,
      reason,
    });

    return tenant;
  }

  /**
   * Get tenant users
   */
  async getTenantUsers(tenantId: string) {
    const query = `
      SELECT 
        u.id, u.email, u.username, u.first_name, u.last_name,
        u.status, u.email_verified, u.mfa_enabled,
        u.last_login_at, u.created_at,
        COALESCE(
          JSON_AGG(
            CASE WHEN r.name IS NOT NULL THEN
              JSON_BUILD_OBJECT(
                'role_id', r.id,
                'role_name', r.name,
                'granted_at', ur.granted_at,
                'expires_at', ur.expires_at
              )
            END
          ) FILTER (WHERE r.name IS NOT NULL), 
          '[]'
        ) as roles
      FROM users u
      LEFT JOIN user_roles ur ON u.id = ur.user_id 
        AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
      LEFT JOIN roles r ON ur.role_id = r.id
      WHERE u.tenant_id = $1
      GROUP BY u.id, u.email, u.username, u.first_name, u.last_name,
               u.status, u.email_verified, u.mfa_enabled,
               u.last_login_at, u.created_at
      ORDER BY u.created_at DESC
    `;

    const result = await DatabaseManager.query(query, [tenantId]);
    return result.rows;
  }

  /**
   * Generate slug from name
   */
  private generateSlug(name: string): string {
    return name
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-')
      .trim();
  }

  /**
   * Create default roles for tenant
   */
  private async createDefaultRoles(tenantId: string): Promise<void> {
    const defaultRoles = [
      {
        name: 'owner',
        description: 'Tenant owner with full permissions',
        permissions: ['*'],
      },
      {
        name: 'admin',
        description: 'Tenant administrator',
        permissions: [
          'users:read', 'users:create', 'users:update', 'users:delete',
          'content:read', 'content:create', 'content:update', 'content:delete',
          'analytics:read', 'settings:read', 'settings:update'
        ],
      },
      {
        name: 'editor',
        description: 'Content editor',
        permissions: [
          'content:read', 'content:create', 'content:update',
          'analytics:read'
        ],
      },
      {
        name: 'viewer',
        description: 'Read-only access',
        permissions: [
          'content:read', 'analytics:read'
        ],
      },
    ];

    for (const role of defaultRoles) {
      const roleId = uuidv4();
      
      await DatabaseManager.query(
        `INSERT INTO roles (id, name, description, permissions, tenant_id, is_system)
         VALUES ($1, $2, $3, $4, $5, false)`,
        [
          roleId,
          role.name,
          role.description,
          JSON.stringify(role.permissions),
          tenantId
        ]
      );
    }
  }

  /**
   * Assign owner role to user
   */
  private async assignOwnerRole(tenantId: string, userId: string, grantedBy: string): Promise<void> {
    // Get owner role for this tenant
    const roleQuery = `
      SELECT id FROM roles 
      WHERE name = 'owner' AND tenant_id = $1
    `;
    const roleResult = await DatabaseManager.query(roleQuery, [tenantId]);
    
    if (roleResult.rows.length === 0) {
      throw new Error('Owner role not found');
    }

    const roleId = roleResult.rows[0].id;

    // Assign role
    await DatabaseManager.query(
      `INSERT INTO user_roles (user_id, role_id, tenant_id, granted_by)
       VALUES ($1, $2, $3, $4)`,
      [userId, roleId, tenantId, grantedBy]
    );
  }
}