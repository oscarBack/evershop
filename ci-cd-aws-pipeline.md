# CI/CD Pipeline (AWS) - EverShop

This pipeline proposes a **Continuous Integration (CI)** and **Continuous Delivery/Deployment (CD)** flow based on DevOps best practices:

- Early quality and security validation.
- Versioned and immutable artifacts.
- Environment promotion with quality gates.
- Manual approval before production.
- Observability and controlled rollback.

## CI Diagram for Application Code

```mermaid
flowchart LR
    Dev["Developer"] --> PC["Pre-commit hooks\n(local lint, secrets scan)"]
    PC --> BR["Push / PR with branch protection"]

    subgraph CI["CI - Continuous Integration"]
      A["Checkout code"] --> B["Install dependencies\n(lockfile)"]
      B --> C["Lint"]
      C --> D["Tests\n(unit/integration + coverage)"]
      D --> E["Security scan\n(SAST + dependencies)"]
      E --> F["Build / Compile"]
      F --> G["Build container image"]
      G --> H["Publish immutable artifact\n(ECR / registry)"]
    end

    BR --> A
```

## CD Diagram for Application Deployment

```mermaid
flowchart LR
  A["Published artifact"] --> M{"Are there DB migrations?"}

  M -- "Yes" --> B1["Backup / snapshot"]
  B1 --> C1["Run migration job\n(expand/contract)"]
    C1 --> S["Smoke tests"]

  M -- "No" --> B2["Backup / snapshot\n(policy-based)"]
    B2 --> S

    S --> BG["Deploy Blue/Green (ECS)"]
  BG --> Q{"Quality Gate OK?\n(health, SLO, smoke/contract)"}

  Q -- "No" --> R["Automatic rollback\n(app and DB according to plan)"]
  Q -- "Yes" --> OK["Successful release"]
```

## Only for Infrastructure CI/CD Diagram (Terraform + AWS)

```mermaid
flowchart TB
    subgraph INFRA["CI/CD Infra"]
      A["Checkout Code"] --> B["tf fmt check"]
      B --> C["tf validate"]
      C --> D["checkov"]
      D --> E["terraform init -backend=false"]
      E --> F["tests"]
      F --> G["Infracost"]
      G --> H["terraform plan"]
      H --> I["manual approve"]
      I --> J["terraform apply"]
    end
```

## Applied DevOps Recommendations

- **Pipeline as Code**: define CI/CD in versioned files.
- **Mandatory gates**: block promotion if quality, tests, or security checks fail.
- **Single promoted artifact**: the same build moves across all environments.
- **Shift-left security**: early scanning in CI.
- **Traceability**: link commit, build, image, deployment, and release.
- **Tested rollback**: strategy and automation for fast recovery.
- **Observability**: metrics, logs, traces, and post-deployment alerts.
