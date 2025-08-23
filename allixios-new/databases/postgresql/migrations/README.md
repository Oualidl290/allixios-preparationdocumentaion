# Database Migrations

This directory contains database migration scripts for the Allixios platform.

## Migration Files

- `001_initial_migration.sql` - Initial schema creation with all tables, functions, and indexes

## Running Migrations

### Using psql directly
```bash
# Set environment variables
export SUPABASE_DB_HOST="db.your-project.supabase.co"
export SUPABASE_DB_USER="postgres"
export SUPABASE_DB_NAME="postgres"

# Run migration
psql -h $SUPABASE_DB_HOST -U $SUPABASE_DB_USER -d $SUPABASE_DB_NAME -f 001_initial_migration.sql
```

### Using npm scripts (recommended)
```bash
# Install dependencies first
npm install

# Run migrations
npm run migrate

# Or run specific migration
npm run migrate:001
```

## Migration Status

Check which migrations have been applied:

```sql
SELECT * FROM schema_migrations ORDER BY applied_at;
```

## Rollback

To rollback migrations, you'll need to manually drop tables and functions. Always backup your data first!

```sql
-- Backup first!
pg_dump -h $SUPABASE_DB_HOST -U postgres -d postgres > backup_$(date +%Y%m%d_%H%M%S).sql

-- Then drop schema (DANGEROUS!)
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
```

## Migration Guidelines

1. **Always backup** before running migrations
2. **Test migrations** on a copy of production data first
3. **Use transactions** for complex migrations
4. **Document changes** in migration comments
5. **Version control** all migration files

## Troubleshooting

### Common Issues

1. **Extension not available**: Some extensions like `vector` may not be available on all PostgreSQL instances
2. **Permission denied**: Ensure you're using the correct database user with sufficient privileges
3. **Constraint violations**: Check for existing data that might violate new constraints

### Solutions

1. **Skip optional extensions**: Comment out extensions that aren't available
2. **Use service role**: Use the service role key for Supabase deployments
3. **Clean data first**: Remove or fix data that violates constraints before migration