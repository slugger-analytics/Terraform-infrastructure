# Aurora Database Setup for Lineup-Optim
# Creates a null_resource documenting the manual database and user setup steps.
#
# The lineup_optimization database and lineup_user role are created manually
# (or via the SQL script) because:
#   1. CREATE DATABASE cannot run inside a Terraform provisioner without a
#      dedicated PostgreSQL provider, and adding that provider would require
#      storing master credentials in Terraform state.
#   2. The operation is a one-time setup step, not an ongoing managed resource.
#
# Requirements: 5.1, 5.2, 5.4, 5.5

# ─── Database Setup Documentation ────────────────────────────────────
#
# MANUAL STEPS (run once before first deployment):
#
# 1. Connect to the Aurora cluster as the admin/master user:
#
#      psql -h alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com \
#           -U <admin_user> -d postgres
#
# 2. Run the database and user creation script:
#
#      \i scripts/create-db-user.sql
#
#    Or from the command line:
#
#      psql -h alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com \
#           -U <admin_user> -d postgres \
#           -f infrastructure/lineup-optim/scripts/create-db-user.sql
#
# 3. IMPORTANT: Before running the script, replace the placeholder password
#    'CHANGE_ME_BEFORE_RUNNING' in create-db-user.sql with a strong password.
#
# 4. After running the script on the postgres database, connect to
#    lineup_optimization to apply the schema grants:
#
#      \c lineup_optimization
#
#    Then re-run Steps 5-8 from create-db-user.sql (GRANT statements).
#
# 5. Run Prisma migrations to create the application tables:
#
#      cd lineup-optim/web-app
#      DATABASE_URL="postgresql://lineup_user:<password>@alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com:5432/lineup_optimization" \
#        npx prisma migrate deploy
#
# 6. Set the DATABASE_URL Terraform variable to:
#      postgresql://lineup_user:<password>@alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com:5432/lineup_optimization
#
#    This value flows into the SSM parameter /slugger/lineup-optim/database-url
#    (defined in ssm.tf) and the Web_App Lambda environment variable.
#
# 7. Verify the user permissions are scoped correctly:
#
#      SELECT datname, has_database_privilege('lineup_user', datname, 'CONNECT')
#      FROM pg_database
#      WHERE datname IN ('lineup_optimization', 'clubhouse', 'flashcard', 'slugger', 'postgres');
#
#    Expected: only lineup_optimization = true
#
# ─────────────────────────────────────────────────────────────────────

resource "null_resource" "database_setup" {
  # This resource serves as a reminder and documentation anchor for the
  # manual database setup. It runs a local-exec provisioner that prints
  # the setup instructions on first apply.
  #
  # The actual database/user creation is performed via:
  #   infrastructure/lineup-optim/scripts/create-db-user.sql

  triggers = {
    # Only run once. Re-trigger by tainting: terraform taint null_resource.database_setup
    setup_version = "1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "============================================================"
      echo "LINEUP-OPTIM DATABASE SETUP REQUIRED"
      echo "============================================================"
      echo ""
      echo "The lineup_optimization database and lineup_user must be"
      echo "created manually on the Aurora cluster before deployment."
      echo ""
      echo "Run the setup script as the Aurora admin user:"
      echo ""
      echo "  psql -h alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com \\"
      echo "       -U <admin_user> -d postgres \\"
      echo "       -f infrastructure/lineup-optim/scripts/create-db-user.sql"
      echo ""
      echo "Then run Prisma migrations:"
      echo ""
      echo "  cd lineup-optim/web-app"
      echo "  DATABASE_URL=\"postgresql://lineup_user:<password>@alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com:5432/lineup_optimization\" \\"
      echo "    npx prisma migrate deploy"
      echo ""
      echo "See infrastructure/lineup-optim/scripts/create-db-user.sql"
      echo "for full details and verification queries."
      echo "============================================================"
    EOT
  }
}
