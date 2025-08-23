-- ============================================================================
-- POSTGRESQL INITIALIZATION SCRIPT
-- Runs automatically when PostgreSQL container starts for the first time
-- ============================================================================

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Try to create vector extension (may not be available in all environments)
DO $$ 
BEGIN
    CREATE EXTENSION IF NOT EXISTS "vector";
    RAISE NOTICE 'Vector extension created successfully';
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'Vector extension not available - semantic search features will be limited';
END $$;

-- Create application user with proper permissions
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'allixios_app') THEN
        CREATE ROLE allixios_app WITH LOGIN PASSWORD 'allixios_app_password';
    END IF;
END $$;

-- Grant permissions
GRANT CONNECT ON DATABASE allixios TO allixios_app;
GRANT USAGE ON SCHEMA public TO allixios_app;
GRANT CREATE ON SCHEMA public TO allixios_app;

-- Create read-only user for analytics
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'allixios_readonly') THEN
        CREATE ROLE allixios_readonly WITH LOGIN PASSWORD 'allixios_readonly_password';
    END IF;
END $$;

GRANT CONNECT ON DATABASE allixios TO allixios_readonly;
GRANT USAGE ON SCHEMA public TO allixios_readonly;

-- Log successful initialization
INSERT INTO pg_stat_statements_info (dealloc) VALUES (0) ON CONFLICT DO NOTHING;

-- Create initial schema migrations table
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(50) PRIMARY KEY,
    description TEXT,
    applied_at TIMESTAMPTZ DEFAULT NOW()
);

-- Log initialization
INSERT INTO schema_migrations (version, description, applied_at) 
VALUES ('000', 'PostgreSQL initialization completed', NOW())
ON CONFLICT (version) DO UPDATE SET applied_at = NOW();

-- Display initialization status
DO $$ 
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'PostgreSQL initialization completed successfully!';
    RAISE NOTICE 'Database: allixios';
    RAISE NOTICE 'Main user: allixios_user';
    RAISE NOTICE 'App user: allixios_app';
    RAISE NOTICE 'Readonly user: allixios_readonly';
    RAISE NOTICE 'Extensions: uuid-ossp, pg_trgm, btree_gin, vector (if available)';
    RAISE NOTICE '============================================================================';
END $$;