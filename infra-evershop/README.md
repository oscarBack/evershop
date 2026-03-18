# infra-evershop

Infrastructure repository for EverShop EKS deployment.

## Overview

This repository contains Terraform configuration for deploying and managing the EverShop e-commerce platform on AWS EKS.

## Architecture

- **EKS**: Kubernetes cluster for container orchestration
- **RDS**: PostgreSQL database for application data
- **Security Groups**: Network security configuration
- **VPC**: Virtual private cloud networking

## Environments

| Environment | Workspace | Account |
|-------------|-----------|---------|
| Development | dev | evershop-dev |
| QA | qa | evershop-qa |
| Production | prod | evershop-prod |

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with SSO
- Atlantis (for PR automation)

## Quick Start

### Development Environment

```bash
make tf-dev
```

### QA Environment

```bash
make tf-qa
```

### Production Environment

```bash
make tf-prod
```

## Atlantis Commands

In PR comments, use:

- `atlantis plan -p evershop-{env}` - Plan infrastructure changes
- `atlantis apply -p evershop-{env}` - Apply infrastructure changes

## Terraform Modules

This project uses shared Terraform modules from the organization registry.

## License

This project is proprietary software.