# Super Content Batch Fetcher

An advanced, AI-powered edge function for intelligent content batch processing with comprehensive analytics, quality scoring, and system optimization.

## 🚀 Features

### **Intelligent Processing**
- **Dynamic Batch Sizing**: Automatically adjusts batch size based on queue depth, time of day, and system load
- **Quality Scoring**: Advanced scoring algorithm considering completeness, priority, age, and retry count
- **Content Strategy Analysis**: Automatic content type detection and strategy recommendations
- **AI Model Selection**: Intelligent selection of optimal AI models based on content characteristics

### **Advanced Queue Management**
- **Auto-Reset Stuck Topics**: Automatically identifies and resets topics stuck in processing
- **Content Diversity**: Ensures variety across niches, categories, and authors
- **Priority Boosting**: Age-based priority boosting with configurable thresholds
- **System Health Monitoring**: Real-time assessment of queue health and performance

### **Performance Optimization**
- **Multiple Performance Modes**: Standard, High, and Extreme modes with different batch size limits
- **Time-Based Optimization**: Adjusts processing based on business hours and peak times
- **Queue Pressure Adaptation**: Scales batch sizes based on queue depth
- **Comprehensive Analytics**: Detailed performance insights and metrics

## 📊 API Specification

### Request Interface
```typescript
interface FetchContentRequest {
  // Basic Configuration
  batch_size?: number                    // 1-50, default: 5
  worker_id?: string                     // Auto-generated if not provided
  priority_filter?: string[]             // ['urgent', 'high', 'medium', 'low']
  niche_filters?: string[]               // Array of niche UUIDs
  category_filters?: string[]            // Array of category UUIDs
  exclude_processing?: boolean           // Default: true
  debug_mode?: boolean                   // Default: false
  
  // Advanced Features
  intelligent_mode?: boolean             // Default: true
  performance_mode?: 'standard' | 'high' | 'extreme'  // Default: 'standard'
  auto_reset_stuck?: boolean             // Default: true
  stuck_threshold_minutes?: number       // Default: 30
  quality_scoring?: boolean              // Default: true
  include_analytics?: boolean            // Default: true
  
  // Content Diversity Configuration
  content_diversity?: {
    enabled: boolean                     // Default: true
    max_per_niche?: number              // Default: 3
    max_per_category?: number           // Default: 4
    max_per_author?: number             // Default: 2
  }
  
  // Priority Boost Configuration
  priority_boost?: {
    enabled: boolean                     // Default: true
    age_hours_threshold?: number         // Default: 12
    age_boost_factor?: number            // Default: 2
    retry_penalty_factor?: number        // Default: 5
  }
}
```

### Enhanced Topic Response
```typescript
interface EnhancedTopic {
  // Basic Fields
  id: string
  topic: string
  description: string | null
  target_keywords: string[]
  niche_id: string
  niche_name: string
  category_id: string | null
  category_name: string
  suggested_author_id: string | null
  author_name: string
  difficulty: string
  estimated_word_count: number
  estimated_reading_time: number
  priority: string
  ai_prompt: string | null
  metadata: Record<string, any>
  created_at: string
  retry_count: number
  hours_waiting: number
  processing_locked_by: string
  processing_locked_at: string
  
  // Enhanced Fields (when enabled)
  quality_score?: number                 // 0-100 quality assessment
  processing_priority_score?: number     // 0-100 processing priority
  content_strategy?: {
    content_type: 'article' | 'guide' | 'listicle' | 'comparison' | 'review'
    target_audience: string[]
    recommended_tone: string
    estimated_engagement: number         // 0-1 scale
  }
  optimal_ai_model?: string             // Recommended AI model
}
```

### Comprehensive Response
```typescript
interface SuperResponse {
  success: boolean
  
  // Batch Metadata
  batch_metadata: {
    batch_id: string
    worker_id: string
    batch_size: number
    requested_size: number
    optimal_size: number
    processing_started_at: string
    estimated_completion: string
    lock_expires_at: string
    performance_mode: string
    intelligent_mode: boolean
    total_word_count: number
    estimated_processing_minutes: number
  }
  
  // Enhanced Topics
  topics: EnhancedTopic[]
  
  // Queue Statistics
  queue_statistics: {
    total_available: number
    total_processing: number
    total_failed: number
    by_priority: Record<string, number>
    by_status: Record<string, number>
    average_wait_time_hours: number
    oldest_topic_hours: number
    stuck_items_count: number
  }
  
  // System Health Assessment
  system_health: {
    status: 'healthy' | 'degraded' | 'critical'
    recommended_batch_size: number
    recommended_workers: number
    queue_velocity_per_hour: number
    estimated_clear_time_hours: number
    warnings: string[]
    recommendations: string[]
  }
  
  // Processing Instructions
  processing_instructions: {
    lock_duration: string
    max_retries: number
    timeout_per_article: string
    success_callback_url: string
    error_callback_url: string
    quality_threshold: number
    monitoring_enabled: boolean
  }
  
  // Performance Insights (when analytics enabled)
  performance_insights?: {
    avg_quality_score: number
    avg_priority_score: number
    content_type_distribution: Record<string, number>
    difficulty_distribution: Record<string, number>
    niche_distribution: Record<string, number>
    estimated_total_reading_time: number
    batch_efficiency_score: number
  }
  
  // Debug Information (when debug mode enabled)
  debug_info?: {
    filters_applied: any
    processing_time_ms: number
    queue_state: Record<string, number>
    batch_optimization: any
    topic_selection_details: any[]
  }
}
```

## 🎯 Usage Examples

### Basic Intelligent Processing
```bash
curl -X POST https://your-project.supabase.co/functions/v1/super-fetch \
  -H "Authorization: Bearer YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "batch_size": 10,
    "intelligent_mode": true,
    "performance_mode": "high"
  }'
```

### High-Performance Mode with Custom Diversity
```bash
curl -X POST https://your-project.supabase.co/functions/v1/super-fetch \
  -H "Authorization: Bearer YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "batch_size": 20,
    "performance_mode": "extreme",
    "content_diversity": {
      "enabled": true,
      "max_per_niche": 5,
      "max_per_category": 6,
      "max_per_author": 3
    },
    "priority_boost": {
      "enabled": true,
      "age_hours_threshold": 6,
      "age_boost_factor": 3
    }
  }'
```

### Debug Mode with Full Analytics
```bash
curl -X POST https://your-project.supabase.co/functions/v1/super-fetch \
  -H "Authorization: Bearer YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "batch_size": 5,
    "debug_mode": true,
    "include_analytics": true,
    "quality_scoring": true,
    "auto_reset_stuck": true
  }'
```

## 🧠 Intelligent Features

### **Quality Scoring Algorithm**
- **Completeness (40 points)**: Description length, keywords, prompts, author assignment
- **Priority Scoring (20 points)**: Urgent=20, High=15, Medium=10, Low=5
- **Age Scoring (20 points)**: Older topics get priority boost
- **Retry Penalty (up to -15 points)**: Penalizes failed attempts
- **Word Count Bonus (5 points)**: Rewards comprehensive content

### **Dynamic Batch Sizing**
- **Time-Based**: Smaller batches during peak hours, larger during off-hours
- **Queue Pressure**: Scales with queue depth (>500 topics = larger batches)
- **Performance Mode**: Standard (max 10), High (max 20), Extreme (max 50)

### **Content Strategy Detection**
- **Article**: General content (default)
- **Guide**: Long-form educational content (>2000 words)
- **Comparison**: Contains "vs" or "compare"
- **Listicle**: Starts with numbers
- **Review**: Contains "review"

### **AI Model Selection**
- **claude-3-opus**: Long-form content (>3000 words)
- **gpt-4-turbo**: Technical or long content (>2000 words, high difficulty)
- **claude-3-sonnet**: Creative content
- **gemini-2.0-flash**: Default for most content

## 📈 System Health Monitoring

### **Health Status Levels**
- **Healthy**: Normal operation, <10% failed topics, reasonable queue depth
- **Degraded**: High processing load (>50% processing) or moderate failures
- **Critical**: High failure rate (>10%) or excessive queue depth (>1000)

### **Automatic Recommendations**
- Batch size optimization based on queue state
- Worker scaling recommendations
- Performance mode suggestions
- Queue management strategies

## 🔧 Performance Modes

### **Standard Mode**
- Max batch size: 10
- Conservative processing
- Balanced resource usage
- Recommended for normal operations

### **High Mode**
- Max batch size: 20
- Increased throughput
- Higher resource usage
- Recommended for queue backlogs

### **Extreme Mode**
- Max batch size: 50
- Maximum throughput
- High resource usage
- Recommended for emergency queue clearing

## 📊 Analytics & Monitoring

### **Workflow Metrics**
- Execution counts and success rates
- Average processing times
- Error rates and patterns
- Performance trends

### **Analytics Events**
- Detailed execution metadata
- System health snapshots
- Performance insights
- Quality score distributions

### **Dead Letter Queue**
- Comprehensive error logging
- Stack traces and context
- Retry patterns analysis
- System debugging support

## 🚀 Deployment

1. **Deploy to Supabase**:
   ```bash
   # Copy super.ts to supabase/functions/super-fetch/index.ts
   supabase functions deploy super-fetch
   ```

2. **Environment Variables**:
   - `SUPABASE_URL`: Your project URL
   - `SUPABASE_SERVICE_ROLE_KEY`: Service role key

3. **Database Dependencies**:
   - All tables from the main schema
   - Workflow metrics tables
   - Analytics events table
   - Dead letter queue table

## 🔍 Troubleshooting

### **No Topics Returned**
- Check queue status with debug mode
- Verify filter settings aren't too restrictive
- Enable auto-reset for stuck topics

### **Low Quality Scores**
- Review topic completeness (descriptions, keywords, prompts)
- Check author assignments
- Consider age-based priority boosting

### **Performance Issues**
- Monitor system health status
- Adjust performance mode based on load
- Scale workers based on recommendations

### **High Error Rates**
- Check dead letter queue for patterns
- Monitor workflow metrics
- Verify database connectivity

## 🎯 Best Practices

1. **Use intelligent mode** for optimal batch sizing
2. **Enable quality scoring** for better prioritization
3. **Configure content diversity** to ensure variety
4. **Monitor system health** regularly
5. **Use appropriate performance modes** based on load
6. **Enable analytics** for insights and optimization
7. **Set up monitoring** for dead letter queue and metrics

## 📝 Notes

- The function automatically handles stuck topic reset
- Quality scores are cached in topic metadata
- System health is assessed in real-time
- All operations are logged for monitoring
- Batch optimization happens automatically in intelligent mode