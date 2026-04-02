# Working Title

![Working Title Architecture](https://raw.githubusercontent.com/Chibuzor-Egbo/working-title/main/docs/architecture-diagram.svg)

**Download diagram (public URL):** [architecture-diagram.svg](https://raw.githubusercontent.com/Chibuzor-Egbo/working-title/main/docs/architecture-diagram.svg)

## Project overview

Working Title is a full-stack DevOps demo project that deploys a Flask todo application on AWS with an automated CI/CD workflow and built-in monitoring.

The repository includes:

- **Application code** (Flask + SQLAlchemy + frontend assets).
- **Containerization** for local and remote runtime (Docker).
- **Infrastructure as Code** for AWS provisioning (Terraform).
- **Configuration management** for host and service setup (Ansible).
- **Observability stack** (Prometheus, Grafana, Alertmanager + Slack alerts).

### What is provisioned in AWS

- **VPC** with public subnets (for EC2) and private subnets (for RDS).
- **App EC2 instance** (pulls and runs the app image from ECR).
- **Monitoring EC2 instance** (runs Prometheus/Grafana/Alertmanager via Docker Compose).
- **RDS PostgreSQL** instance in private subnets.
- **ECR repository** (`wt`) for image storage.
- **Terraform remote state backend** using S3 + DynamoDB lock table.

### App endpoints

- `/` – UI
- `/todos` – GET, POST
- `/todos/<id>` – PUT, DELETE
- `/health` – healthcheck
- `/metrics` – Prometheus metrics endpoint

---

## tech stack

### App/runtime

- Python (3.11 image runtime, 3.12 used in CI)
- Flask
- Flask-SQLAlchemy
- PostgreSQL
- pytest

### DevOps / infra / automation

- Docker + Docker Compose
- Terraform (AWS modules for networking, compute, database, monitoring)
- Ansible (roles: `common`, `app`, `monitoring`)
- GitHub Actions (CI + CD)

### Observability

- Prometheus
- Grafana (provisioned datasource + dashboard)
- Alertmanager (Slack notifications)

---

## how to run locally (docker compose)

Local compose file: `app/compose.yaml`

It starts:

- `db` (PostgreSQL 15)
- `web` (Flask app)
- `prometheus`
- `grafana`

### 1) prerequisites

- Docker
- Docker Compose plugin

### 2) create local env file

Create `app/.env`:

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=working_title
DATABASE_URL=postgresql://postgres:postgres@db:5432/working_title
SECRET_KEY=dev-secret
```

### 3) start the stack

```bash
cd app
docker compose up --build -d
```

### 4) verify

- App: http://localhost:5001
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3001

Quick checks:

```bash
curl http://localhost:5001/health
curl http://localhost:5001/metrics
```

### 5) stop

```bash
cd app
docker compose down
```

---

## how to deploy (step-by-step with the pipeline)

Pipelines:

- `.github/workflows/ci.yml`
- `.github/workflows/cd.yml`

### 0) one-time bootstrap

1. **Provision Terraform backend resources** from `terraform/bootstrap` (S3 bucket + DynamoDB table).
2. **Create ECR repo** (if not already created by Terraform in your flow):
   ```bash
   aws ecr create-repository --repository-name wt --region us-east-1
   ```
3. If repo was created manually, import it so Terraform manages it:
   ```bash
   terraform import module.compute.aws_ecr_repository.this wt
   ```
4. **Create GitHub OIDC provider + IAM role** trusted by `token.actions.githubusercontent.com`.
5. Set repo **variables** and **secrets** used by workflows.

Required variables (from `cd.yml`):

- `BUCKET_NAME`, `DYNAMODBTABLE_NAME`
- `VPC_CIDR`, `PUB1_CIDR`, `PUB2_CIDR`, `PRIV1_CIDR`, `PRIV2_CIDR`
- `AZ1`, `AZ2`
- `MY_IP`
- `INSTANCE_TYPE`
- `DB_USER`

Required secrets (from `ci.yml`/`cd.yml`):

- `AWS_ROLE_ARN`
- `DB_PASSWORD`
- `WT_KEY`, `MON_KEY`
- `ANSIBLE_VAULT_PASS`
- `SLACK_WEBHOOK_URL`

> `MY_IP` is CIDR-restricted ingress for monitoring ports. Update it when your public IP changes.

### 1) CI flow (`ci.yml`)

Triggered on PRs and pushes to `main`:

1. Checkout code
2. Setup Python 3.12
3. Install dependencies
4. Run tests (`pytest app/`)
5. On push to `main` only:
   - Build Docker image from `app/`
   - Configure AWS credentials via OIDC (`AWS_ROLE_ARN`)
   - Login to ECR
   - Push image tagged with commit SHA

### 2) CD flow (`cd.yml`)

Triggered on push to `main`:

1. Checkout code
2. Setup Terraform
3. Configure AWS credentials via OIDC
4. Generate `terraform/terraform.tfvars` from repo vars/secrets
5. `terraform init`
6. `terraform plan -out=tfplan`
7. Upload plan artifact
8. Wait for manual approval
9. `terraform apply -auto-approve tfplan`
10. Export Terraform outputs to workflow env:
    - app public IP
    - monitoring public IP
    - DB endpoint
    - app private IP
11. Generate dynamic Ansible inventory
12. Add hosts to SSH `known_hosts`
13. Run `ansible-playbook ansible/site.yml` with runtime extra vars:
    - `ecr_repo`
    - `image_tag`
    - `db_host`
    - `app_private_ip`
    - `slack_webhook_url`

### 3) post-terraform Ansible behavior

- **common role** (all hosts)
  - Installs Docker, docker-compose, python3-pip, unzip, awscli
  - Ensures Docker is enabled/running
- **app role** (app host)
  - Authenticates to ECR
  - Pulls image tag from CI
  - Runs app container with DB env vars
- **monitoring role** (monitoring host)
  - Writes Prometheus scrape config (targeting app private IP)
  - Writes alert rules + Alertmanager config
  - Provisions Grafana datasource/dashboard files
  - Starts monitoring stack via docker-compose

---

## how the monitoring works

### 1) app instrumentation

`app/app.py` exposes and updates these metrics:

- `http_requests_total{method,endpoint,http_status}` (Counter)
- `http_request_duration_seconds{method,endpoint}` (Histogram)
- `db_active_connections` (Gauge)

Metrics are exposed on `/metrics`.

### 2) scraping

Prometheus on the monitoring server scrapes:

- `job_name: flask-app`
- target: `<app_private_ip>:5000`

### 3) alert rules

Defined in `ansible/roles/monitoring/files/alerts.yml`:

- **AppDown**: app scrape target down for >1 minute
- **HighErrorRate**: 5xx error rate >5% over 2 minutes

### 4) alert routing

Alertmanager sends alerts to Slack webhook (`SLACK_WEBHOOK_URL`) and routes to `#prometheus-alerts`.

### 5) dashboards

Grafana is provisioned automatically with:

- Prometheus datasource (`http://prometheus:9090`)
- Preloaded dashboard JSON from role files

---

## repo structure

```text
.
├── app/                 # Flask app, Dockerfile, compose, tests, local Prometheus config
├── terraform/           # Root Terraform + modules + bootstrap backend
├── ansible/             # site.yml, inventory, app/common/monitoring roles
└── .github/workflows/   # CI and CD pipelines
```
