# User Service

The User Service is a comprehensive authentication and user management microservice for the Allixios platform. It provides secure user registration, authentication, multi-factor authentication (MFA), role-based access control (RBAC), and multi-tenant support.

## Features

### 🔐 **Authentication & Security**
- **JWT-based authentication** with refresh tokens
- **Multi-factor authentication (MFA)** using TOTP
- **Password policies** with strength validation
- **Account lockout** protection against brute force attacks
- **Session management** with device tracking
- **Password history** to prevent reuse

### 👥 **User Management**
- **User registration** with email verification
- **Profile management** with customizable fields
- **Password reset** with secure token-based flow
- **Account status management** (active, inactive, suspended)
- **Audit logging** for all user actions

### 🏢 **Multi-Tenant Support**
- **Tenant isolation** with secure data separation
- **Tenant management** with owner assignment
- **Tenant-specific settings** and configurations
- **Cross-tenant administration** for super admins

### 🛡️ **Role-Based Access Control (RBAC)**
- **Flexible role system** with custom permissions
- **Hierarchical roles** with inheritance
- **Time-based role assignments** with expiration
- **Permission-based access control**

### 📊 **Monitoring & Observability**
- **Health checks** for system monitoring
- **Structured logging** with correlation IDs
- **Security event logging** for audit trails
- **Performance metrics** collection

## API Endpoints

### Authentication
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `POST /api/auth/logout` - User logout
- `POST /api/auth/refresh` - Refresh access token
- `POST /api/auth/forgot-password` - Request password reset
- `POST /api/auth/reset-password` - Reset password with token
- `POST /api/auth/verify-email` - Verify email address
- `POST /api/auth/resend-verification` - Resend verification email

### Profile Management
- `GET /api/profile` - Get current user profile
- `PUT /api/profile` - Update user profile
- `POST /api/profile/change-password` - Change password
- `GET /api/profile/sessions` - Get active sessions
- `DELETE /api/profile/sessions/:id` - Revoke session

### Multi-Factor Authentication
- `POST /api/profile/mfa/setup` - Setup MFA
- `POST /api/profile/mfa/verify` - Verify and enable MFA
- `POST /api/profile/mfa/disable` - Disable MFA
- `GET /api/profile/mfa/backup-codes` - Generate backup codes
- `GET /api/profile/mfa/status` - Get MFA status

### User Management (Admin)
- `GET /api/users` - List users with filtering
- `GET /api/users/:id` - Get user by ID
- `PATCH /api/users/:id/status` - Update user status
- `GET /api/users/:id/roles` - Get user roles
- `POST /api/users/:id/roles` - Assign role to user
- `DELETE /api/users/:id/roles/:roleId` - Remove role from user

### Tenant Management
- `GET /api/tenants` - List tenants (admin only)
- `POST /api/tenants` - Create new tenant (admin only)
- `GET /api/tenants/:id` - Get tenant details
- `PUT /api/tenants/:id` - Update tenant
- `PATCH /api/tenants/:id/status` - Update tenant status
- `GET /api/tenants/:id/users` - Get tenant users

### Health & Monitoring
- `GET /health` - Health check
- `GET /health/ready` - Readiness check
- `GET /health/live` - Liveness check

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure the following:

#### Database Configuration
```env
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=allixios
POSTGRES_USER=allixios_user
POSTGRES_PASSWORD=your_password
REDIS_URL=redis://localhost:6379
```

#### Authentication Configuration
```env
JWT_SECRET=your-super-secret-jwt-key-min-32-chars
JWT_EXPIRES_IN=24h
REFRESH_TOKEN_EXPIRES_IN=7d
BCRYPT_ROUNDS=12
```

#### Email Configuration
```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
EMAIL_FROM=noreply@yourdomain.com
```

#### Security Configuration
```env
MAX_LOGIN_ATTEMPTS=5
LOCKOUT_DURATION=900000
PASSWORD_MIN_LENGTH=8
PASSWORD_REQUIRE_UPPERCASE=true
```

## Database Schema

The service uses PostgreSQL with the following main tables:

### Users Table
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(50) UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(50),
  last_name VARCHAR(50),
  avatar_url TEXT,
  phone VARCHAR(20),
  date_of_birth DATE,
  timezone VARCHAR(50),
  locale VARCHAR(10),
  status user_status DEFAULT 'pending_verification',
  email_verified BOOLEAN DEFAULT FALSE,
  email_verified_at TIMESTAMP,
  phone_verified BOOLEAN DEFAULT FALSE,
  phone_verified_at TIMESTAMP,
  mfa_enabled BOOLEAN DEFAULT FALSE,
  mfa_secret VARCHAR(255),
  last_login_at TIMESTAMP,
  last_login_ip INET,
  login_attempts INTEGER DEFAULT 0,
  locked_until TIMESTAMP,
  password_changed_at TIMESTAMP DEFAULT NOW(),
  tenant_id UUID REFERENCES tenants(id),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Tenants Table
```sql
CREATE TABLE tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  slug VARCHAR(50) UNIQUE NOT NULL,
  domain VARCHAR(255) UNIQUE,
  logo_url TEXT,
  settings JSONB DEFAULT '{}',
  subscription_plan VARCHAR(50),
  subscription_status subscription_status DEFAULT 'trial',
  subscription_expires_at TIMESTAMP,
  owner_id UUID NOT NULL REFERENCES users(id),
  status tenant_status DEFAULT 'active',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Roles & Permissions
```sql
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) NOT NULL,
  description TEXT,
  permissions JSONB DEFAULT '[]',
  tenant_id UUID REFERENCES tenants(id),
  is_system BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  tenant_id UUID REFERENCES tenants(id),
  granted_by UUID NOT NULL REFERENCES users(id),
  granted_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP
);
```

## Development

### Prerequisites
- Node.js 18+
- PostgreSQL 15+
- Redis 7+

### Setup
1. **Install dependencies**:
   ```bash
   npm install
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Run database migrations**:
   ```bash
   npm run migrate
   ```

4. **Start development server**:
   ```bash
   npm run dev
   ```

### Testing
```bash
# Run tests
npm test

# Run tests with coverage
npm run test:coverage

# Run tests in watch mode
npm run test:watch
```

### Building
```bash
# Build for production
npm run build

# Start production server
npm start
```

## Docker

### Build Image
```bash
docker build -t allixios/user-service .
```

### Run Container
```bash
docker run -p 3002:3002 \
  -e POSTGRES_HOST=host.docker.internal \
  -e REDIS_URL=redis://host.docker.internal:6379 \
  -e JWT_SECRET=your-secret-key \
  allixios/user-service
```

### Docker Compose
```yaml
version: '3.8'
services:
  user-service:
    build: .
    ports:
      - "3002:3002"
    environment:
      - NODE_ENV=production
      - POSTGRES_HOST=postgres
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis
```

## Security Features

### Password Security
- **Bcrypt hashing** with configurable rounds
- **Password strength validation** with customizable policies
- **Password history** to prevent reuse
- **Secure password reset** with time-limited tokens

### Account Protection
- **Rate limiting** on authentication endpoints
- **Account lockout** after failed login attempts
- **IP-based tracking** for suspicious activity
- **Session management** with device fingerprinting

### Multi-Factor Authentication
- **TOTP-based MFA** using authenticator apps
- **Backup codes** for account recovery
- **QR code generation** for easy setup
- **Time-window validation** for code verification

### Data Protection
- **Input validation** and sanitization
- **SQL injection prevention** with parameterized queries
- **XSS protection** with output encoding
- **CSRF protection** with token validation

## Monitoring

### Health Checks
- **Liveness probe**: `/health/live`
- **Readiness probe**: `/health/ready`
- **Detailed health**: `/health`

### Logging
- **Structured JSON logging** with Winston
- **Correlation IDs** for request tracking
- **Security event logging** for audit trails
- **Performance metrics** for monitoring

### Metrics
- **Authentication metrics** (login success/failure rates)
- **User activity metrics** (registrations, logins)
- **Security metrics** (failed attempts, lockouts)
- **Performance metrics** (response times, throughput)

## API Documentation

Interactive API documentation is available at:
- **Development**: http://localhost:3002/api-docs
- **Swagger/OpenAPI** specification included

## Contributing

1. Follow the established code patterns
2. Add comprehensive tests for new features
3. Update documentation for API changes
4. Follow security best practices
5. Use conventional commit messages

## License

MIT License - see LICENSE file for details