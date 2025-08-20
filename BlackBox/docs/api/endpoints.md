# 🚀 Allixios Edge Function Endpoints - Complete Reference

## 📋 **Overview**
This document details all Edge Function endpoints for the Allixios content management platform, including their specific purposes, parameters, and use cases.

---

## 👥 **Author Management**

### 1. `/upsert-authors-batch`
**Purpose**: Batch process and upsert multiple authors with intelligent entity resolution
**What it does**:
- Processes multiple author records simultaneously
- Resolves duplicate authors using name/email matching
- Creates user accounts if they don't exist
- Links authors to existing user profiles
- Handles social media profile extraction
- Updates author metadata and statistics

**Use Case**: When importing content from multiple sources or onboarding new content creators
**Input**: Array of author objects with name, email, bio, social links
**Output**: Array of created/updated author IDs with resolution status

### 23. `/upsert-authors-batch-v2`
**Purpose**: Enhanced version of author batch upsert with improved performance
**What it does**:
- All features of v1 plus:
- Better duplicate detection algorithms
- Bulk database operations for faster processing
- Enhanced error handling and rollback capabilities
- Support for author role assignments
- Integration with user permission system

**Use Case**: Large-scale author imports or migrations
**Input**: Enhanced author objects with role definitions
**Output**: Detailed processing report with success/failure metrics

---

## 🏷️ **Tag & Category Management**

### 3. `/upsert-tags-batch`
**Purpose**: Batch process tags with automated slug generation and hierarchy management
**What it does**:
- Creates/updates multiple tags simultaneously
- Generates SEO-friendly slugs automatically
- Establishes parent-child tag relationships
- Merges duplicate tags intelligently
- Updates tag usage statistics
- Creates tag synonyms and aliases

**Use Case**: Content taxonomy management, tag cleanup, or bulk tag operations
**Input**: Array of tag objects with names, descriptions, parent relationships
**Output**: Created tag IDs with generated slugs and hierarchy mappings

---

## 🎨 **Media & Content Generation**

### 4. `/generate-media-batch`
**Purpose**: Batch generate and process media assets for articles
**What it does**:
- Generates featured images using AI (DALL-E, Midjourney APIs)
- Creates multiple image variations and sizes
- Optimizes images for web performance
- Generates alt text and captions automatically
- Creates social media variants
- Stores media in Supabase Storage with CDN optimization

**Use Case**: Automated content illustration, social media asset creation
**Input**: Article titles, descriptions, style preferences
**Output**: Media URLs, metadata, and optimization reports

### 5. `/generate-translations-batch`
**Purpose**: Generate high-quality translations for articles using AI
**What it does**:
- Translates article content to multiple languages
- Preserves formatting and structure
- Maintains SEO metadata translations
- Handles technical terms and brand names
- Creates language-specific slugs
- Updates translation relationships in database

**Use Case**: Multi-language content expansion, international SEO
**Input**: Article IDs and target language codes
**Output**: Translation IDs with quality scores and completion status

---

## 📊 **SEO & Analytics**

### 6. `/initialize-seo-metrics`
**Purpose**: Initialize comprehensive SEO metrics and tracking for new content
**What it does**:
- Sets up SEO baseline metrics for articles
- Initializes keyword tracking
- Creates search console integration
- Sets up ranking monitoring
- Establishes competitor tracking
- Configures technical SEO audits

**Use Case**: New article SEO setup, SEO campaign initialization
**Input**: Article IDs, target keywords, competitor URLs
**Output**: SEO metric IDs with initial scores and tracking setup

### 13. `/apply-seo-optimizations`
**Purpose**: Apply AI-powered SEO optimization strategies to content
**What it does**:
- Analyzes content for SEO improvements
- Optimizes meta titles and descriptions
- Improves internal linking structure
- Enhances keyword density and placement
- Optimizes heading structure (H1-H6)
- Generates schema markup
- Creates XML sitemap updates

**Use Case**: Automated SEO improvement, content optimization campaigns
**Input**: Article IDs, target keywords, optimization preferences
**Output**: Optimization report with before/after metrics

### 17. `/fetch-seo-queue`
**Purpose**: Fetch articles that need SEO analysis and optimization
**What it does**:
- Identifies articles with poor SEO scores
- Prioritizes content based on traffic potential
- Filters by last optimization date
- Considers business priority and seasonality
- Returns optimized batch sizes for processing
- Includes current performance metrics

**Use Case**: SEO workflow automation, performance monitoring
**Input**: Batch size, priority filters, date ranges
**Output**: Prioritized list of articles needing SEO attention

### 22. `/update-seo-metrics`
**Purpose**: Update and process SEO-related performance metrics
**What it does**:
- Updates search ranking positions
- Processes Google Search Console data
- Calculates SEO score improvements
- Tracks keyword performance changes
- Updates competitor analysis data
- Generates SEO performance reports

**Use Case**: SEO performance tracking, ranking monitoring
**Input**: Article IDs, new metric data, time periods
**Output**: Updated SEO scores with trend analysis

---

## 💰 **Revenue & Monetization**

### 7. `/create-affiliate-links-smart`
**Purpose**: Intelligently create and manage affiliate links with optimization
**What it does**:
- Analyzes content for affiliate opportunities
- Creates contextually relevant affiliate links
- Manages multiple affiliate program integrations
- Tracks link performance and conversions
- A/B tests different link placements
- Handles link cloaking and tracking

**Use Case**: Automated monetization, affiliate marketing optimization
**Input**: Article content, product keywords, affiliate programs
**Output**: Generated affiliate links with tracking codes

### 12. `/apply-revenue-optimizations`
**Purpose**: Apply AI-powered revenue optimization strategies
**What it does**:
- Analyzes content for monetization opportunities
- Optimizes ad placements and formats
- Improves affiliate link positioning
- Tests different monetization strategies
- Personalizes offers based on user behavior
- Calculates revenue impact predictions

**Use Case**: Revenue maximization, monetization strategy testing
**Input**: Article IDs, current revenue data, optimization goals
**Output**: Optimization recommendations with projected revenue impact

### 16. `/fetch-revenue-analytics`
**Purpose**: Fetch and analyze comprehensive revenue-related metrics
**What it does**:
- Aggregates revenue data from multiple sources
- Calculates revenue per visitor (RPV)
- Analyzes conversion funnel performance
- Tracks affiliate commission earnings
- Monitors ad revenue and CTR
- Generates revenue forecasting models

**Use Case**: Revenue reporting, performance analysis, forecasting
**Input**: Date ranges, article filters, metric types
**Output**: Comprehensive revenue analytics with trends

### 21. `/update-revenue-metrics`
**Purpose**: Update and process revenue-related performance metrics
**What it does**:
- Updates real-time revenue tracking
- Processes affiliate conversion data
- Calculates lifetime value metrics
- Updates monetization efficiency scores
- Tracks revenue attribution by traffic source
- Generates revenue optimization recommendations

**Use Case**: Revenue tracking, performance monitoring
**Input**: Revenue events, conversion data, attribution info
**Output**: Updated revenue metrics with performance insights

---

## 🧪 **A/B Testing & Experimentation**

### 8. `/setup-article-ab-tests`
**Purpose**: Set up and manage A/B tests for article optimization
**What it does**:
- Creates A/B test configurations for articles
- Sets up traffic splitting mechanisms
- Defines success metrics and goals
- Configures test duration and sample sizes
- Sets up statistical significance tracking
- Creates test variation management

**Use Case**: Content optimization, conversion rate testing
**Input**: Article IDs, test variations, success metrics
**Output**: A/B test IDs with configuration details

### 20. `/manage-ab-tests`
**Purpose**: Manage ongoing A/B tests and conclude experiments
**What it does**:
- Monitors A/B test performance in real-time
- Calculates statistical significance
- Determines winning variations
- Automatically concludes tests when significant
- Applies winning variations to live content
- Archives test results and learnings

**Use Case**: Test management, automated optimization
**Input**: Test IDs, performance thresholds, time limits
**Output**: Test results with winner declarations and recommendations

---

## 🔗 **Internal Linking & Structure**

### 9. `/generate-internal-links-ai`
**Purpose**: Generate intelligent internal links using AI semantic analysis
**What it does**:
- Analyzes content semantic relationships
- Identifies relevant internal linking opportunities
- Creates contextually appropriate anchor text
- Maintains optimal link density
- Avoids over-optimization penalties
- Updates existing content with new links

**Use Case**: SEO improvement, content discoverability, user engagement
**Input**: Article content, existing link structure, target articles
**Output**: Internal link recommendations with anchor text and placement

---

## 📈 **Analytics & Monitoring**

### 10. `/log-analytics-batch`
**Purpose**: Log and process batch analytics events efficiently
**What it does**:
- Processes large volumes of user interaction events
- Aggregates pageviews, engagement metrics
- Tracks user journey and behavior patterns
- Calculates bounce rates and session duration
- Updates real-time analytics dashboards
- Handles data deduplication and validation

**Use Case**: User behavior tracking, performance monitoring
**Input**: Batch of analytics events with timestamps and user data
**Output**: Processing confirmation with aggregated metrics

### 14. `/collect-system-metrics`
**Purpose**: Collect and analyze comprehensive system performance metrics
**What it does**:
- Monitors database performance and query times
- Tracks Edge Function execution metrics
- Analyzes API response times and error rates
- Monitors resource usage and scaling needs
- Collects user experience metrics
- Generates system health reports

**Use Case**: System monitoring, performance optimization, capacity planning
**Input**: Metric collection timeframes and system components
**Output**: Comprehensive system health report with recommendations

### 19. `/log-workflow-metrics`
**Purpose**: Log and track workflow performance metrics for optimization
**What it does**:
- Tracks n8n workflow execution times
- Monitors success/failure rates
- Analyzes bottlenecks and performance issues
- Calculates workflow efficiency metrics
- Tracks resource consumption
- Generates workflow optimization recommendations

**Use Case**: Workflow optimization, performance monitoring, debugging
**Input**: Workflow execution data, timing metrics, error logs
**Output**: Workflow performance analysis with optimization suggestions

---

## 🔄 **Content Workflow Management**

### 11. `/update-topic-status`
**Purpose**: Update and manage workflow topic statuses throughout the content pipeline
**What it does**:
- Updates topic status in the content queue
- Manages workflow state transitions
- Handles error states and retry logic
- Tracks processing timestamps
- Manages worker assignments
- Prevents race conditions in topic processing

**Use Case**: Content workflow orchestration, queue management
**Input**: Topic IDs, new status values, worker information
**Output**: Status update confirmation with transition logs

### 15. `/fetch-content-batch-v2`
**Purpose**: Fetch and process content batches with advanced worker management
**What it does**:
- Implements intelligent batch sizing based on system load
- Manages worker assignments and load balancing
- Handles priority-based topic selection
- Implements retry logic for failed items
- Tracks processing metrics and performance
- Prevents duplicate processing with locking mechanisms

**Use Case**: Content generation workflow, batch processing optimization
**Input**: Batch size preferences, worker ID, priority filters
**Output**: Optimized content batch with processing metadata

### 18. `/insert-article-complete-v2`
**Purpose**: Complete article insertion with comprehensive processing and validation
**What it does**:
- Validates article data integrity
- Generates SEO-optimized slugs
- Creates article relationships (tags, categories, authors)
- Initializes SEO and revenue tracking
- Sets up analytics tracking
- Triggers post-publication workflows
- Handles duplicate detection and merging

**Use Case**: Article publishing, content import, data migration
**Input**: Complete article objects with metadata and relationships
**Output**: Article IDs with processing status and validation results

---

## 🎯 **Performance Intelligence**

### 24. `/fetch-performance-data`
**Purpose**: Fetch comprehensive performance data across content, SEO, and revenue dimensions
**What it does**:
- Aggregates multi-dimensional performance metrics
- Combines content, SEO, and revenue analytics
- Calculates performance scores and rankings
- Identifies trends and anomalies
- Generates predictive insights
- Provides data for AI-powered recommendations

**Use Case**: Performance intelligence dashboard, predictive analytics, business intelligence
**Input**: Analysis parameters, time ranges, metric types
**Output**: Comprehensive performance dataset with intelligence insights

---

## 🛠️ **Utility Functions**

### 2. `/shared-utilities`
**Purpose**: Provide shared utility functions for other Edge Functions
**What it does**:
- Common database connection management
- Shared validation and sanitization functions
- Error handling and logging utilities
- Rate limiting and throttling mechanisms
- Authentication and authorization helpers
- Data transformation and formatting tools

**Use Case**: Code reusability, consistency across functions, performance optimization
**Input**: Various utility function calls
**Output**: Processed results based on utility function used

---

## 📊 **Usage Patterns & Best Practices**

### **High-Frequency Endpoints** (Called multiple times per hour):
- `/fetch-performance-data` - Performance monitoring
- `/log-analytics-batch` - User tracking
- `/update-topic-status` - Workflow management
- `/collect-system-metrics` - System monitoring

### **Medium-Frequency Endpoints** (Called daily/weekly):
- `/fetch-content-batch-v2` - Content generation
- `/apply-seo-optimizations` - SEO improvements
- `/update-seo-metrics` - SEO tracking
- `/update-revenue-metrics` - Revenue tracking

### **Low-Frequency Endpoints** (Called on-demand):
- `/generate-media-batch` - Asset creation
- `/generate-translations-batch` - Localization
- `/upsert-authors-batch` - Author management
- `/setup-article-ab-tests` - Experimentation

### **Performance Considerations**:
- Batch endpoints are optimized for processing 50-200 items
- Analytics endpoints use streaming for large datasets
- All endpoints implement proper error handling and retries
- Rate limiting prevents system overload
- Caching reduces database load for frequently accessed data

This comprehensive endpoint documentation provides the foundation for understanding how each function contributes to the overall Allixios content management and optimization ecosystem.