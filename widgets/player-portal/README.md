# Player Portal Infrastructure

Terraform stack for deploying the SLUGGER Player Portal as Lambda container images behind the existing `slugger-alb`.

## Architecture

Three Lambda functions share the shared `slugger-alb`:

- **player-portal-web** — Next.js 15 App Router (`/widgets/player-portal/*`), 512 MB, 60 s timeout, arm64
- **player-portal-api** — Express 4 REST API (`/widgets/player-portal/api/*`), 512 MB, 30 s timeout, arm64
- **player-portal-sync** — Same image as API, CMD overridden to `node dist/jobs/syncPipeline.js`, invoked by EventBridge every 30 min

```
Internet → slugger-alb
             ├─ /widgets/player-portal/api/*  (priority 310) → player-portal-api Lambda
             └─ /widgets/player-portal/*      (priority 320) → player-portal-web Lambda

EventBridge (rate 30 min) → player-portal-sync Lambda → Aurora alpb-1 (player_portal DB)
                                                       → thebaseballcube.com feeds
```

## File Structure

```
widgets/player-portal/
├── main.tf          # ECR, IAM, Lambdas, CloudWatch, ALB target groups and rules
├── variables.tf     # Input variables (memory, timeout, secrets, ALB priorities)
├── outputs.tf       # Lambda ARNs, ECR URLs, widget URL
├── providers.tf     # Terraform / AWS provider (us-east-2)
├── data.tf          # Data sources for existing VPC, ALB, SGs, subnets, Aurora
├── ssm.tf           # SSM parameters under /slugger/player-portal/
├── eventbridge.tf   # Scheduled rule (rate 30 min) → sync Lambda
├── github-oidc.tf   # OIDC role for GitHub Actions CI/CD
├── database.tf      # null_resource documenting manual DB setup steps
└── README.md
```

## Prerequisites

- Terraform >= 1.0.0
- AWS CLI v2 configured with appropriate credentials
- `psql` for database setup
- `docker buildx` with QEMU for arm64 cross-compilation

## Deployment Steps

### 1. One-time database setup

See `database.tf` for the full psql commands. Summary:

```sql
CREATE DATABASE player_portal;
CREATE USER player_portal_user WITH PASSWORD '<password>';
GRANT ALL PRIVILEGES ON DATABASE player_portal TO player_portal_user;
\c player_portal
GRANT ALL ON SCHEMA public TO player_portal_user;
```

Then generate and apply Prisma migrations from `apps/api/`:

```bash
# Run once locally to create migration files — commit the generated migrations/
npx prisma migrate dev --name init

# Apply in production
DATABASE_URL="postgresql://player_portal_user:<pw>@alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com:5432/player_portal" \
  npx prisma migrate deploy
```

### 2. Update github-oidc.tf

Replace `<YOUR_GITHUB_ORG>` in `github-oidc.tf` with the actual GitHub org/user that owns the `slugger-player-portal` repository.

### 3. Create terraform.tfvars (do not commit)

```hcl
database_url      = "postgresql://player_portal_user:<pw>@alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com:5432/player_portal"
tbc_feed_password = "<tbc-password>"
sync_internal_key = "<random-secret>"
```

### 4. Apply

```bash
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### 5. Build and push initial images

```bash
# Build and push from the slugger-player-portal repo root
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="$ACCOUNT_ID.dkr.ecr.us-east-2.amazonaws.com"
aws ecr get-login-password | docker login --username AWS --password-stdin "$ECR_BASE"

docker buildx build --platform linux/arm64 \
  -f docker/Dockerfile.api \
  -t "$ECR_BASE/player-portal-api:latest" --push .

docker buildx build --platform linux/arm64 \
  --build-arg NEXT_PUBLIC_API_URL=https://alpb-analytics.com/widgets/player-portal/api \
  -f docker/Dockerfile.web \
  -t "$ECR_BASE/player-portal-web:latest" --push .

aws lambda update-function-code --function-name player-portal-api --image-uri "$ECR_BASE/player-portal-api:latest"
aws lambda update-function-code --function-name player-portal-web --image-uri "$ECR_BASE/player-portal-web:latest"
aws lambda update-function-code --function-name player-portal-sync --image-uri "$ECR_BASE/player-portal-api:latest"
```

### 6. Trigger the first sync

```bash
aws lambda invoke --function-name player-portal-sync /dev/null
```

### 7. Register the widget in the SLUGGER dashboard

Run `backend/db/seed-player-portal.js` from the `slugger-website` repo against the production database.

### 8. Set CI/CD secret

Copy the `github_deploy_role_arn` Terraform output and set it as `AWS_DEPLOY_ROLE_ARN` in the `slugger-player-portal` GitHub repository secrets.

## ALB Routing Table

| Priority | Path Pattern | Target | Service |
|----------|-------------|--------|---------|
| 1 | `/api/*` | `slugger-backend-tg` | ECS Fargate (existing) |
| 100 | `/widgets/clubhouse/*` | `tg-widget-clubhouse` | Lambda (existing) |
| 200 | `/widgets/flashcard/*` | `tg-widget-flashcard` | Lambda (existing) |
| 290 | `/widgets/lineup/api/optimizer/*` | `tg-lineup-optim-server` | Lambda (existing) |
| 300 | `/widgets/lineup/*` | `tg-lineup-optim-app` | Lambda (existing) |
| **310** | `/widgets/player-portal/api/*` | `tg-player-portal-api` | **Lambda (this stack)** |
| **320** | `/widgets/player-portal/*` | `tg-player-portal-web` | **Lambda (this stack)** |
| default | `/*` | `slugger-frontend-tg` | ECS Fargate (existing) |

## SSM Parameters

| Path | Type | Used By |
|------|------|---------|
| `/slugger/player-portal/database-url` | SecureString | API + Sync Lambdas |
| `/slugger/player-portal/tbc-feed-password` | SecureString | Sync Lambda |
| `/slugger/player-portal/sync-internal-key` | SecureString | API + Web Lambdas |
| `/slugger/player-portal/api-url-public` | String | CI/CD (web image build arg) |
