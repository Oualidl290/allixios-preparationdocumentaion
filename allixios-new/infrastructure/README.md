# 🏗️ Allixios Infrastructure

Complete infrastructure setup for the Allixios platform with Docker, Kubernetes, Terraform, and CI/CD automation.

## 📁 Directory Structure

```
infrastructure/
├── 🐳 docker/                    # Docker & Docker Compose
│   ├── docker-compose.yml       # Complete development stack
│   ├── .env.example             # Environment variables template
│   ├── Dockerfile.base          # Base Docker image for services
│   └── init-scripts/            # Database initialization scripts
├── ☸️ kubernetes/               # Kubernetes manifests
│   ├── namespace.yaml           # Namespace definitions
│   ├── configmap.yaml          # Configuration management
│   ├── secrets.yaml            # Secrets management
│   └── deployments/            # Service deployments
├── 🌍 terraform/               # Infrastructure as Code
│   ├── main.tf                 # Main infrastructure definition
│   ├── variables.tf            # Configuration variables
│   ├── outputs.tf              # Infrastructure outputs
│   └── environments/           # Environment-specific configs
├── 🚀 ci-cd/                   # CI/CD pipelines
│   ├── github-actions.yml      # GitHub Actions workflow
│   ├── gitlab-ci.yml          # GitLab CI pipeline
│   └── jenkins/               # Jenkins pipeline configs
└── 📚 README.md               # This file
```

## 🚀 Quick Start

### 1. Development Environment (Docker Compose)

```bash
# Clone repository
git clone <repository-url>
cd allixios-new/infrastructure/docker

# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env

# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f api-gateway
```

### 2. Production Environment (Kubernetes + Terraform)

```bash
# Deploy infrastructure
cd ../terraform
terraform init
terraform plan -var-file="production.tfvars"
terraform apply

# Deploy applications
cd ../kubernetes
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
kubectl apply -f deployments/

# Verify deployment
kubectl get pods -n allixios
```

## 🐳 Docker Development Stack

### Services Included

| Service | Port | Description |
|---------|------|-------------|
| **PostgreSQL** | 5432 | Primary database |
| **MongoDB** | 27017 | Document store |
| **Redis** | 6379 | Caching layer |
| **Elasticsearch** | 9200 | Search engine |
| **ClickHouse** | 8123 | Analytics database |
| **API Gateway** | 3000 | Main API endpoint |
| **Content Service** | 3001 | Content management |
| **SEO Service** | 3002 | SEO optimization |
| **Analytics Service** | 3003 | Analytics processing |
| **User Service** | 3004 | User management |
| **Translation Service** | 3005 | Multi-language support |
| **Notification Service** | 3006 | Notifications |
| **n8n** | 5678 | Workflow automation |
| **Prometheus** | 9090 | Metrics collection |
| **Grafana** | 3007 | Metrics visualization |
| **Public Website** | 3008 | Public frontend |
| **Admin Dashboard** | 3009 | Admin interface |

### Docker Commands

```bash
# Start all services
docker-compose up -d

# Start specific service
docker-compose up -d postgres redis

# Scale services
docker-compose up -d --scale content-service=3

# View logs
docker-compose logs -f api-gateway

# Execute commands in container
docker-compose exec postgres psql -U allixios_user -d allixios

# Stop all services
docker-compose down

# Remove volumes (⚠️ Data loss!)
docker-compose down -v
```

## ☸️ Kubernetes Production Deployment

### Prerequisites

- Kubernetes cluster (EKS, GKE, AKS, or self-managed)
- kubectl configured
- Helm 3.x installed
- Docker images built and pushed to registry

### Deployment Steps

```bash
# 1. Create namespace
kubectl apply -f namespace.yaml

# 2. Create secrets (update with your values)
kubectl create secret generic allixios-secrets \
  --from-literal=POSTGRES_PASSWORD=your_password \
  --from-literal=REDIS_PASSWORD=your_password \
  --from-literal=JWT_SECRET=your_jwt_secret \
  --namespace=allixios

# 3. Apply configuration
kubectl apply -f configmap.yaml

# 4. Deploy databases
kubectl apply -f deployments/databases.yaml

# 5. Wait for databases to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=postgres -n allixios --timeout=300s

# 6. Deploy applications
kubectl apply -f deployments/api-gateway.yaml
kubectl apply -f deployments/

# 7. Verify deployment
kubectl get pods -n allixios
kubectl get services -n allixios
```

### Scaling Applications

```bash
# Scale API Gateway
kubectl scale deployment api-gateway --replicas=5 -n allixios

# Auto-scaling (HPA already configured)
kubectl get hpa -n allixios

# Check resource usage
kubectl top pods -n allixios
kubectl top nodes
```

## 🌍 Terraform Infrastructure

### AWS Resources Created

- **EKS Cluster** with managed node groups
- **RDS PostgreSQL** with Multi-AZ deployment
- **ElastiCache Redis** cluster
- **S3 Buckets** for media and backups
- **CloudFront CDN** for global content delivery
- **Application Load Balancer** with SSL termination
- **Route53** DNS management
- **VPC** with public/private subnets
- **Security Groups** and IAM roles
- **CloudWatch** logging and monitoring

### Terraform Commands

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="production.tfvars"

# Apply infrastructure
terraform apply -var-file="production.tfvars"

# Show outputs
terraform output

# Destroy infrastructure (⚠️ Destructive!)
terraform destroy -var-file="production.tfvars"
```

### Environment Files

Create environment-specific `.tfvars` files:

```hcl
# production.tfvars
environment = "production"
aws_region = "us-east-1"
domain_name = "allixios.com"
db_instance_class = "db.r5.large"
redis_node_type = "cache.r5.large"
min_nodes = 3
max_nodes = 20
desired_nodes = 5
```

## 🚀 CI/CD Pipeline

### GitHub Actions Workflow

The CI/CD pipeline includes:

1. **Code Quality** - ESLint, Prettier, TypeScript checks
2. **Security Scanning** - Snyk, CodeQL analysis
3. **Testing** - Unit, integration, and E2E tests
4. **Building** - Docker images for all services
5. **Infrastructure** - Terraform deployment
6. **Deployment** - Kubernetes rollout
7. **Migration** - Database schema updates
8. **Validation** - Health checks and performance tests
9. **Notification** - Slack and email alerts

### Required Secrets

Configure these secrets in your GitHub repository:

```bash
# AWS Credentials
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY

# Database Passwords
DB_PASSWORD
REDIS_AUTH_TOKEN

# Application Secrets
JWT_SECRET
ENCRYPTION_KEY

# AI API Keys
OPENAI_API_KEY
GOOGLE_AI_API_KEY
ANTHROPIC_API_KEY

# Email Configuration
SMTP_PASSWORD

# External Services
CLOUDFLARE_API_TOKEN
SNYK_TOKEN
CODECOV_TOKEN
SLACK_WEBHOOK
```

### Manual Deployment

```bash
# Trigger deployment via GitHub CLI
gh workflow run "Allixios CI/CD Pipeline" \
  --field environment=production

# Or via web interface
# Go to Actions tab → Select workflow → Run workflow
```

## 📊 Monitoring & Observability

### Prometheus Metrics

Access Prometheus at `http://localhost:9090` (development) or your production URL.

Key metrics monitored:
- Application performance (response times, error rates)
- Infrastructure health (CPU, memory, disk usage)
- Database performance (connections, query times)
- Business metrics (user registrations, content creation)

### Grafana Dashboards

Access Grafana at `http://localhost:3007` (development).

Pre-configured dashboards:
- **Application Overview** - High-level system health
- **Infrastructure Metrics** - Server and container metrics
- **Database Performance** - PostgreSQL, MongoDB, Redis metrics
- **Business Intelligence** - User engagement and revenue metrics

### Log Aggregation

Logs are collected from:
- Application services (structured JSON logs)
- Database query logs
- Infrastructure logs (Kubernetes events)
- Security audit logs

## 🔒 Security Configuration

### Network Security

- **VPC Isolation** - Private subnets for databases and services
- **Security Groups** - Restrictive firewall rules
- **WAF Protection** - Web Application Firewall for public endpoints
- **SSL/TLS** - End-to-end encryption

### Application Security

- **Secrets Management** - Kubernetes secrets and AWS Secrets Manager
- **RBAC** - Role-based access control
- **Image Scanning** - Container vulnerability scanning
- **Network Policies** - Kubernetes network segmentation

### Compliance

- **Audit Logging** - Complete audit trail
- **Data Encryption** - At rest and in transit
- **Backup Encryption** - Encrypted backups
- **Access Controls** - Multi-factor authentication

## 💰 Cost Optimization

### Development Environment

- **Single NAT Gateway** - Reduced networking costs
- **Spot Instances** - 70% cost savings for non-critical workloads
- **Resource Limits** - Prevent resource waste
- **Auto-shutdown** - Scheduled environment shutdown

### Production Environment

- **Reserved Instances** - 40-60% savings for predictable workloads
- **Auto Scaling** - Scale based on demand
- **Storage Optimization** - Lifecycle policies for S3 and EBS
- **Monitoring Alerts** - Cost anomaly detection

## 🔧 Troubleshooting

### Common Issues

#### Docker Compose Issues

```bash
# Port conflicts
docker-compose down
docker system prune -f
docker-compose up -d

# Database connection issues
docker-compose logs postgres
docker-compose exec postgres pg_isready

# Memory issues
docker system df
docker system prune -a
```

#### Kubernetes Issues

```bash
# Pod not starting
kubectl describe pod <pod-name> -n allixios
kubectl logs <pod-name> -n allixios

# Service not accessible
kubectl get endpoints -n allixios
kubectl describe service <service-name> -n allixios

# Resource constraints
kubectl top pods -n allixios
kubectl describe node
```

#### Terraform Issues

```bash
# State lock issues
terraform force-unlock <lock-id>

# Resource conflicts
terraform import <resource-type>.<name> <resource-id>

# Plan differences
terraform refresh
terraform plan -detailed-exitcode
```

### Health Checks

```bash
# Application health
curl http://localhost:3000/health

# Database connectivity
docker-compose exec postgres pg_isready
docker-compose exec mongodb mongosh --eval "db.adminCommand('ping')"
docker-compose exec redis redis-cli ping

# Kubernetes health
kubectl get pods -n allixios
kubectl get services -n allixios
kubectl get ingress -n allixios
```

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

## 🤝 Contributing

When modifying infrastructure:

1. **Test locally** with Docker Compose first
2. **Update documentation** for any changes
3. **Follow security best practices**
4. **Test in staging** before production
5. **Monitor deployment** and rollback if needed

---

*This infrastructure setup provides enterprise-grade scalability, security, and reliability for the Allixios platform.*