# infra-evershop

Infrastructure repository for EverShop on AWS EKS.

## Structure

```
infra-evershop/
└── eks-deployment/       # EKS cluster, RDS, VPC, IAM, networking
    ├── atlantis.yaml
    ├── makefile
    ├── providers.tf
    ├── variables.tf
    ├── data.tf
    ├── vpc.tf
    ├── eks.tf
    ├── rds.tf
    ├── security_groups.tf
    ├── iam.tf
    ├── outputs.tf
    ├── dev.hcl
    ├── qa.hcl
    └── prod.hcl
```

## Quick Start

```bash
cd eks-deployment
make tf-dev    # plan dev
make tf-qa     # plan qa
make tf-prod   # plan prod
```

## Atlantis

```
atlantis plan -p evershop-eks-dev
atlantis plan -p evershop-eks-qa
atlantis plan -p evershop-eks-prod
```
