# Aurora Database Setup Documentation for Player Portal
#
# The player_portal database and player_portal_user are created manually because:
#   1. CREATE DATABASE cannot run in a Terraform provisioner without a dedicated
#      PostgreSQL provider, which would require master credentials in Terraform state.
#   2. This is a one-time setup step, not an ongoing managed resource.
#
# Run these steps ONCE before the first terraform apply and image push.

resource "null_resource" "database_setup" {
  triggers = {
    setup_version = "1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "============================================================"
      echo "PLAYER PORTAL DATABASE SETUP REQUIRED"
      echo "============================================================"
      echo ""
      echo "Step 1 — Connect to Aurora as the admin user:"
      echo ""
      echo "  psql -h alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com \\"
      echo "       -U <admin_user> -d postgres"
      echo ""
      echo "Step 2 — Create the database and user (replace <password>):"
      echo ""
      echo "  CREATE DATABASE player_portal;"
      echo "  CREATE USER player_portal_user WITH PASSWORD '<password>';"
      echo "  GRANT ALL PRIVILEGES ON DATABASE player_portal TO player_portal_user;"
      echo "  \\c player_portal"
      echo "  GRANT ALL ON SCHEMA public TO player_portal_user;"
      echo ""
      echo "Step 3 — Generate and apply Prisma migrations (run from apps/api/):"
      echo ""
      echo "  cd /path/to/slugger-player-portal/apps/api"
      echo "  npx prisma migrate dev --name init    # creates migration files — commit these"
      echo "  DATABASE_URL=\"postgresql://player_portal_user:<pw>@alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com:5432/player_portal\" \\"
      echo "    npx prisma migrate deploy"
      echo ""
      echo "Step 4 — Set DATABASE_URL in terraform.tfvars to the same connection string."
      echo ""
      echo "Step 5 — After first deploy, invoke the sync Lambda to populate data:"
      echo ""
      echo "  aws lambda invoke --function-name player-portal-sync /dev/null"
      echo ""
      echo "============================================================"
    EOT
  }
}
