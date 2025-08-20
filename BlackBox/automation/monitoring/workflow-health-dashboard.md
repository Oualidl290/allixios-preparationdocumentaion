# 📊 Allixios Workflow Health Dashboard

## 🎯 Real-Time Monitoring Queries

### **1. Workflow Performance Overview**
```sql
-- Get real-time workflow performance metrics
SELECT 
  workflow_name,
  total_executions,
  successful_executions,
  failed_executions,
  success_rate || '%' as success_rate,
  ROUND(avg_duration_ms/1000, 2) || 's' as avg_duration,
  ROUND(p95_duration_ms/1000, 2) || 's' as p95_duration,
  last_execution,
  CASE 
    WHEN oldest_running IS NOT NULL 
    THEN EXTRACT(EPOCH FROM (NOW() - oldest_running))/60 || ' min ago'
    ELSE 'None'
  END as oldest_running_since
FROM n8n_workflow_performance
ORDER BY success_rate ASC, total_executions DESC;
```

### **2. API Usage & Cost Tracking**
```sql
-- Monitor API usage and costs across services
SELECT 
  service_name,
  total_requests,
  total_tokens,
  '$' || ROUND(total_cost_usd, 4) as total_cost,
  ROUND(total_cost_usd / NULLIF(total_requests, 0), 6) as cost_per_request,
  COALESCE(avg_rate_limit_remaining, 0) as rate_limit_remaining,
  last_window
FROM api_usage_summary
ORDER BY total_cost_usd DESC;
```

### **3. Content Generation Pipeline Health**
```sql
-- Detailed content pipeline analysis
SELECT 
  DATE(ne.started_at) as date,
  COUNT(*) as total_executions,
  COUNT(*) FILTER (WHERE ne.status = 'completed') as successful,
  COUNT(*) FILTER (WHERE ne.status = 'failed') as failed,
  COUNT(*) FILTER (WHERE ne.status = 'running') as currently_running,
  ROUND(AVG(ne.duration_ms) FILTER (WHERE ne.status = 'completed'), 0) as avg_duration_ms,
  
  -- Topic processing metrics
  COUNT(DISTINCT (ne.output_data->>'articles_created')::int) FILTER (WHERE ne.status = 'completed') as articles_created,
  
  -- Quality metrics
  AVG((ne.metrics->>'success_rate')::numeric) as avg_success_rate
FROM n8n_executions ne
WHERE ne.workflow_name = 'Content Generation Pipeline'
  AND ne.started_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(ne.started_at)
ORDER BY date DESC;
```

### **4. System Health Alerts**
```sql
-- Get current system health alerts
SELECT * FROM check_workflow_health();
```

### **5. Topic Processing Performance**
```sql
-- Analyze topic processing efficiency
SELECT 
  tq.status,
  COUNT(*) as count,
  AVG(EXTRACT(EPOCH FROM (NOW() - tq.created_at))/3600) as avg_age_hours,
  MAX(EXTRACT(EPOCH FROM (NOW() - tq.created_at))/3600) as oldest_hours,
  AVG(tq.retry_count) as avg_retries
FROM topics_queue tq
WHERE tq.created_at > NOW() - INTERVAL '24 hours'
GROUP BY tq.status
ORDER BY 
  CASE tq.status 
    WHEN 'failed' THEN 1 
    WHEN 'processing' THEN 2 
    WHEN 'queued' THEN 3 
    ELSE 4 
  END;
```

## 🚨 **Critical Alerts Setup**

### **Alert Conditions**
```sql
-- Create alert monitoring function
CREATE OR REPLACE FUNCTION get_critical_alerts()
RETURNS TABLE (
  alert_type TEXT,
  severity TEXT,
  message TEXT,
  count INTEGER,
  threshold INTEGER,
  action_required TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  
  -- High failure rate alert
  SELECT 
    'workflow_failure_rate'::TEXT,
    'CRITICAL'::TEXT,
    'Workflow ' || wp.workflow_name || ' has ' || wp.success_rate || '% success rate'::TEXT,
    wp.failed_executions::INTEGER,
    80::INTEGER,
    'Check workflow logs and fix issues immediately'::TEXT
  FROM n8n_workflow_performance wp
  WHERE wp.success_rate < 80 AND wp.total_executions > 5
  
  UNION ALL
  
  -- Long running executions
  SELECT 
    'long_running_execution'::TEXT,
    'HIGH'::TEXT,
    'Execution ' || ne.execution_id || ' running for ' || 
    ROUND(EXTRACT(EPOCH FROM (NOW() - ne.started_at))/60) || ' minutes'::TEXT,
    1::INTEGER,
    30::INTEGER,
    'Investigate stuck execution and consider manual intervention'::TEXT
  FROM n8n_executions ne
  WHERE ne.status = 'running' 
    AND ne.started_at < NOW() - INTERVAL '30 minutes'
  
  UNION ALL
  
  -- API rate limit warnings
  SELECT 
    'api_rate_limit'::TEXT,
    'MEDIUM'::TEXT,
    'Service ' || aus.service_name || ' has ' || aus.avg_rate_limit_remaining || ' requests remaining'::TEXT,
    aus.avg_rate_limit_remaining::INTEGER,
    100::INTEGER,
    'Monitor API usage and consider rate limiting'::TEXT
  FROM api_usage_summary aus
  WHERE aus.avg_rate_limit_remaining < 100
  
  UNION ALL
  
  -- Queue backlog alert
  SELECT 
    'queue_backlog'::TEXT,
    'HIGH'::TEXT,
    'Topics queue has ' || COUNT(*) || ' items pending for over 2 hours'::TEXT,
    COUNT(*)::INTEGER,
    50::INTEGER,
    'Scale up workers or investigate processing bottlenecks'::TEXT
  FROM topics_queue tq
  WHERE tq.status IN ('queued', 'pending')
    AND tq.created_at < NOW() - INTERVAL '2 hours'
  HAVING COUNT(*) > 50;
  
END;
$$;
```

## 📈 **Performance KPIs Dashboard**

### **Daily Metrics Summary**
```sql
-- Comprehensive daily performance summary
WITH daily_stats AS (
  SELECT 
    DATE(created_at) as date,
    COUNT(*) FILTER (WHERE status = 'published') as articles_published,
    COUNT(*) FILTER (WHERE status = 'draft') as articles_draft,
    AVG(content_score) as avg_content_quality,
    AVG(word_count) as avg_word_count,
    SUM(view_count) as total_views
  FROM articles
  WHERE created_at > NOW() - INTERVAL '30 days'
  GROUP BY DATE(created_at)
),
workflow_stats AS (
  SELECT 
    DATE(started_at) as date,
    COUNT(*) as total_executions,
    COUNT(*) FILTER (WHERE status = 'completed') as successful_executions,
    AVG(duration_ms) as avg_execution_time
  FROM n8n_executions
  WHERE started_at > NOW() - INTERVAL '30 days'
  GROUP BY DATE(started_at)
),
api_costs AS (
  SELECT 
    DATE(window_start) as date,
    SUM(cost_usd) as daily_api_cost,
    SUM(tokens_used) as daily_tokens
  FROM api_usage_metrics
  WHERE window_start > NOW() - INTERVAL '30 days'
  GROUP BY DATE(window_start)
)
SELECT 
  COALESCE(ds.date, ws.date, ac.date) as date,
  COALESCE(ds.articles_published, 0) as articles_published,
  COALESCE(ds.articles_draft, 0) as articles_draft,
  ROUND(COALESCE(ds.avg_content_quality, 0), 1) as avg_quality_score,
  ROUND(COALESCE(ds.avg_word_count, 0), 0) as avg_word_count,
  COALESCE(ds.total_views, 0) as total_views,
  COALESCE(ws.total_executions, 0) as workflow_executions,
  COALESCE(ws.successful_executions, 0) as successful_executions,
  ROUND(COALESCE(ws.avg_execution_time, 0)/1000, 1) as avg_execution_seconds,
  ROUND(COALESCE(ac.daily_api_cost, 0), 4) as api_cost_usd,
  COALESCE(ac.daily_tokens, 0) as tokens_used
FROM daily_stats ds
FULL OUTER JOIN workflow_stats ws ON ds.date = ws.date
FULL OUTER JOIN api_costs ac ON COALESCE(ds.date, ws.date) = ac.date
ORDER BY date DESC
LIMIT 30;
```

## 🔧 **Automated Health Checks**

### **Health Check Workflow (n8n)**
```javascript
// n8n Code Node for automated health monitoring
const healthCheck = await $http.request({
  method: 'POST',
  url: `${$env.SUPABASE_URL}/rest/v1/rpc/check_workflow_health`,
  headers: {
    'Authorization': `Bearer ${$env.SUPABASE_SERVICE_ROLE_KEY}`,
    'Content-Type': 'application/json'
  }
});

const alerts = healthCheck.data.alerts || [];
const criticalAlerts = alerts.filter(alert => alert.severity === 'high');

if (criticalAlerts.length > 0) {
  // Send Slack notification
  await $http.request({
    method: 'POST',
    url: $env.SLACK_WEBHOOK_URL,
    data: {
      text: `🚨 CRITICAL: ${criticalAlerts.length} workflow issues detected`,
      blocks: [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: `*Allixios System Health Alert*\n\n${criticalAlerts.map(alert => 
              `• *${alert.type}*: ${alert.message}`
            ).join('\n')}`
          }
        }
      ]
    }
  });
}

return {
  total_alerts: alerts.length,
  critical_alerts: criticalAlerts.length,
  alerts: alerts,
  health_status: criticalAlerts.length > 0 ? 'CRITICAL' : 'HEALTHY',
  timestamp: new Date().toISOString()
};
```

## 📊 **Grafana Dashboard Config**

### **Key Metrics Panels**
1. **Workflow Success Rate** (Time Series)
2. **API Cost Tracking** (Stat Panel)
3. **Content Generation Rate** (Bar Chart)
4. **Queue Health** (Gauge)
5. **Error Rate Trends** (Time Series)
6. **Processing Time Distribution** (Histogram)

### **Alert Rules**
- Workflow success rate < 80%
- Queue backlog > 100 items
- API costs > $10/day
- Long-running executions > 30 minutes
- Error rate > 10%

This monitoring setup gives you enterprise-level visibility into your automation pipeline! 🚀