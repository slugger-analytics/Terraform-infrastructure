-- Player Portal database and user setup for Aurora alpb-1
-- Run as the Aurora admin user against the 'postgres' database:
--
--   psql -h alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com \
--        -U <admin_user> -d postgres \
--        -f scripts/create-db-user.sql
--
-- IMPORTANT: Replace CHANGE_ME_BEFORE_RUNNING with a strong password before executing.

-- Step 1: Create the database
CREATE DATABASE player_portal;

-- Step 2: Create the application user
-- Replace CHANGE_ME_BEFORE_RUNNING with a strong password
CREATE USER player_portal_user WITH PASSWORD 'CHANGE_ME_BEFORE_RUNNING';

-- Step 3: Grant connection and ownership on the database
GRANT ALL PRIVILEGES ON DATABASE player_portal TO player_portal_user;

-- Steps 4–6 must be run while connected to the player_portal database.
-- After running this file, connect to player_portal and re-run these:
--
--   \c player_portal
--
-- Step 4: Grant schema permissions
GRANT ALL ON SCHEMA public TO player_portal_user;

-- Step 5: Grant permissions on existing tables (if any already exist)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO player_portal_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO player_portal_user;

-- Step 6: Ensure future tables are accessible
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO player_portal_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON SEQUENCES TO player_portal_user;

-- Step 7: Verify the user can only connect to player_portal (not other DBs)
-- SELECT datname, has_database_privilege('player_portal_user', datname, 'CONNECT')
-- FROM pg_database
-- WHERE datname IN ('player_portal', 'lineup_optimization', 'clubhouse', 'slugger', 'postgres');
-- Expected: only player_portal = true
