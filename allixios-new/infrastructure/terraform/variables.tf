# ============================================================================
# TERRAFORM VARIABLES
# Configuration variables for Allixios infrastructure
# ============================================================================

# ============================================================================
# GENERAL VARIABLES
# ============================================================================

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
  default     = "allixios-team"
}

# ============================================================================
# DOMAIN & DNS VARIABLES
# ============================================================================

variable "domain_name" {
  description = "Primary domain name for the application"
  type        = string
  default     = "allixios.com"
}

variable "create_dns_zone" {
  description = "Whether to create Route53 hosted zone"
  type        = bool
  default     = true
}

variable "cdn_domain_names" {
  description = "Domain names for CloudFront distribution"
  type        = list(string)
  default     = ["cdn.allixios.com", "media.allixios.com"]
}

variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate in ACM"
  type        = string
  default     = ""
}

# ============================================================================
# DATABASE VARIABLES
# ============================================================================

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 100
}

variable "db_password" {
  description = "Password for RDS database"
  type        = string
  sensitive   = true
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_auth_token" {
  description = "Auth token for Redis"
  type        = string
  sensitive   = true
}

# ============================================================================
# SECURITY VARIABLES
# ============================================================================

variable "jwt_secret" {
  description = "JWT secret key"
  type        = string
  sensitive   = true
}

variable "encryption_key" {
  description = "Encryption key for sensitive data"
  type        = string
  sensitive   = true
}

# ============================================================================
# AI SERVICE VARIABLES
# ============================================================================

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "google_ai_api_key" {
  description = "Google AI API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "anthropic_api_key" {
  description = "Anthropic API key"
  type        = string
  sensitive   = true
  default     = ""
}

# ============================================================================
# EMAIL VARIABLES
# ============================================================================

variable "smtp_password" {
  description = "SMTP password for email sending"
  type        = string
  sensitive   = true
  default     = ""
}

# ============================================================================
# CLOUDFLARE VARIABLES
# ============================================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
  default     = ""
}

# ============================================================================
# FEATURE FLAGS
# ============================================================================

variable "enable_monitoring" {
  description = "Enable monitoring stack (Prometheus, Grafana)"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable centralized logging (ELK stack)"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "enable_cdn" {
  description = "Enable CloudFront CDN"
  type        = bool
  default     = true
}

# ============================================================================
# SCALING VARIABLES
# ============================================================================

variable "min_nodes" {
  description = "Minimum number of EKS nodes"
  type        = number
  default     = 2
}

variable "max_nodes" {
  description = "Maximum number of EKS nodes"
  type        = number
  default     = 10
}

variable "desired_nodes" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 3
}

# ============================================================================
# COST OPTIMIZATION VARIABLES
# ============================================================================

variable "enable_spot_instances" {
  description = "Enable spot instances for cost optimization"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

# ============================================================================
# MONITORING VARIABLES
# ============================================================================

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = "alerts@allixios.com"
}

# ============================================================================
# DEVELOPMENT VARIABLES
# ============================================================================

variable "enable_debug_mode" {
  description = "Enable debug mode for development"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ============================================================================
# BACKUP VARIABLES
# ============================================================================

variable "backup_schedule" {
  description = "Cron expression for backup schedule"
  type        = string
  default     = "0 2 * * *"
}

variable "cross_region_backup" {
  description = "Enable cross-region backup replication"
  type        = bool
  default     = false
}

variable "backup_region" {
  description = "Region for cross-region backup replication"
  type        = string
  default     = "us-west-2"
}

# ============================================================================
# PERFORMANCE VARIABLES
# ============================================================================

variable "enable_performance_insights" {
  description = "Enable RDS Performance Insights"
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7
}

# ============================================================================
# SECURITY VARIABLES
# ============================================================================

variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest for all storage"
  type        = bool
  default     = true
}

variable "enable_encryption_in_transit" {
  description = "Enable encryption in transit"
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Enable AWS WAF for web application firewall"
  type        = bool
  default     = true
}

# ============================================================================
# COMPLIANCE VARIABLES
# ============================================================================

variable "enable_compliance_logging" {
  description = "Enable compliance logging for audit trails"
  type        = bool
  default     = true
}

variable "enable_access_logging" {
  description = "Enable access logging for load balancers"
  type        = bool
  default     = true
}

# ============================================================================
# DISASTER RECOVERY VARIABLES
# ============================================================================

variable "enable_multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
  default     = true
}

variable "enable_automated_backups" {
  description = "Enable automated backups for RDS"
  type        = bool
  default     = true
}

variable "backup_window" {
  description = "Backup window for RDS"
  type        = string
  default     = "03:00-06:00"
}

variable "maintenance_window" {
  description = "Maintenance window for RDS"
  type        = string
  default     = "Mon:00:00-Mon:03:00"
}