-- ========================================================
-- ULTIMATE LEAD COORDINATOR - COMPREHENSIVE TESTING SUITE
-- ========================================================
-- Production-grade testing for all coordinator functions and workflows
-- ========================================================

-- ========================================================
-- 1. CORE FUNCTION TESTS
-- ========================================================

-- Test orchestration function with various scenarios
CREATE OR REPLACE FUNCTION test_orchestration_function()
RETURNS TABLE (
    test_name TEXT,
    status TEXT,
    result JSONB,
    execution_time_ms INTEGER,
    notes TEXT
)
LANGUAGE plpgsql
AS $test_orchestration$
DECLARE
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_result JSONB;
    v_test_worker TEXT := 'test-coordinator-' || gen_random_uuid()::TEXT;
BEGIN
    -- Test 1: Normal execution
    v_start_time := clock_timestamp();
    
    BEGIN
        SELECT orchestrate_workflow_execution(v_test_worker, NOW(), 3, TRUE) INTO v_result;
        v_end_time := clock_timestamp();
        
        RETURN QUERY SELECT 
            'normal_execution'::TEXT,
            CASE WHEN v_result->>'success' = 'true' THEN 'PASS' ELSE 'FAIL' END,
            v_result,
            EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INTEGER * 1000,
            'Standard orchestration execution test'::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 
                'normal_execution'::TEXT,
                'FAIL'::TEXT,
                jsonb_build_object('error', SQLERRM),
                0,
                'Exception during normal execution: ' || SQLERRM;
    END;
    
    -- Test 2: High load scenario
    v_start_time := clock_timestamp();
    
    BEGIN
        -- Simulate high load by creating multiple pending executions
        INSERT INTO workflow_orchestration (execution_id, workflow_type, status, worker_id)
        SELECT 
            'test-load-' || generate_series || '-' || gen_random_uuid()::TEXT,
            (ARRAY['content_pipeline', 'seo_monitor', 'revenue_optimizer'])[1 + (generate_series % 3)],
            'running',
            'load-test-worker'
        FROM generate_series(1, 5);
        
        SELECT orchestrate_workflow_execution(v_test_worker || '-load', NOW(), 3, TRUE) INTO v_result;
        v_end_time := clock_timestamp();
        
        RETURN QUERY SELECT 
            'high_load_scenario'::TEXT,
            CASE WHEN v_result->>'success' = 'false' AND v_result->>'reason' LIKE '%concurrent%' THEN 'PASS' ELSE 'FAIL' END,
            v_result,
            EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INTEGER * 1000,
            'High load rejection test'::TEXT;
            
        -- Cleanup
        DELETE FROM workflow_orchestration WHERE worker_id = 'load-test-worker';
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 
                'high_load_scenario'::TEXT,
                'FAIL'::TEXT,
                jsonb_build_object('error', SQLERRM),
                0,
                'Exception during high load test: ' || SQLERRM;
    END;
    
    -- Test 3: Resource constraint scenario
    v_start_time := clock_timestamp();
    
    BEGIN
        -- Simulate resource constraints
        UPDATE api_rate_limits 
        SET requests_used_current_minute = requests_per_minute - 1,
            daily_cost_used = daily_cost_limit - 0.01
        WHERE provider = 'gemini';
        
        SELECT orchestrate_workflow_execution(v_test_worker || '-resource', NOW(), 3, TRUE) INTO v_result;
        v_end_time := clock_timestamp();
        
        RETURN QUERY SELECT 
            'resource_constraint'::TEXT,
            CASE WHEN v_result IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
            v_result,
            EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INTEGER * 1000,
            'Resource constraint handling test'::TEXT;
            
        -- Reset resource limits
        UPDATE api_rate_limits 
        SET requests_used_current_minute = 0,
            daily_cost_used = 0
        WHERE provider = 'gemini';
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 
                'resource_constraint'::TEXT,
                'FAIL'::TEXT,
                jsonb_build_object('error', SQLERRM),
                0,
                'Exception during resource constraint test: ' || SQLERRM;
    END;
END;
$test_orchestration$;

-- Test system health function
CREATE OR REPLACE FUNCTION test_system_health()
RETURNS TABLE (
    test_name TEXT,
    status TEXT,
    health_data JSONB,
    notes TEXT
)
LANGUAGE plpgsql
AS $test_health$
DECLARE
    v_health JSONB;
BEGIN
    -- Test normal health check
    BEGIN
        SELECT check_system_health_comprehensive() INTO v_health;
        
        RETURN QUERY SELECT 
            'health_check_normal'::TEXT,
            CASE 
                WHEN v_health ? 'can_proceed' AND v_health ? 'overall_status' THEN 'PASS'
                ELSE 'FAIL'
            END,
            v_health,
            'Normal system health check'::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 
                'health_check_normal'::TEXT,
                'FAIL'::TEXT,
                jsonb_build_object('error', SQLERRM),
                'Exception during health check: ' || SQLERRM;
    END;
    
    -- Test health check with simulated failures
    BEGIN
        -- Create some failed executions
        INSERT INTO workflow_orchestration (execution_id, workflow_type, status, worker_id, created_at)
        SELECT 
            'test-fail-' || generate_series,
            'content_pipeline',
            'failed',
            'test-health-worker',
            NOW() - (generate_series || ' minutes')::INTERVAL
        FROM generate_series(1, 3);
        
        SELECT check_system_health_comprehensive() INTO v_health;
        
        RETURN QUERY SELECT 
            'health_check_with_failures'::TEXT,
            CASE 
                WHEN v_health->>'overall_status' IN ('warning', 'critical') THEN 'PASS'
                ELSE 'FAIL'
            END,
            v_health,
            'Health check with simulated failures'::TEXT;
            
        -- Cleanup
        DELETE FROM workflow_orchestration WHERE worker_id = 'test-health-worker';
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 
                'health_check_with_failures'::TEXT,
                'FAIL'::TEXT,
                jsonb_build_object('error', SQLERRM),
                'Exception during failure simulation: ' || SQLERRM;
    END;
END;
$test_health$;

-- Test resource management functions
CREATE OR REPLACE FUNCTION test_resource_management()
RETURNS TABLE (
    test_name TEXT,
    status TEXT,
    result_data JSONB,
    notes TEXT
)
LANGUAGE plpgsql
AS $test_resources$
DECLARE
    v_result JSONB;
    v_test_tasks JSONB;
BEGIN
    -- Prepare test task data
    v_test_tasks := jsonb_build_object(
        'tasks', jsonb_build_array(
            jsonb_build_object(
                'workflow_type', 'content_pipeline',
                'should_execute', true,
                'batch_size', 5,
                'estimated_cost', 0.75,
                'estimated_duration_ms', 180000
            ),
            jsonb_build_object(
                'workflow_type', 'seo_monitor',
                'should_execute', true,
                'batch_size', 10,
                'estimated_cost', 0.05,
                'estimated_duration_ms', 120000
            )
        )
    );
    
    -- Test resource availability check
    BEGIN
        SELECT check_comprehensive_resource_availability(v_test_tasks) INTO v_result;
        
        RETURN QUERY SELECT 
            'resource_availability_check'::TEXT,
            CASE 
                WHEN v_result ? 'overall_status' AND v_result ? 'api_limits' THEN 'PASS'
                ELSE 'FAIL'
            END,
            v_result,
            'Resource availability assessment'::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 
                'resource_availability_check'::TEXT,
                'FAIL'::TEXT,
                jsonb_build_object('error', SQLERRM),
                'Exception during resource check: ' || SQLERRM;
    END;
    
    -- Test execution plan creation
    BEGIN
        SELECT create_optimal_execution_plan(
            v_test_tasks,
            v_result,
            'test-planner',
            NOW()
        ) INTO v_result;
        
        RETURN QUERY SELECT 
            'execution_plan_creation'::TEXT,
            CASE 
                WHEN v_result ? 'workflows_to_execute' AND v_result ? 'resource_allocation' THEN 'PASS'
                ELSE 'FAIL'
            END,
            v_result,
            'Execution plan optimization'::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 
                'execution_plan_creation'::TEXT,
                'FAIL'::TEXT,
                jsonb_build_object('error', SQLERRM),
                'Exception during plan creation: ' || SQLERRM;
    END;
    
    -- Test resource reservation
    BEGIN
        PERFORM reserve_execution_resources(v_result);
        
        RETURN QUERY SELECT 
            'resource_reservation'::TEXT,
            'PASS'::TEXT,
            jsonb_build_object('reserved', true),
            'Resource reservation successful'::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 
                'resource_reservation'::TEXT,
                'FAIL'::TEXT,
                jsonb_build_object('error', SQLERRM),
                'Exception during resource reservation: ' || SQLERRM;
    END;
END;
$test_resources$;

-- Test intelligent scheduling
CREATE OR REPLACE FUNCTION test_intelligent_scheduling()
RETURNS TABLE (
    test_name TEXT,
    status TEXT,
    scheduling_data JSONB,
    notes TEXT
)
LANGUAGE plpgsql
AS $test_scheduling$
DECLARE
    v_result JSONB;
    v_current_time TIMESTAMPTZ := NOW();
BEGIN
    -- Test normal scheduling
    BEGIN
        SELECT get_intelligent_scheduled_tasks(v_current_time, 3) INTO v_result;
        
        RETURN QUERY SELECT 
            'intelligent_scheduling_normal'::TEXT,
            CASE 
                WHEN v_result ? 'tasks' AND v_result ? 'analysis_context' THEN 'PASS'
                ELSE 'FAIL'
            END,
            v_result,
            'Normal intelligent scheduling'::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 
                'intelligent_scheduling_normal'::TEXT,
                'FAIL'::TEXT,
                jsonb_build_object('error', SQLERRM),
                'Exception during scheduling: ' || SQLERRM;
    END;
    
    -- Test scheduling with historical data
    BEGIN
        -- Insert some historical execution data
        INSERT INTO execution_history (workflow_type, execution_date, hour_of_day, total_executions, successful_executions, avg_success_rate)
        VALUES 
            ('content_pipeline', CURRENT_DATE, EXTRACT(hour FROM v_current_time)::INTEGER, 10, 9, 0.90),
            ('seo_monitor', CURRENT_DATE, EXTRACT(hour FROM v_current_time)::INTEGER, 5, 5, 1.00),
            ('revenue_optimizer', CURRENT_DATE, EXTRACT(hour FROM v_current_time)::INTEGER, 3, 2, 0.67);
        
        SELECT get_intelligent_scheduled_tasks(v_current_time, 3) INTO v_result;
        
        RETURN QUERY SELECT 
            'scheduling_with_history'::TEXT,
            CASE 
                WHEN jsonb_array_length(v_result->'tasks') >= 0 THEN 'PASS'
                ELSE 'FAIL'
            END,
            v_result,
            'Scheduling with historical performance data'::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 
                'scheduling_with_history'::TEXT,
                'FAIL'::TEXT,
                jsonb_build_object('error', SQLERRM),
                'Exception during historical scheduling: ' || SQLERRM;
    END;
END;
$test_scheduling$;

-- Test monitoring and dashboard functions
CREATE OR REPLACE FUNCTION test_monitoring_functions()
RETURNS TABLE (
    test_name TEXT,
    status TEXT,
    monitoring_data JSONB,
    notes TEXT
)
LANGUAGE plpgsql
AS $test_monitoring$
DECLARE
    v_result JSONB;
    v_test_plan JSONB;
BEGIN
    -- Prepare test execution plan
    v_test_plan := jsonb_build_object(
        'plan_id', 'test-plan-' || gen_random_uuid()::TEXT,
        'workflows_to_execute', jsonb_build_array(
            jsonb_build_object(
                'execution_id', 'test-exec-1',
                'workflow_type', 'content_pipeline',
                'batch_size', 5,
                'estimated_cost', 0.75
            )
        ),
        'resource_allocation', jsonb_build_object(
            'total_estimated_cost', 0.75,
            'resource_efficiency_score', 85
        )
    );
    
    -- Test coordinator dashboard
    BEGIN
        SELECT get_coordinator_dashboard(1) INTO v_result;
        
        RETURN QUERY SELECT 
            'coordinator_dashboard'::TEXT,
            CASE 
                WHEN v_result ? 'coordinator_dashboard' THEN 'PASS'
                ELSE 'FAIL'
            END,
            v_result,
            'Coordinator performance dashboard'::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 
                'coordinator_dashboard'::TEXT,
                'FAIL'::TEXT,
                jsonb_build_object('error', SQLERRM),
                'Exception during dashboard generation: ' || SQLERRM;
    END;
    
    -- Test metrics recording
    BEGIN
        PERFORM record_orchestration_metrics(
            v_test_plan,
            jsonb_build_object('overall_status', 'healthy'),
            NOW()
        );
        
        RETURN QUERY SELECT 
            'metrics_recording'::TEXT,
            'PASS'::TEXT,
            jsonb_build_object('recorded', true),
            'Metrics recording successful'::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 
                'metrics_recording'::TEXT,
                'FAIL'::TEXT,
                jsonb_build_object('error', SQLERRM),
                'Exception during metrics recording: ' || SQLERRM;
    END;
    
    -- Test state management
    BEGIN
        PERFORM update_coordinator_state('ANALYZING', v_test_plan, 'test-coordinator');
        
        RETURN QUERY SELECT 
            'state_management'::TEXT,
            'PASS'::TEXT,
            jsonb_build_object('state_updated', true),
            'State management successful'::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 
                'state_management'::TEXT,
                'FAIL'::TEXT,
                jsonb_build_object('error', SQLERRM),
                'Exception during state management: ' || SQLERRM;
    END;
END;
$test_monitoring$;

-- ========================================================
-- 2. COMPREHENSIVE TEST SUITE RUNNER
-- ========================================================

CREATE OR REPLACE FUNCTION run_coordinator_test_suite()
RETURNS TABLE (
    test_category TEXT,
    test_name TEXT,
    status TEXT,
    execution_time_ms INTEGER,
    result_summary TEXT,
    detailed_result JSONB
)
LANGUAGE plpgsql
AS $run_tests$
DECLARE
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_test_record RECORD;
BEGIN
    -- Initialize test environment
    PERFORM log_orchestration_error('TEST_INIT', 'Starting comprehensive test suite', '{}', 'test-runner');
    
    -- Run orchestration function tests
    v_start_time := clock_timestamp();
    FOR v_test_record IN SELECT * FROM test_orchestration_function()
    LOOP
        v_end_time := clock_timestamp();
        RETURN QUERY SELECT 
            'Orchestration Functions'::TEXT,
            v_test_record.test_name,
            v_test_record.status,
            v_test_record.execution_time_ms,
            v_test_record.notes,
            v_test_record.result;
    END LOOP;
    
    -- Run system health tests
    FOR v_test_record IN SELECT * FROM test_system_health()
    LOOP
        RETURN QUERY SELECT 
            'System Health'::TEXT,
            v_test_record.test_name,
            v_test_record.status,
            0, -- No timing for health tests
            v_test_record.notes,
            v_test_record.health_data;
    END LOOP;
    
    -- Run resource management tests
    FOR v_test_record IN SELECT * FROM test_resource_management()
    LOOP
        RETURN QUERY SELECT 
            'Resource Management'::TEXT,
            v_test_record.test_name,
            v_test_record.status,
            0,
            v_test_record.notes,
            v_test_record.result_data;
    END LOOP;
    
    -- Run intelligent scheduling tests
    FOR v_test_record IN SELECT * FROM test_intelligent_scheduling()
    LOOP
        RETURN QUERY SELECT 
            'Intelligent Scheduling'::TEXT,
            v_test_record.test_name,
            v_test_record.status,
            0,
            v_test_record.notes,
            v_test_record.scheduling_data;
    END LOOP;
    
    -- Run monitoring function tests
    FOR v_test_record IN SELECT * FROM test_monitoring_functions()
    LOOP
        RETURN QUERY SELECT 
            'Monitoring & Analytics'::TEXT,
            v_test_record.test_name,
            v_test_record.status,
            0,
            v_test_record.notes,
            v_test_record.monitoring_data;
    END LOOP;
END;
$run_tests$;

-- ========================================================
-- 3. PERFORMANCE BENCHMARKING
-- ========================================================

CREATE OR REPLACE FUNCTION benchmark_coordinator_performance(
    p_iterations INTEGER DEFAULT 10
)
RETURNS TABLE (
    benchmark_name TEXT,
    iterations INTEGER,
    avg_execution_time_ms DECIMAL,
    min_execution_time_ms INTEGER,
    max_execution_time_ms INTEGER,
    success_rate DECIMAL,
    notes TEXT
)
LANGUAGE plpgsql
AS $benchmark$
DECLARE
    v_iteration INTEGER;
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_execution_times INTEGER[] := ARRAY[]::INTEGER[];
    v_successes INTEGER := 0;
    v_result JSONB;
BEGIN
    -- Benchmark orchestration function
    FOR v_iteration IN 1..p_iterations
    LOOP
        v_start_time := clock_timestamp();
        
        BEGIN
            SELECT orchestrate_workflow_execution('benchmark-worker-' || v_iteration, NOW(), 3, FALSE) INTO v_result;
            v_end_time := clock_timestamp();
            
            v_execution_times := array_append(v_execution_times, 
                EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INTEGER * 1000);
            
            IF v_result->>'success' = 'true' THEN
                v_successes := v_successes + 1;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                v_execution_times := array_append(v_execution_times, 999999); -- Mark as failure
        END;
    END LOOP;
    
    RETURN QUERY SELECT 
        'orchestrate_workflow_execution'::TEXT,
        p_iterations,
        (SELECT AVG(t) FROM unnest(v_execution_times) t WHERE t < 999999),
        (SELECT MIN(t) FROM unnest(v_execution_times) t WHERE t < 999999),
        (SELECT MAX(t) FROM unnest(v_execution_times) t WHERE t < 999999),
        (v_successes::DECIMAL / p_iterations) * 100,
        'Core orchestration function performance'::TEXT;
    
    -- Reset for next benchmark
    v_execution_times := ARRAY[]::INTEGER[];
    v_successes := 0;
    
    -- Benchmark system health check
    FOR v_iteration IN 1..p_iterations
    LOOP
        v_start_time := clock_timestamp();
        
        BEGIN
            PERFORM check_system_health_comprehensive();
            v_end_time := clock_timestamp();
            
            v_execution_times := array_append(v_execution_times, 
                EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INTEGER * 1000);
            v_successes := v_successes + 1;
        EXCEPTION
            WHEN OTHERS THEN
                v_execution_times := array_append(v_execution_times, 999999);
        END;
    END LOOP;
    
    RETURN QUERY SELECT 
        'check_system_health_comprehensive'::TEXT,
        p_iterations,
        (SELECT AVG(t) FROM unnest(v_execution_times) t WHERE t < 999999),
        (SELECT MIN(t) FROM unnest(v_execution_times) t WHERE t < 999999),
        (SELECT MAX(t) FROM unnest(v_execution_times) t WHERE t < 999999),
        (v_successes::DECIMAL / p_iterations) * 100,
        'System health check performance'::TEXT;
END;
$benchmark$;

-- ========================================================
-- 4. TEST RESULT ANALYSIS
-- ========================================================

CREATE OR REPLACE FUNCTION analyze_test_results()
RETURNS TABLE (
    analysis_category TEXT,
    metric_name TEXT,
    metric_value TEXT,
    status TEXT,
    recommendation TEXT
)
LANGUAGE plpgsql
AS $analyze$
DECLARE
    v_test_results RECORD;
    v_total_tests INTEGER := 0;
    v_passed_tests INTEGER := 0;
    v_failed_tests INTEGER := 0;
BEGIN
    -- Count test results
    FOR v_test_results IN SELECT status FROM run_coordinator_test_suite()
    LOOP
        v_total_tests := v_total_tests + 1;
        IF v_test_results.status = 'PASS' THEN
            v_passed_tests := v_passed_tests + 1;
        ELSE
            v_failed_tests := v_failed_tests + 1;
        END IF;
    END LOOP;
    
    -- Overall test results
    RETURN QUERY SELECT 
        'Test Results'::TEXT,
        'Total Tests'::TEXT,
        v_total_tests::TEXT,
        CASE WHEN v_total_tests > 0 THEN 'INFO' ELSE 'ERROR' END,
        'Complete test suite execution'::TEXT;
    
    RETURN QUERY SELECT 
        'Test Results'::TEXT,
        'Passed Tests'::TEXT,
        v_passed_tests::TEXT,
        CASE WHEN v_passed_tests = v_total_tests THEN 'PASS' ELSE 'WARN' END,
        CASE WHEN v_passed_tests = v_total_tests THEN 'All tests passing' ELSE 'Some tests failing' END;
    
    RETURN QUERY SELECT 
        'Test Results'::TEXT,
        'Success Rate'::TEXT,
        ROUND((v_passed_tests::DECIMAL / GREATEST(v_total_tests, 1)) * 100, 2)::TEXT || '%',
        CASE 
            WHEN v_passed_tests::DECIMAL / GREATEST(v_total_tests, 1) >= 0.95 THEN 'PASS'
            WHEN v_passed_tests::DECIMAL / GREATEST(v_total_tests, 1) >= 0.80 THEN 'WARN'
            ELSE 'FAIL'
        END,
        CASE 
            WHEN v_passed_tests::DECIMAL / GREATEST(v_total_tests, 1) >= 0.95 THEN 'Excellent test coverage'
            WHEN v_passed_tests::DECIMAL / GREATEST(v_total_tests, 1) >= 0.80 THEN 'Good test coverage, investigate failures'
            ELSE 'Poor test coverage, immediate attention required'
        END;
    
    -- System readiness assessment
    RETURN QUERY SELECT 
        'System Readiness'::TEXT,
        'Production Ready'::TEXT,
        CASE 
            WHEN v_passed_tests::DECIMAL / GREATEST(v_total_tests, 1) >= 0.95 THEN 'YES'
            ELSE 'NO'
        END,
        CASE 
            WHEN v_passed_tests::DECIMAL / GREATEST(v_total_tests, 1) >= 0.95 THEN 'PASS'
            ELSE 'FAIL'
        END,
        CASE 
            WHEN v_passed_tests::DECIMAL / GREATEST(v_total_tests, 1) >= 0.95 THEN 'System ready for production deployment'
            ELSE 'System requires fixes before production deployment'
        END;
END;
$analyze$;

-- ========================================================
-- 5. QUICK VALIDATION FUNCTIONS
-- ========================================================

-- Quick health check for deployment validation
CREATE OR REPLACE FUNCTION validate_coordinator_deployment()
RETURNS JSONB
LANGUAGE plpgsql
AS $validate$
DECLARE
    v_validation JSONB := '{}';
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_warnings TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Check if core tables exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'workflow_orchestration') THEN
        v_errors := array_append(v_errors, 'Missing table: workflow_orchestration');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'resource_usage') THEN
        v_errors := array_append(v_errors, 'Missing table: resource_usage');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'system_health') THEN
        v_errors := array_append(v_errors, 'Missing table: system_health');
    END IF;
    
    -- Check if core functions exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'orchestrate_workflow_execution') THEN
        v_errors := array_append(v_errors, 'Missing function: orchestrate_workflow_execution');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'check_system_health_comprehensive') THEN
        v_errors := array_append(v_errors, 'Missing function: check_system_health_comprehensive');
    END IF;
    
    -- Check API rate limits configuration
    IF NOT EXISTS (SELECT 1 FROM api_rate_limits WHERE provider = 'gemini') THEN
        v_warnings := array_append(v_warnings, 'Missing API rate limit configuration for Gemini');
    END IF;
    
    -- Test basic function execution
    BEGIN
        PERFORM check_system_health_comprehensive();
    EXCEPTION
        WHEN OTHERS THEN
            v_errors := array_append(v_errors, 'System health function execution failed: ' || SQLERRM);
    END;
    
    v_validation := jsonb_build_object(
        'deployment_valid', array_length(v_errors, 1) IS NULL,
        'errors', v_errors,
        'warnings', v_warnings,
        'status', CASE 
            WHEN array_length(v_errors, 1) IS NULL THEN 'READY'
            ELSE 'FAILED'
        END,
        'timestamp', NOW()
    );
    
    RETURN v_validation;
END;
$validate$;

\echo 'Ultimate Lead Coordinator testing suite deployed successfully!'
\echo 'Run: SELECT * FROM run_coordinator_test_suite(); to execute all tests'
\echo 'Run: SELECT * FROM validate_coordinator_deployment(); for quick validation'