# Allixios Microservices

This directory contains all microservices for the Allixios platform. Each service is designed to be independently deployable and scalable.

## Services Overview

### Core Services

#### 1. Content Service (`content-service/`)
- **Port**: 3001
- **Purpose**: Content management, articles, media, SEO
- **Database**: PostgreSQL + MongoDB + Elasticsearch
- **Features**:
  - Article CRUD operations
  - Media management with variants
  - SEO optimization
  - Content workflow (draft → review → published)
  - Full-text search
  - Analytics integration
  - Multi-tenant support

#### 2. User Service (`user-service/`)
- **Port**: 3002
- **Purpose**: User authentication, authorization, profile management
- **Database**: PostgreSQL + Redis
- **Features**:
  - User registration/login
  - JWT token management
  - Role-based access control (RBAC)
  - Multi-factor authentication (MFA)
  - Password reset
  - Profile management
  - Tenant management

#### 3. Analytics Service (`analytics-service/`)
- **Port**: 3003
- **Purpose**: Data analytics, reporting, metrics
- **Database**: MongoDB + ClickHouse + Redis
- **Features**:
  - Real-time analytics
  - Custom dashboards
  - Performance metrics
  - User behavior tracking
  - Revenue analytics
  - A/B testing
  - Data export

#### 4. SEO Service (`seo-service/`)
- **Port**: 3004
- **Purpose**: SEO optimization, meta generation, sitemap
- **Database**: PostgreSQL + Redis
- **Features**:
  - Meta tag generation
  - Sitemap generation
  - SEO score analysis
  - Keyword optimization
  - Schema markup
  - Performance monitoring
  - Competitor analysis

#### 5. Translation Service (`translation-service/`)
- **Port**: 3005
- **Purpose**: Multi-language content management
- **Database**: PostgreSQL + Redis
- **Features**:
  - Content translation
  - Language detection
  - Translation memory
  - Quality scoring
  - Batch translation
  - AI-powered translation
  - Localization management

#### 6. Notification Service (`notification-service/`)
- **Port**: 3006
- **Purpose**: Email, SMS, push notifications
- **Database**: PostgreSQL + Redis + Queue
- **Features**:
  - Email campaigns
  - SMS notifications
  - Push notifications
  - Template management
  - Delivery tracking
  - A/B testing
  - Automation workflows

#### 7. Monetization Service (`monetization-service/`)
- **Port**: 3007
- **Purpose**: Revenue tracking, subscriptions, payments
- **Database**: PostgreSQL + Redis
- **Features**:
  - Subscription management
  - Payment processing
  - Revenue analytics
  - Affiliate tracking
  - Commission calculations
  - Payout management
  - Financial reporting

### Shared Libraries (`shared/`)

#### Common Utilities
- **Database connections**
- **Authentication middleware**
- **Logging utilities**
- **Validation schemas**
- **Error handling**
- **Metrics collection**
- **Configuration management**

## Architecture Patterns

### Communication
- **Synchronous**: REST APIs for real-time operations
- **Asynchronous**: Message queues (Redis/Bull) for background tasks
- **Event-driven**: Event bus for service coordination

### Data Management
- **Database per service**: Each service owns its data
- **CQRS**: Command Query Responsibility Segregation where needed
- **Event sourcing**: For audit trails and analytics

### Security
- **JWT tokens**: For authentication
- **API Gateway**: Rate limiting and request routing
- **Service mesh**: For internal communication security
- **Encryption**: At rest and in transit

### Monitoring
- **Health checks**: `/health` endpoint for each service
- **Metrics**: Prometheus metrics collection
- **Logging**: Structured logging with correlation IDs
- **Tracing**: Distributed tracing for request flows

## Development

### Prerequisites
- Node.js 18+
- Docker & Docker Compose
- PostgreSQL 15+
- MongoDB 7+
- Redis 7+
- Elasticsearch 8+

### Getting Started

1. **Install dependencies for all services**:
```bash
# Install dependencies for each service
cd content-service && npm install
cd ../user-service && npm install
cd ../analytics-service && npm install
# ... repeat for all services
```

2. **Start infrastructure**:
```bash
# From project root
docker-compose -f infrastructure/docker/docker-compose.yml up -d
```

3. **Run database migrations**:
```bash
# Run migrations for each service
cd content-service && npm run migrate
cd ../user-service && npm run migrate
# ... repeat for all services
```

4. **Start services in development**:
```bash
# Start all services (use separate terminals or process manager)
cd content-service && npm run dev
cd ../user-service && npm run dev
cd ../analytics-service && npm run dev
# ... repeat for all services
```

### Service URLs (Development)
- Content Service: http://localhost:3001
- User Service: http://localhost:3002
- Analytics Service: http://localhost:3003
- SEO Service: http://localhost:3004
- Translation Service: http://localhost:3005
- Notification Service: http://localhost:3006
- Monetization Service: http://localhost:3007

### API Documentation
Each service provides Swagger documentation at `/api-docs` endpoint:
- Content Service: http://localhost:3001/api-docs
- User Service: http://localhost:3002/api-docs
- etc.

## Deployment

### Docker
Each service includes a Dockerfile for containerization:
```bash
# Build service image
docker build -t allixios/content-service ./content-service

# Run service container
docker run -p 3001:3001 allixios/content-service
```

### Kubernetes
Kubernetes manifests are available in `/infrastructure/kubernetes/`:
```bash
# Deploy all services
kubectl apply -f infrastructure/kubernetes/
```

### CI/CD
GitHub Actions workflows handle:
- Automated testing
- Security scanning
- Docker image building
- Deployment to staging/production

## Monitoring & Observability

### Health Checks
- **Liveness**: `/health/live` - Service is running
- **Readiness**: `/health/ready` - Service is ready to accept traffic
- **Health**: `/health` - Detailed health status

### Metrics
- **Application metrics**: Custom business metrics
- **System metrics**: CPU, memory, disk usage
- **Database metrics**: Connection pools, query performance
- **HTTP metrics**: Request rate, response time, error rate

### Logging
- **Structured logging**: JSON format with correlation IDs
- **Log levels**: ERROR, WARN, INFO, DEBUG
- **Log aggregation**: Centralized logging with ELK stack

## Security

### Authentication & Authorization
- **JWT tokens**: Stateless authentication
- **Role-based access**: Fine-grained permissions
- **Multi-tenant**: Tenant isolation
- **API keys**: For service-to-service communication

### Data Protection
- **Encryption**: TLS 1.3 for transport, AES-256 for storage
- **Input validation**: Comprehensive request validation
- **SQL injection**: Parameterized queries
- **XSS protection**: Content sanitization

### Compliance
- **GDPR**: Data privacy and right to be forgotten
- **SOC 2**: Security controls and monitoring
- **PCI DSS**: Payment data protection (monetization service)

## Performance

### Caching
- **Redis**: Application-level caching
- **CDN**: Static asset delivery
- **Database**: Query result caching

### Optimization
- **Connection pooling**: Database connections
- **Compression**: Response compression
- **Minification**: Asset optimization
- **Lazy loading**: On-demand resource loading

### Scaling
- **Horizontal scaling**: Multiple service instances
- **Auto-scaling**: Based on CPU/memory metrics
- **Load balancing**: Request distribution
- **Database sharding**: For high-volume data

## Testing

### Unit Tests
```bash
# Run tests for a service
cd content-service && npm test
```

### Integration Tests
```bash
# Run integration tests
npm run test:integration
```

### Load Testing
```bash
# Run load tests
npm run test:load
```

## Contributing

1. Follow the established patterns in existing services
2. Add comprehensive tests for new features
3. Update documentation for API changes
4. Follow security best practices
5. Use conventional commit messages

## Support

For questions or issues:
- Create GitHub issues for bugs/features
- Check service logs for troubleshooting
- Review API documentation for usage
- Contact the development team for urgent issues