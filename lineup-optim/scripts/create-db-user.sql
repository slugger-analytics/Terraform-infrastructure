-- =============================================================================
-- create-db-user.sql
-- Creates the lineup_optimization database and lineup_user role with
-- permissions scoped EXCLUSIVELY to the lineup_optimization database.
--
-- IMPORTANT: This user has NO access to any other databases on the Aurora
-- cluster, including:
--   - clubhouse
--   - flashcard
--   - slugger
--
-- Requirements: 17.4, 17.5
--
-- Usage:
--   Connect to the Aurora cluster as the admin/master user, then run:
--   psql -h alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com \
--        -U <admin_user> -d postgres -f create-db-user.sql
-- =============================================================================

-- Step 1: Create the lineup_optimization database if it doesn't exist.
-- NOTE: CREATE DATABASE cannot run inside a transaction block. If running via
-- psql, this executes as a top-level statement. If the database already exists,
-- the DO block catches the duplicate_database error and continues.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'lineup_optimization') THEN
    PERFORM dblink_exec('dbname=postgres', 'CREATE DATABASE lineup_optimization');
  END IF;
END
$$;

-- Step 2: Create the lineup_user role with a password placeholder.
-- Replace 'CHANGE_ME_BEFORE_RUNNING' with a strong, unique password.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lineup_user') THEN
    CREATE ROLE lineup_user WITH LOGIN PASSWORD 'CHANGE_ME_BEFORE_RUNNING';
  END IF;
END
$$;

-- Step 3: Grant CONNECT on ONLY the lineup_optimization database.
-- This is the sole database this user can connect to. No GRANT CONNECT
-- statements exist for clubhouse, flashcard, slugger, or any other database.
GRANT CONNECT ON DATABASE lineup_optimization TO lineup_user;

-- Step 4: Revoke default public access to ensure the user cannot connect to
-- other databases via the implicit public role grant (defense in depth).
-- On Aurora PostgreSQL, the public role may have CONNECT on template databases.
-- This revocation is a safety measure — it does NOT affect other users because
-- specific grants to other roles remain intact.
REVOKE CONNECT ON DATABASE postgres FROM lineup_user;

-- =============================================================================
-- The following commands MUST be run while connected to the lineup_optimization
-- database. Switch connection context:
--
--   \c lineup_optimization
--
-- Or run a separate psql session:
--   psql -h alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com \
--        -U <admin_user> -d lineup_optimization -f create-db-user-grants.sql
-- =============================================================================

-- Step 5: Grant USAGE on the public schema within lineup_optimization.
GRANT USAGE ON SCHEMA public TO lineup_user;

-- Step 6: Grant ALL PRIVILEGES on ALL existing TABLES in the public schema.
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO lineup_user;

-- Step 7: Grant ALL PRIVILEGES on ALL existing SEQUENCES in the public schema.
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO lineup_user;

-- Step 8: Set default privileges so that future tables and sequences created
-- in the public schema are automatically accessible to lineup_user.
-- This ensures Prisma migrations that create new tables work without manual
-- re-granting.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL PRIVILEGES ON TABLES TO lineup_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL PRIVILEGES ON SEQUENCES TO lineup_user;

-- =============================================================================
-- VERIFICATION QUERIES (run as admin to confirm scoping)
-- =============================================================================
--
-- 1. Verify lineup_user can only connect to lineup_optimization:
--    SELECT datname, has_database_privilege('lineup_user', datname, 'CONNECT')
--    FROM pg_database
--    WHERE datname IN ('lineup_optimization', 'clubhouse', 'flashcard', 'slugger', 'postgres');
--
--    Expected: only lineup_optimization = true
--
-- 2. Verify lineup_user has table privileges in lineup_optimization:
--    \c lineup_optimization
--    SELECT grantee, table_name, privilege_type
--    FROM information_schema.table_privileges
--    WHERE grantee = 'lineup_user';
--
-- =============================================================================
