# DCE04 — Deployment and Validation Guide

This document describes how the assessment environment was prepared, what needs to be configured for a repeat deployment, how its components were verified, and how to remove them safely. It accompanies the [project README](../README.md).

> **Important:** The original environment has been destroyed. This is a reproducibility **guide**, not a claim that rerunning the commands will succeed unchanged in another AWS account. Several account-specific identifiers, GitHub connections, resource names, provider settings and IAM trust relationships must be reviewed. In particular, CodeBuild builds were blocked by the account quota and the final working pipeline used GitHub Actions instead.

## 1. Prerequisites

- Terraform CLI and AWS CLI, with an authorised AWS CLI profile.
- Docker Engine / Docker Desktop, Node.js and Git for local application testing.
- A GitHub repository with permission to configure Actions and the AWS OIDC integration.
- AWS permissions for VPC, ALB, ECS, ECR, IAM, S3, DynamoDB, CloudWatch, SNS, CodeConnections, CodePipeline and CodeDeploy.
- Optional: a Microsoft Entra tenant and authorised administrator for SAML federation; Google Cloud CLI for reviewing the proposed DR configuration.
- An AWS budget, cost alerts and a plan to destroy the environment after testing. **ALBs and running ECS tasks may accrue charges while deployed.**

The demonstrated AWS deployment used region `ap-southeast-2`. Resource names and account identifiers in the Terraform configuration reflect the original assessment account and must be checked before reuse.

## 2. Check the account and project configuration

From the repository root, set your profile and verify the active identity:

```powershell
$profile = "dce-project"  # Replace with your configured AWS CLI profile
aws sts get-caller-identity --profile $profile
aws configure get region --profile $profile
```

Inspect, rather than blindly reuse, these files:

```text
terraform/versions.tf
terraform/providers.tf
terraform/variables.tf
terraform/main.tf
terraform/outputs.tf
terraform/backend.tf
terraform/bootstrap/
terraform/modules/
.github/workflows/build-and-push.yml
```

Update project-specific settings where necessary, including AWS account IDs, region, bucket names, repository names, GitHub organisation/repository and OIDC `sub` trust condition, and CodeConnections identifiers. Verify required input values by inspecting the actual `variable` declarations. Do not commit secret values, state files, SAML metadata or credential exports.

## 3. Validate Terraform locally

In PowerShell:

```powershell
cd terraform
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
```

These commands are **inspection and planning** steps. `terraform init` requires a working configured backend; when starting from scratch, complete Section 4 first. A valid `terraform validate` result does not independently prove that AWS deployment will succeed.

## 4. Bootstrap remote Terraform state

The original workflow first used local state and then migrated to an S3 remote backend. The backend was managed in a **separate** Terraform stack under `terraform/bootstrap`, to prevent destruction of the backend before the main application infrastructure.

```powershell
cd terraform/bootstrap
terraform init
terraform plan
terraform apply
```

The bootstrap stack provisioned an S3 bucket for Terraform state, with bucket-level controls and versioning. The root Terraform configuration used S3 native lock files (`use_lockfile = true`). Check the root `backend.tf` for the configured S3 bucket, key, region and locking settings; update them to match the newly created backend bucket.

Then initialise the root stack:

```powershell
cd ..
terraform init -reconfigure
terraform validate
terraform plan
```

If migrating **existing** local state into the backend, use Terraform's migration option as appropriate and review its prompt. Do not assume a migration is required for a fresh deployment.

## 5. Provision the AWS infrastructure

The Terraform project was developed in stages rather than deployed in one initial operation. The approximate dependency sequence was:

1. VPC, public subnets in two AZs, routes and Internet Gateway.
2. Dedicated ALB and ECS security groups.
3. Two ECR repositories.
4. Two ALBs, Blue/Green target groups and HTTP health checks.
5. ECS cluster, Fargate task definitions and two services using container images in ECR.
6. CloudWatch logging, alarms, SNS notifications and ECS scaling policies.
7. S3 artifact and asset buckets, plus the DynamoDB table.
8. CodeDeploy applications/deployment groups, CodeBuild project definitions and CodePipeline.
9. AWS IAM SAML provider and federation roles for Microsoft Entra ID.

Terraform must have valid ECR images available for any ECS task definitions that reference them. On a fresh environment, **create ECR first, publish the initial `v1` images, and only then deploy ECS resources**. Review dependencies in `terraform/main.tf` rather than assuming a single first-time `terraform apply` will succeed with empty registries.

Typical commands at an appropriate deployment checkpoint:

```powershell
cd terraform
terraform plan
terraform apply
terraform output
```

Inspect the output before approving changes. Using targeted Terraform operations for a new environment requires care and should not replace a normal full plan once dependencies are established.

## 6. Build and test the Node.js services locally

Both microservices listen on container port `8080` and expose a `/health` endpoint. The original local checks mapped the services to different host ports (`8081` and `8082`). Navigate to the application directories, inspect each Dockerfile and build context, and build each image, for example:

```powershell
# Adjust paths if the repository layout has changed.
docker build -t dce04-service-a:v1 ./applications/service-a
docker build -t dce04-service-b:v1 ./applications/service-b

docker run --rm -d --name dce04-a -p 8081:8080 dce04-service-a:v1
docker run --rm -d --name dce04-b -p 8082:8080 dce04-service-b:v1

Invoke-RestMethod http://localhost:8081/health
Invoke-RestMethod http://localhost:8082/health

docker stop dce04-a dce04-b
```

Use the container image names, build paths and health endpoints defined in the current repository if they differ from the example.

## 7. Publish container images to Amazon ECR

For manual bootstrap image publishing, obtain the ECR registry URI from the Terraform output or AWS console, then use AWS CLI authentication and Docker push:

```powershell
$region = "ap-southeast-2"
$profile = "dce-project"
$account = (aws sts get-caller-identity --profile $profile --query Account --output text)
$registry = "$account.dkr.ecr.$region.amazonaws.com"

aws ecr get-login-password --region $region --profile $profile |
  docker login --username AWS --password-stdin $registry

docker tag dce04-service-a:v1 "$registry/dce04-service-a:v1"
docker tag dce04-service-b:v1 "$registry/dce04-service-b:v1"
docker push "$registry/dce04-service-a:v1"
docker push "$registry/dce04-service-b:v1"
```

Verify both repositories contain the expected immutable image tags and image digests before ECS deployment.

## 8. The CI/CD design change: CodeBuild to GitHub Actions

### Original architecture

```text
GitHub source → AWS CodePipeline → parallel AWS CodeBuild
              → ECR → parallel AWS CodeDeploy → ECS Fargate
```

Both AWS CodeBuild project resources were provisioned. Their builds did **not** run successfully because `AccountLimitExceededException` revealed a Linux/Small concurrent-build quota of **zero**. The restriction remained after the AWS account was upgraded, so the team adopted an alternative continuous-integration mechanism.

### Actual successful architecture

```text
GitHub push
  → GitHub Actions matrix build (Service A and Service B)
  → AWS OIDC temporary credentials
  → push versioned Docker images to separate ECR repositories
  → AWS CodePipeline detects configured source/image changes
  → parallel CodeDeploy Blue/Green ECS deployments
  → confirm updated public service endpoints
```

GitHub Actions used `.github/workflows/build-and-push.yml` and assumed the assessment-specific AWS IAM role `dce04-github-actions-role`. That role trusted GitHub's OIDC issuer `token.actions.githubusercontent.com`, with audience `sts.amazonaws.com` and repository/branch restrictions in the role trust policy. **The identity-provider trust and role must be recreated and reviewed for a new account or repository.**

The successful workflow processed both services in parallel, producing new `v2` ECR images. CodePipeline retained orchestration of deployments; the active build stage was **not CodeBuild**. Review the actual `terraform/modules/cicd` and `deployment/` configurations before recreating CodePipeline/CodeDeploy.

## 9. Blue/Green deployment verification

Each ECS service used its own ALB, health-check endpoint and Blue/Green target groups. CodeDeploy orchestrated production traffic migration to the replacement task set and retained rollback configuration for failed deployments.

The validation sequence was:

1. Confirm `v1` images and healthy service targets.
2. Push updated `v2` images through GitHub Actions.
3. Inspect CodePipeline execution and two deployment actions.
4. Verify both CodeDeploy deployments succeeded and production traffic moved to the new task sets.
5. Request both public endpoints and confirm they return the updated service version.
6. Review service events and target-group health.

The demonstrated listener traffic was HTTP on port 80. HTTPS and ACM certificate provisioning were not completed.

## 10. Monitoring, scaling, storage and data verification

Verify the deployed resources in AWS:

- Four CPU alarms: high- and low-CPU alarms for each ECS service.
- Four scaling policies: scale-out and scale-in for each service, with capacity configured from one to two tasks.
- CloudWatch Logs for application containers.
- SNS notification subscription and successful delivery of a test notification.
- Two S3 buckets: pipeline artifacts and application assets.
- DynamoDB `dce04-transactions` table; demonstrate sample-record insertion and retrieval.
- ECS services in separate Availability Zones during a temporary two-task distribution test.

**Evidence limitation:** Alarm/policy wiring was verified, but alarm-driven autoscaling of running workloads was **not conclusively observed**. Do not report a completed automatic scaling event.

## 11. Microsoft Entra ID SAML federation

The assessment configured the Entra Enterprise Application **AWS Single-Account Access** and AWS IAM SAML provider **DCE04-EntraID**, with two AWS IAM roles: `DCE04-ReadOnlyAuditor` and `DCE04-DevOpsEngineer`.

The successful test consisted of an Entra-based SAML sign-in to AWS and an AWS Console session using the read-only auditor role. AWS IAM federation resources were subsequently brought under Terraform management.

For a new deployment, obtain current Entra SAML metadata and configure role claims, trust relationships, app assignment and sign-in URLs for the actual AWS account. Do not commit SAML metadata exports if they are intentionally local. The free Entra configuration did not demonstrate group-to-role assignments or enforced Conditional Access/MFA; these are documented limitations.

## 12. Google Cloud disaster-recovery design

The `terraform/modules/gcp-dr` module defines a proposed private Cloud Storage bucket with uniform access, public-access prevention, versioning and removal of noncurrent object versions after 30 days.

The module was successfully initialised and validated:

```powershell
cd terraform/modules/gcp-dr
terraform init -backend=false
terraform fmt -check
terraform validate
```

**No GCP bucket was deployed and no data restore test occurred.** The available Google Cloud billing account was a closed, expired free-trial account. Any AWS-to-GCP backup path illustrated in the architecture is therefore *proposed*, not an established replication service.

## 13. Safe teardown and cost control

The original assessment infrastructure was destroyed after testing. **Always back up state and export required screenshots/evidence before teardown.** State files can contain sensitive information and must be kept outside public Git.

Correct teardown order:

1. Back up the **main** Terraform state and confirm the backup file exists and is nonempty.
2. From `terraform/`, execute `terraform plan -destroy`, review the resources, then `terraform destroy`.
3. Verify `terraform state list` contains no managed resources.
4. If ECR repository deletion fails because images remain, empty those repositories (or use AWS ECR's force deletion appropriately), then rerun `terraform destroy` to reconcile state.
5. Remove assessment-only manual IAM resources, such as the GitHub Actions OIDC role and provider, **only after checking that no other workloads depend on them**.
6. Inspect `terraform/bootstrap/` state and confirm the backend bucket is no longer required by the main stack.
7. Empty **all object versions and delete markers** in the versioned state bucket. This is a permanent operation; verify local state backup first.
8. Execute `terraform destroy` in `terraform/bootstrap/` and confirm the backend bucket is deleted.
9. Independently audit regional ECS, ALBs, ECR, CodeBuild, CodePipeline, S3 buckets, IAM roles and any additional manually created resources.
10. Review AWS billing and budgets over the next billing cycle for delayed charges or resources not tracked by Terraform.

In the completed teardown, the main Terraform state became empty; the separate bootstrap stack then reported **5 resources destroyed**.

## 14. Known gaps and production considerations

This is an assessment implementation rather than a production-ready blueprint. Production adaptation would require at least: TLS termination (ACM/HTTPS), stricter IAM audit and policy review, verified MFA/Conditional Access, private application subnet/NAT or VPC endpoint design as appropriate, explicit disaster-recovery testing and objectives, continuous autoscaling load tests, monitoring-based deployment rollback triggers, application-level security reviews and formal cost management.

## 15. References to evidence

The separately submitted **Implementation and Technical Documentation** report contains the chronological deployment screenshots and validation captions. Refer to that report for evidence of what was **deployed**, **validated**, **blocked**, and **designed only**.
