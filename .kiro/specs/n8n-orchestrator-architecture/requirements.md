# Requirements Document

## Introduction

The current Allixios platform uses 4 independent n8n workflows that run on separate schedules (every 15min, 2hr, 4hr, 6hr), creating critical architectural problems including resource contention, race conditions, API rate limit violations, and impossible debugging scenarios. This specification defines the implementation of a Master Orchestrator Pattern that will replace the current chaotic multi-workflow approach with a centralized, intelligent, and scalable workflow architecture.

The new architecture will implement a hub-and-spoke model where a single Master Orchestrator Workflow runs every 5 minutes, making intelligent decisions about when and how to trigger specialized sub-workflows based on system health, resource availability, and business priorities.

## Requirements

### Requirement 1: Master Orchestrator Workflow

**User Story:** As a system administrator, I want a central orchestrator that intelligently manages all workflow execution, so that I can eliminate resource conflicts and ensure optimal system performance.

#### Acceptance Criteria

1. WHEN the system is running THEN the Master Orchestrator SHALL execute every 5 minutes with sub-second precision
2. WHEN the orchestrator runs THEN it SHALL evaluate system health, resource availability, and task priorities before making execution decisions
3. WHEN multiple tasks are pending THEN the orchestrator SHALL use a priority scoring algorithm (Priority × 10 + Age in minutes) to determine execution order
4. WHEN API rate limits are approaching THEN the orchestrator SHALL throttle or delay workflow execution to prevent violations
5. WHEN system resources are constrained THEN the orchestrator SHALL implement intelligent load balancing across available capacity
6. WHEN a sub-workflow fails THEN the orchestrator SHALL implement exponential backoff retry logic with a maximum of 3 attempts
7. WHEN the orchestrator detects system anomalies THEN it SHALL enter ERROR_RECOVERY state and implement appropriate recovery procedures

### Requirement 2: Intelligent Resource Management

**User Story:** As a cost-conscious operator, I want the system to automatically manage API usage and costs, so that I never exceed budget limits or rate restrictions.

#### Acceptance Criteria

1. WHEN checking AI API limits THEN the system SHALL monitor Gemini (60 req/min), OpenAI (50 req/min), and enforce a $500/day cost ceiling
2. WHEN database connections exceed 15 THEN the system SHALL queue new requests and implement connection pooling
3. WHEN memory usage exceeds 1.5GB THEN the system SHALL pause non-critical workflows and trigger garbage collection
4. WHEN API costs approach daily limits THEN the system SHALL automatically reduce batch sizes and increase intervals
5. WHEN resource availability changes THEN the system SHALL dynamically adjust workflow scheduling and execution parameters
6. WHEN multiple workflows compete for resources THEN the system SHALL implement fair scheduling with starvation prevention

### Requirement 3: State Machine and Execution Control

**User Story:** As a developer, I want complete visibility into workflow execution states and the ability to track end-to-end processing, so that I can debug issues and optimize performance.

#### Acceptance Criteria

1. WHEN any workflow executes THEN the system SHALL track states: IDLE → ANALYZING → DISPATCHING → MONITORING → COMPLETED/ERROR_RECOVERY
2. WHEN state transitions occur THEN the system SHALL log all changes with timestamps, context, and execution metadata
3. WHEN workflows are triggered THEN the system SHALL use webhook-based communication with 5-minute timeouts and guaranteed delivery
4. WHEN execution context is needed THEN the system SHALL maintain parent-child relationships between orchestrator and sub-workflow executions
5. WHEN errors occur THEN the system SHALL capture full stack traces, input parameters, and system state for debugging
6. WHEN workflows complete THEN the system SHALL execute callback webhooks to update orchestrator state and trigger next actions

### Requirement 4: Priority Queue Management

**User Story:** As a content manager, I want high-priority content to be processed first while ensuring no tasks are permanently starved, so that urgent content reaches publication quickly.

#### Acceptance Criteria

1. WHEN tasks are queued THEN the system SHALL implement a priority queue with scoring algorithm: (Priority × 10) + (Age in minutes)
2. WHEN tasks age beyond 30 minutes THEN the system SHALL apply age boost to prevent starvation
3. WHEN queue depth exceeds 1000 items THEN the system SHALL implement batch processing and parallel execution
4. WHEN tasks fail 5 times THEN the system SHALL move them to a dead letter queue for manual intervention
5. WHEN system load is high THEN the system SHALL limit concurrent sub-workflows to maximum of 3
6. WHEN fairness is required THEN the system SHALL ensure no single content type monopolizes processing resources

### Requirement 5: Sub-Workflow Integration Pattern

**User Story:** As a workflow designer, I want standardized sub-workflows that can be triggered reliably and report back consistently, so that I can build complex processing pipelines.

#### Acceptance Criteria

1. WHEN sub-workflows are triggered THEN they SHALL accept webhook calls with standardized input format and authentication
2. WHEN sub-workflows execute THEN they SHALL implement pre-flight checks, main processing, and callback reporting
3. WHEN Content Pipeline runs THEN it SHALL process 1-10 topics with entity resolution, AI generation, quality scoring, and publishing
4. WHEN SEO Monitor runs THEN it SHALL analyze batches of articles with parallel processing and optimization recommendations
5. WHEN Revenue Optimizer runs THEN it SHALL perform conversion analysis, A/B test management, and strategy updates
6. WHEN Intelligence Engine runs THEN it SHALL execute data aggregation, trend analysis, and predictive modeling
7. WHEN sub-workflows complete THEN they SHALL report execution results, metrics, and any errors back to the orchestrator

### Requirement 6: Database Schema for Orchestration

**User Story:** As a database administrator, I want a robust schema that tracks all workflow executions and enables comprehensive monitoring, so that I can ensure system reliability and performance.

#### Acceptance Criteria

1. WHEN the system initializes THEN it SHALL create workflow_orchestration table with execution tracking fields
2. WHEN executions start THEN the system SHALL record execution_id, workflow_type, priority, and context
3. WHEN state changes occur THEN the system SHALL update status, timestamps, and execution metadata
4. WHEN errors happen THEN the system SHALL store error details, retry counts, and recovery actions
5. WHEN parent-child relationships exist THEN the system SHALL maintain referential integrity with parent_execution_id
6. WHEN querying execution history THEN the system SHALL support filtering by status, workflow type, and time ranges
7. WHEN cleanup is needed THEN the system SHALL implement automatic archival of executions older than 30 days

### Requirement 7: Monitoring and Alerting System

**User Story:** As a system operator, I want comprehensive monitoring and intelligent alerting, so that I can proactively address issues before they impact content production.

#### Acceptance Criteria

1. WHEN system metrics are collected THEN the system SHALL track throughput, latency, success rates, and cost per article
2. WHEN thresholds are exceeded THEN the system SHALL send alerts for API limits, error rates, and budget overruns
3. WHEN performance degrades THEN the system SHALL automatically adjust batch sizes and execution intervals
4. WHEN anomalies are detected THEN the system SHALL trigger investigation workflows and notify administrators
5. WHEN uptime targets are missed THEN the system SHALL implement automatic failover and recovery procedures
6. WHEN cost efficiency drops THEN the system SHALL recommend optimization strategies and implement approved changes

### Requirement 8: Gradual Migration Strategy

**User Story:** As a project manager, I want to migrate from the current 4-workflow system to the orchestrator pattern without disrupting production, so that content generation continues uninterrupted.

#### Acceptance Criteria

1. WHEN Phase 1 begins THEN the system SHALL add mutex locks to existing workflows to prevent conflicts
2. WHEN Phase 2 starts THEN the system SHALL implement basic orchestrator with simple scheduling logic
3. WHEN Phase 3 initiates THEN the system SHALL add resource management and intelligent decision making
4. WHEN Phase 4 launches THEN the system SHALL implement full orchestrator architecture with all advanced features
5. WHEN migration occurs THEN the system SHALL maintain backward compatibility and provide rollback capabilities
6. WHEN each phase completes THEN the system SHALL validate performance improvements and stability metrics
7. WHEN migration finishes THEN the system SHALL achieve target metrics: 500 articles/day, <2min latency, >95% success rate
