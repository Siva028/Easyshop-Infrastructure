# EasyShop Infrastructure

Terraform-based AWS infrastructure for the **EasyShop** e-commerce platform. Provisions a production-ready Kubernetes environment on Amazon EKS with separate `dev` and `prod` environments, deployed to `ap-south-1` (Mumbai).

[![Terraform](https://img.shields.io/badge/Terraform-1.10%2B-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS%201.34-232F3E?logo=amazonaws&logoColor=white)](https://aws.amazon.com/eks/)
[![Region](https://img.shields.io/badge/Region-ap--south--1-orange)](https://aws.amazon.com/about-aws/global-infrastructure/regions_az/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions%20OIDC-2088FF?logo=githubactions&logoColor=white)](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

---

## 📐 Architecture

### Dev Environment

![Dev Architecture](docs/easyshop-architecture-dev.png)

| Component | Configuration |
|---|---|
| VPC | `10.0.0.0/16` across **2 AZs** (ap-south-1a, 1b) |
| NAT Gateways | 2 (one per AZ) |
| EKS Version | 1.34 |
| App Nodes | `t3.medium` × 1–2 |
| ECR | `easyshop-dev` (mutable tags, 5 image limit) |

### Prod Environment

![Prod Architecture](docs/easyshop-architecture-prod.png)

| Component | Configuration |
|---|---|
| VPC | `10.1.0.0/16` across **3 AZs** (ap-south-1a, 1b, 1c) |
| NAT Gateways | 3 (one per AZ — high availability) |
| EKS Version | 1.34 |
| System Nodes | `t3.medium` × 2–3 |
| App Nodes | `t3.large` × 2–6 (desired 3) |
| ECR | `easyshop-prod` (immutable tags, 20 image limit) |

### Common

- **Region:** `ap-south-1` (Mumbai)
- **State backend:** S3 (`easyshop-tfstate`) with native S3 locking (`use_lockfile = true`) — no DynamoDB required
- **CI/CD:** GitHub Actions with OIDC trust (no long-lived AWS keys)

> Editable diagram source: [`docs/easyshop-architecture.drawio`](docs/easyshop-architecture.drawio) — open at [app.diagrams.net](https://app.diagrams.net) → File → Open from → Device.

---

## 📁 Repository Structure

```
.
├── modules/                    # Reusable Terraform modules
│   ├── vpc/                    # VPC, subnets, IGW, NAT gateways, route tables
│   ├── eks/                    # EKS control plane + managed node groups
│   └── ecr/                    # ECR repository with lifecycle + IAM access
│
├── environments/               # Environment-specific compositions
│   ├── bootstrap/              # One-time: GitHub OIDC provider + IAM roles
│   ├── dev/                    # Dev environment (2 AZs)
│   └── prod/                   # Prod environment (3 AZs, HA)
│
├── docs/                       # Architecture diagrams
│   ├── easyshop-architecture.drawio
│   ├── easyshop-architecture-dev.png
│   └── easyshop-architecture-prod.png
│
└── README.md
```

---

## ✅ Prerequisites

- **Terraform** ≥ 1.10 (required for S3 native state locking)
- **AWS CLI** configured with credentials that can create IAM, VPC, EKS, and ECR resources
- **kubectl** (to interact with the cluster after deployment)
- An **S3 bucket** named `easyshop-tfstate` in `ap-south-1` (created manually before first `terraform init` — see Setup)
- A **GitHub repository** for the application code (referenced by the OIDC trust policy)

---

## 🚀 Setup

### 1. Create the Terraform state bucket (one-time, manual)

```bash
aws s3api create-bucket \
  --bucket easyshop-tfstate \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

aws s3api put-bucket-versioning \
  --bucket easyshop-tfstate \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket easyshop-tfstate \
  --server-side-encryption-configuration '{
    "Rules": [{ "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" } }]
  }'

aws s3api put-public-access-block \
  --bucket easyshop-tfstate \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### 2. Bootstrap the AWS account (one-time)

The `bootstrap` environment provisions:
- A **GitHub Actions OIDC identity provider** (account-wide)
- IAM trust relationships for keyless authentication

```bash
cd environments/bootstrap
terraform init
terraform plan
terraform apply
```

> The OIDC provider has `prevent_destroy` set — it should not be removed once created.

---

## 🔧 Deploying an Environment

### Dev

```bash
cd environments/dev
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Prod

```bash
cd environments/prod
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Connect kubectl to the cluster

```bash
# Dev
aws eks update-kubeconfig --region ap-south-1 --name easyshop-dev

# Prod
aws eks update-kubeconfig --region ap-south-1 --name easyshop-prod

kubectl get nodes
```

---

## 🤖 CI/CD with GitHub Actions OIDC

The `bootstrap` environment creates an **IAM role** that the EasyShop application repository assumes via OIDC for Docker image builds and pushes to ECR. **No static AWS access keys are stored in GitHub Secrets** — authentication is short-lived and token-based.

A typical workflow step:

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::<account-id>:role/easyshop-github-actions
      aws-region: ap-south-1
```

---

## 🔍 Environment Differences at a Glance

| Aspect | Dev | Prod |
|---|---|---|
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` |
| Availability Zones | 2 | 3 |
| NAT Gateways | 2 | 3 |
| App node type | `t3.medium` | `t3.large` |
| App node count | 1–2 | 2–6 (desired 3) |
| System node group | – | `t3.medium` × 2–3 |
| ECR tag mutability | Mutable | Immutable |
| ECR image retention | 5 | 20 |

---

## 🧹 Cleanup

To destroy an environment:

```bash
cd environments/dev      # or environments/prod
terraform destroy -var-file=terraform.tfvars
```

> The `bootstrap` environment is account-wide foundational infrastructure and should generally **not** be destroyed.

---

## 📦 Modules Reference

| Module | Purpose |
|---|---|
| [`modules/vpc`](modules/vpc) | VPC, public/private subnets across configurable AZs, IGW, NAT Gateway(s), route tables |
| [`modules/eks`](modules/eks) | EKS control plane and managed node groups in private subnets |
| [`modules/ecr`](modules/ecr) | ECR repository with encryption, lifecycle policies, and IAM access for the GitHub Actions role |

---

## 🤝 Contributing

1. Fork and create a feature branch.
2. Keep modules generic — environment-specific values belong in `terraform.tfvars`.
3. Run `terraform fmt -recursive` and `terraform validate` before committing.
4. Open a pull request against `main`.

---

## 📄 License

This project is for educational and portfolio purposes.

---

## 🔗 Related Repositories

- **[Easyshop-App](https://github.com/Siva028/Easyshop-App)** — The Next.js application that runs on this infrastructure.
