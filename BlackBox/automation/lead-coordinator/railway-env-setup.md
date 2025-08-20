# 🚂 Railway + n8n Environment Configuration

## Railway Dashboard Setup

### Core Variables (Required)
```bash
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...your_service_role_key

# AI API Keys
GEMINI_API_KEY=AIza...your_gemini_key
OPENAI_API_KEY=sk-...your_openai_key

# Coordinator Settings
MAX_CONCURRENT_WORKFLOWS=3
DAILY_BUDGET_USD=500
EXECUTION_TIMEOUT_MINUTES=10
N8N_INSTANCE_ID=railway-lead-coordinator
NODE_ENV=production
```

### Monitoring & Notifications
```bash
# Slack Integration (Optional)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T.../B.../...

# Performance Settings
GEMINI_RATE_LIMIT_PER_MINUTE=60
OPENAI_RATE_LIMIT_PER_MINUTE=50
DATABASE_CONNECTION_LIMIT=20
MEMORY_LIMIT_MB=2048
```

### Business Hours Configuration
```bash
# Timezone and Business Hours
TZ=America/New_York
BUSINESS_HOURS_START=9
BUSINESS_HOURS_END=17
PEAK_HOURS_START=10
PEAK_HOURS_END=16
```

### Railway-Specific Settings
```bash
# Railway Platform Settings
RAILWAY_ENVIRONMENT=production
PORT=5678
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=https
```

## Railway CLI Setup (Alternative)

### Install Railway CLI
```bash
npm install -g @railway/cli
railway login
```

### Set Variables via CLI
```bash
# Navigate to your project
railway link

# Set core variables
railway variables set SUPABASE_URL="https://your-project.supabase.co"
railway variables set SUPABASE_SERVICE_ROLE_KEY="eyJ...your_key"
railway variables set GEMINI_API_KEY="AIza...your_key"
railway variables set MAX_CONCURRENT_WORKFLOWS="3"
railway variables set DAILY_BUDGET_USD="500"
railway variables set N8N_INSTANCE_ID="railway-lead-coordinator"

# Set monitoring variables
railway variables set SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
railway variables set GEMINI_RATE_LIMIT_PER_MINUTE="60"
railway variables set DATABASE_CONNECTION_LIMIT="20"

# Set business hours
railway variables set BUSINESS_HOURS_START="9"
railway variables set BUSINESS_HOURS_END="17"
railway variables set TZ="America/New_York"
```

## Environment File Upload (Bulk Method)

### Create .env file
```bash
# Create environment file
cat > railway.env << 'EOF'
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...your_service_role_key
GEMINI_API_KEY=AIza...your_gemini_key
OPENAI_API_KEY=sk-...your_openai_key
MAX_CONCURRENT_WORKFLOWS=3
DAILY_BUDGET_USD=500
EXECUTION_TIMEOUT_MINUTES=10
N8N_INSTANCE_ID=railway-lead-coordinator
NODE_ENV=production
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
GEMINI_RATE_LIMIT_PER_MINUTE=60
OPENAI_RATE_LIMIT_PER_MINUTE=50
DATABASE_CONNECTION_LIMIT=20
MEMORY_LIMIT_MB=2048
TZ=America/New_York
BUSINESS_HOURS_START=9
BUSINESS_HOURS_END=17
PEAK_HOURS_START=10
PEAK_HOURS_END=16
RAILWAY_ENVIRONMENT=production
PORT=5678
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=https
EOF
```

### Upload via Railway CLI
```bash
# Upload all variables from file
railway variables set --from-file railway.env
```

## Validation Steps

### 1. Check Variables in Railway
```bash
# List all variables
railway variables

# Check specific variable
railway variables get SUPABASE_URL
```

### 2. Test in n8n
Create a test workflow with this code node:
```javascript
// Test Railway environment variables
const railwayVars = {
  supabaseUrl: $env.SUPABASE_URL,
  hasServiceKey: !!$env.SUPABASE_SERVICE_ROLE_KEY,
  hasGeminiKey: !!$env.GEMINI_API_KEY,
  maxConcurrent: $env.MAX_CONCURRENT_WORKFLOWS,
  dailyBudget: $env.DAILY_BUDGET_USD,
  instanceId: $env.N8N_INSTANCE_ID,
  timezone: $env.TZ,
  railwayEnv: $env.RAILWAY_ENVIRONMENT
};

return [{
  json: {
    status: 'RAILWAY_ENV_CHECK',
    variables: railwayVars,
    timestamp: new Date().toISOString(),
    platform: 'Railway'
  }
}];
```

## Railway-Specific Considerations

### Automatic Deployments
- Variables are applied on next deployment
- Use `railway up` to trigger redeploy after adding variables
- Or redeploy via Railway dashboard

### Environment Isolation
- Use different Railway services for staging/production
- Each service has its own environment variables
- Copy variables between environments as needed

### Secrets Management
- Railway automatically encrypts sensitive variables
- Use Railway's built-in secrets for API keys
- Never commit actual keys to your repository

## Troubleshooting

### Variables Not Loading
```bash
# Force redeploy
railway up --detach

# Check deployment logs
railway logs
```

### Connection Issues
```bash
# Test Supabase connection
curl -X POST "$SUPABASE_URL/rest/v1/rpc/check_system_health_comprehensive" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json"
```

### n8n Access Issues
- Ensure PORT=5678 is set
- Check N8N_HOST=0.0.0.0 for Railway compatibility
- Verify N8N_PROTOCOL=https for Railway domains