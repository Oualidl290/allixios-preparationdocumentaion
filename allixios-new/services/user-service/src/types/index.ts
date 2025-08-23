/**
 * Type Definitions for User Service
 */

export interface User {
  id: string;
  email: string;
  username?: string;
  password_hash: string;
  first_name?: string;
  last_name?: string;
  avatar_url?: string;
  phone?: string;
  date_of_birth?: Date;
  timezone?: string;
  locale?: string;
  status: 'active' | 'inactive' | 'suspended' | 'pending_verification';
  email_verified: boolean;
  email_verified_at?: Date;
  phone_verified: boolean;
  phone_verified_at?: Date;
  mfa_enabled: boolean;
  mfa_secret?: string;
  last_login_at?: Date;
  last_login_ip?: string;
  login_attempts: number;
  locked_until?: Date;
  password_changed_at?: Date;
  tenant_id?: string;
  metadata?: Record<string, any>;
  created_at: Date;
  updated_at: Date;
}

export interface Tenant {
  id: string;
  name: string;
  slug: string;
  domain?: string;
  logo_url?: string;
  settings: Record<string, any>;
  subscription_plan?: string;
  subscription_status?: 'active' | 'inactive' | 'trial' | 'expired';
  subscription_expires_at?: Date;
  owner_id: string;
  status: 'active' | 'inactive' | 'suspended';
  created_at: Date;
  updated_at: Date;
}

export interface Role {
  id: string;
  name: string;
  description?: string;
  permissions: string[];
  tenant_id?: string;
  is_system: boolean;
  created_at: Date;
  updated_at: Date;
}

export interface UserRole {
  id: string;
  user_id: string;
  role_id: string;
  tenant_id?: string;
  granted_by: string;
  granted_at: Date;
  expires_at?: Date;
}

export interface Session {
  id: string;
  user_id: string;
  token_hash: string;
  refresh_token_hash?: string;
  device_info?: string;
  ip_address?: string;
  user_agent?: string;
  last_activity: Date;
  expires_at: Date;
  created_at: Date;
}

export interface AuditLog {
  id: string;
  user_id?: string;
  tenant_id?: string;
  action: string;
  resource_type?: string;
  resource_id?: string;
  old_values?: Record<string, any>;
  new_values?: Record<string, any>;
  ip_address?: string;
  user_agent?: string;
  created_at: Date;
}

export interface PasswordReset {
  id: string;
  user_id: string;
  token_hash: string;
  expires_at: Date;
  used_at?: Date;
  created_at: Date;
}

export interface EmailVerification {
  id: string;
  user_id: string;
  email: string;
  token_hash: string;
  expires_at: Date;
  verified_at?: Date;
  created_at: Date;
}

export interface LoginAttempt {
  id: string;
  email: string;
  ip_address: string;
  user_agent?: string;
  success: boolean;
  failure_reason?: string;
  created_at: Date;
}

// Request/Response Types
export interface RegisterRequest {
  email: string;
  password: string;
  first_name?: string;
  last_name?: string;
  username?: string;
  tenant_id?: string;
  metadata?: Record<string, any>;
}

export interface LoginRequest {
  email: string;
  password: string;
  mfa_code?: string;
  remember_me?: boolean;
}

export interface LoginResponse {
  user: Omit<User, 'password_hash' | 'mfa_secret'>;
  token: string;
  refresh_token?: string;
  expires_in: number;
  mfa_required?: boolean;
}

export interface UpdateProfileRequest {
  first_name?: string;
  last_name?: string;
  username?: string;
  phone?: string;
  date_of_birth?: string;
  timezone?: string;
  locale?: string;
  avatar_url?: string;
  metadata?: Record<string, any>;
}

export interface ChangePasswordRequest {
  current_password: string;
  new_password: string;
}

export interface ResetPasswordRequest {
  token: string;
  new_password: string;
}

export interface EnableMFAResponse {
  secret: string;
  qr_code: string;
  backup_codes: string[];
}

export interface VerifyMFARequest {
  code: string;
}

// Express Request Extensions
declare global {
  namespace Express {
    interface Request {
      id: string;
      startTime: number;
      user?: {
        id: string;
        email: string;
        tenantId?: string;
        roles: string[];
        permissions: string[];
      };
    }
  }
}