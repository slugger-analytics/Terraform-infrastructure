# Lineup-Optim Infrastructure

Terraform module for deploying the lineup-optim application (Next.js Web_App + Python FastAPI Web_Server) as Lambda container images behind the existing SLUGGER ALB.

## Architecture

Two Lambda functions behind the shared `slugger-alb`:

- **Web_App** — Next.js T3 Stack (tRPC + Prisma + Supabase Auth), 512MB, 30s timeout, ARM64
- **Web_Server** — Python FastAPI optimizer + RAG chatbot, 1024MB, 30s timeout, ARM64

Both use the [Lambda Web Adapter](https://github.com/awslabs/aws-lambda-web-adapter) to translate ALB requests into HTTP on port 8080. The Web_App connects to Aurora PostgreSQL (`lineup_optimization` database) via Prisma, and Supabase Auth remains external (accessed over HTTPS through the existing NAT Gateway).

```
Internet → ALB (slugger-alb)
             ├─ /widgets/lineup/api/optimizer/*  → Web_Server Lambda (priority 290)
             └─ /widgets/lineup/*                → Web_App Lambda    (priority 300)
```

## File Structure

```
infrastructure/lineup-optim/
├── main.tf              # ECR repos, IAM, Lambda functions, CloudWatch, ALB routing
├── variables.tf         # Input variables (memory, timeout, secrets, priorities)
├── outputs.tf           # Lambda ARNs, ECR URLs, target group ARNs, log groups
├── providers.tf         # Terraform/AWS provider config (us-east-2)
├── data.tf              # Data sources for existing VPC, ALB, subnets, Aurora
├── ssm.tf               # SSM Parameter Store definitions
├── database.tf          # Database setup documentation (null_resource)
├── scripts/
│   ├── create-db-user.sql       # SQL to create lineup_optimization DB and lineup_user
│   ├── validate-plan.sh         # Verifies terraform plan has zero modifications
│   └── validate-deployment.sh   # Post-deployment endpoint smoke tests
└── README.md
```

## Prerequisites

- [Terraform](https://www.terraform.io/) >= 1.0.0
- [AWS CLI](https://aws.amazon.com/cli/) v2, configured with appropriate credentials
- [jq](https://jqlang.github.io/jq/) (used by validation scripts)
- `psql` (for database setup)
- Node.js 18 + Yarn (for Prisma migrations)

## Deployment Steps

### 1. Initialize Terraform

```bash
cd infrastructure/lineup-optim
terraform init
```

### 2. Create a variable file

Create `terraform.tfvars` (do not commit — it contains secrets):

```hcl
database_url         = "postgresql://lineup_user:<password>@alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com:5432/lineup_optimization"
supabase_url         = "https://<project>.supabase.co"
supabase_anon_key    = "<supabase-anon-key>"
openai_api_key       = "<openai-api-key>"
sports_radar_api_key = "<sports-radar-key>"
pointstreak_api_key  = "<pointstreak-key>"
```

### 3. Plan and validate

```bash
terraform plan -var-file="terraform.tfvars"
```

Run the zero-modification validation script to confirm no existing resources are touched:

```bash
bash scripts/validate-plan.sh .
```

The script parses the plan JSON and exits with an error if any action other than `create` or `no-op` is found.

### 4. Apply

```bash
terraform apply -var-file="terraform.tfvars"
```

## Database Setup

Run these steps once before the first deployment.

### 1. Create the database and user

Edit `scripts/create-db-user.sql` and replace `CHANGE_ME_BEFORE_RUNNING` with a strong password, then run:

```bash
psql -h alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com \
     -U <admin_user> -d postgres \
     -f scripts/create-db-user.sql
```

Then connect to the new database and apply schema grants:

```bash
psql -h alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com \
     -U <admin_user> -d lineup_optimization
```

Re-run the GRANT statements (Steps 5–8 in the SQL file) while connected to `lineup_optimization`.

### 2. Run Prisma migrations

```bash
cd lineup-optim/web-app
DATABASE_URL="postgresql://lineup_user:<password>@alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com:5432/lineup_optimization" \
  npx prisma migrate deploy
```

### 3. Verify user permissions

```sql
SELECT datname, has_database_privilege('lineup_user', datname, 'CONNECT')
FROM pg_database
WHERE datname IN ('lineup_optimization', 'clubhouse', 'flashcard', 'slugger', 'postgres');
```

Expected: only `lineup_optimization` = `true`.

## SSM Parameters

All parameters live under `/slugger/lineup-optim/`. Lambda functions read these at initialization.

| Parameter Path | Type | Used By | Description |
|---|---|---|---|
| `/slugger/lineup-optim/database-url` | SecureString | Web_App | PostgreSQL connection string for Aurora |
| `/slugger/lineup-optim/supabase-url` | String | Web_App | Supabase project URL |
| `/slugger/lineup-optim/supabase-anon-key` | String | Web_App | Supabase anonymous key |
| `/slugger/lineup-optim/openai-api-key` | SecureString | Web_Server | OpenAI API key for RAG chatbot |
| `/slugger/lineup-optim/backend-url` | String | Web_App | Web_Server path: `/widgets/lineup/api/optimizer` |
| `/slugger/lineup-optim/sports-radar-api-key` | SecureString | Web_App | Sports Radar API key |
| `/slugger/lineup-optim/pointstreak-api-key` | SecureString | Web_App | Pointstreak API key |

## ALB Routing

Listener rules are attached to both HTTPS (443) and HTTP (80) listeners on `slugger-alb`.

| Priority | Path Pattern | Target Group | Service |
|---|---|---|---|
| 1 | `/api/*` | `slugger-backend-tg` | ECS Fargate (existing) |
| 100 | `/widgets/clubhouse/*` | `tg-widget-clubhouse` | Lambda (existing) |
| 200 | `/widgets/flashcard/*` | `tg-widget-flashcard` | Lambda (existing) |
| **290** | `/widgets/lineup/api/optimizer/*` | `tg-lineup-optim-server` | **Web_Server Lambda** |
| **300** | `/widgets/lineup/*` | `tg-lineup-optim-app` | **Web_App Lambda** |
| default | `/*` | `slugger-frontend-tg` | ECS Fargate (existing) |

Priority 290 (Web_Server) is evaluated before 300 (Web_App), so the more specific `/api/optimizer/*` path matches first.

## Validation

After deployment, run the validation script to verify all endpoints:

```bash
bash scripts/validate-deployment.sh
```

This tests:
1. Web_App health at `/widgets/lineup/api/health` → HTTP 200
2. Web_Server health at `/widgets/lineup/api/optimizer/health` → HTTP 200
3. Web_App static files at `/widgets/lineup/` → HTML response
4. Web_Server optimizer at `/widgets/lineup/api/optimizer/optimize-lineup` → valid JSON on POST

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/deploy-lineup-optim.yml`) triggers on pushes to `main` that change `lineup-optim/` or `infrastructure/lineup-optim/`.

Pipeline stages:

1. **Test** — runs unit tests and property-based tests (100+ iterations)
2. **Terraform Plan** — runs `terraform plan` + `validate-plan.sh` (zero-modification check)
3. **Build & Deploy** (requires test + plan to pass):
   - Builds ARM64 Docker images via QEMU/Buildx
   - Tags with git SHA, pushes to ECR
   - Runs Prisma migrations
   - Updates both Lambda functions
   - Smoke tests health endpoints
   - If smoke tests fail → automatic rollback to previous images
4. **Existing Services Validation** — verifies clubhouse, flashcard, API, and frontend still return HTTP 200. If any fail → rollback + alert.

Authentication uses the `github-actions-deploy` OIDC role via `AWS_DEPLOY_ROLE_ARN` secret.
