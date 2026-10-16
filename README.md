# DCE04 — Multi-Cloud Microservices Infrastructure

**Course:** DCE04.2 — Multi-Cloud Automation and Emerging Technologies  
**Assessment:** Implementation and Technical Documentation  
**Primary cloud:** Amazon Web Services (AWS), `ap-southeast-2` (Sydney)  
**Supporting platforms:** Microsoft Entra ID (Azure) and a proposed Google Cloud Storage disaster-recovery design

## Project overview

This project demonstrates Infrastructure as Code (IaC), containerised microservice deployment, automated release management, monitoring, and federated cloud identity. Terraform was used to provision the AWS application environment and incorporate AWS IAM resources for Microsoft Entra ID SAML federation.

Two independent Node.js services were packaged as Docker containers, stored in separate Amazon ECR repositories and deployed to Amazon ECS Fargate behind separate public Application Load Balancers (ALBs). The application environment was configured across two AWS Availability Zones. Monitoring and scaling components included Amazon CloudWatch, Application Auto Scaling and Amazon SNS.

The final working software-delivery workflow used **GitHub Actions for automated builds and ECR image publishing**, followed by **AWS CodePipeline and CodeDeploy for parallel Blue/Green deployments**. AWS CodeBuild projects were provisioned initially but could not execute builds because this AWS account's Linux/Small concurrent-build quota was zero.

> **Lifecycle note:** The demonstration AWS infrastructure was successfully deployed, tested and subsequently destroyed to avoid continuing cloud charges. The repository preserves the IaC design and deployment documentation; no live application endpoints are currently expected to respond.

## Architecture

![DCE04 architecture](docs/architecture.png)

> **Diagram interpretation:** The overview drawing includes the original AWS CodeBuild stage. In the successful final configuration, builds ran in GitHub Actions instead; CodeBuild resources were created but could not execute because of the AWS account quota. The GCP storage/backup path is proposed and was not deployed. See the actual working CI/CD flow below.

### Component summary

| Layer | Services and purpose |
| --- | --- |
| Infrastructure management | Modular Terraform configuration; initial local state; S3 remote backend with native S3 locking |
| Networking | Dedicated VPC, public subnets in two Availability Zones, Internet Gateway, routing and service-specific security groups |
| Container registry | Two private Amazon ECR repositories, one for each microservice; immutable versioned images |
| Compute | ECS Fargate cluster with independent Service A and Service B workloads |
| Traffic management | Two public ALBs, health checks and Blue/Green target groups |
| Data | S3 artifact bucket, S3 application-assets bucket and DynamoDB transactions table |
| Observability | CloudWatch log groups, four CPU alarms, four scaling policies and SNS notifications |
| Continuous integration | GitHub Actions matrix workflow builds and pushes both container images to ECR using short-lived AWS credentials via OIDC |
| Continuous delivery | CodePipeline uses source/image changes and CodeDeploy to update both ECS services using Blue/Green deployments |
| Identity | Microsoft Entra ID Enterprise Application with SAML federation to AWS IAM roles |
| Proposed disaster recovery | Terraform-validated Google Cloud Storage bucket configuration; not deployed |

## Repository layout

```text
.github/workflows/        # GitHub Actions build and publish workflow
applications/             # Service A and Service B Node.js applications and Dockerfiles
deployment/               # Deployment specifications / CodeDeploy assets
docs/                     # Architecture and deployment documentation
terraform/                # Root infrastructure configuration and provider settings
terraform/bootstrap/      # Separate Terraform stack for the S3 state backend
terraform/modules/        # AWS modules, Entra-related AWS IAM and GCP DR design
```

## Quick start

This repository is a **demonstration project**, not a one-command production deployment. Recreating the environment requires an AWS account with appropriate permissions and quotas, a configured AWS CLI profile, Terraform, Docker, GitHub repository settings, and updated account-specific configuration. Follow the [deployment guide](docs/DEPLOYMENT_GUIDE.md) rather than running `terraform apply` without reviewing the configuration.

At a high level:

1. Configure AWS CLI credentials and verify the selected AWS account and region.
2. Review Terraform variables, account identifiers, names, provider versions and GitHub connections.
3. Deploy the separate Terraform bootstrap stack, then initialise the root configuration against the S3 backend.
4. Deploy AWS networking, security, ECR, data, ECS, ALBs, monitoring and delivery services.
5. Build and publish the applications through GitHub Actions using AWS OIDC federation.
6. Execute and verify the CodePipeline/CodeDeploy Blue/Green releases.
7. Configure and test Microsoft Entra ID SAML sign-in if required.
8. Record test evidence and destroy resources when no longer needed.

The exact commands, dependencies, validation checks and caveats are detailed in **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)**.

## Original CI/CD design and implemented change

**Original plan:** GitHub source → AWS CodePipeline → two parallel **AWS CodeBuild** projects → Amazon ECR → parallel CodeDeploy Blue/Green deployments → ECS Fargate.

**Issue:** Both CodeBuild projects were created, but build execution failed with `AccountLimitExceededException`. The AWS Linux/Small concurrent-build quota applied to the account was **0**. This restriction persisted after the account was moved to a paid plan.

**Working alternative:**

```text
GitHub repository
  ├── GitHub Actions (parallel build/test of Service A and Service B)
  │     └── AWS OIDC role → Amazon ECR (versioned images)
  └── AWS CodePipeline (GitHub connection + ECR image sources)
        ├── AWS CodeDeploy → ECS Service A Blue/Green release
        └── AWS CodeDeploy → ECS Service B Blue/Green release
```

GitHub Actions successfully built and published updated `v2` images for both services. CodePipeline and CodeDeploy then performed the successful Blue/Green deployments. The original CodeBuild resources remain part of the documented design, **but CodeBuild was not the functioning build executor**.

## Verification performed

- Terraform initialisation, validation, plans and applied infrastructure changes.
- Public subnet placement across `ap-southeast-2a` and `ap-southeast-2b`.
- Separate security groups, with ECS inbound traffic restricted to the corresponding ALB security group.
- Local Docker container responses and `/health` endpoints.
- Versioned container images uploaded to both ECR repositories.
- Healthy ALB target groups and responding public endpoints.
- ECS services observed running across two AZs during a temporary two-task test.
- CloudWatch alarms and autoscaling policies configured; SNS test email successfully delivered.
- DynamoDB sample transaction written and retrieved.
- Successful GitHub Actions builds and CodePipeline/CodeDeploy Blue/Green releases of both `v2` services.
- Successful Microsoft Entra ID SAML sign-in to the AWS Console.
- Terraform configuration validation of the proposed Google Cloud Storage DR module.

## Known limitations

- **HTTPS was not implemented.** The public ALBs were tested over HTTP because the assessment environment did not have a suitable domain/certificate configuration.
- **CodeBuild could not run** due to an account-specific concurrent-build quota of zero; GitHub Actions was used instead.
- **Scaling was configured but not conclusively demonstrated end-to-end** through a CPU-alarm-triggered automatic scale-out event.
- **Entra group mappings and enforced Conditional Access/MFA were not fully demonstrated.** A federated sign-in succeeded, and an authentication method was made available, but enforcement was not independently verified.
- **GCP disaster recovery was not deployed or recovery-tested.** The Terraform module validated locally, but the available Google Cloud free-trial billing account had expired.
- **Infrastructure has been decommissioned.** No live deployment is maintained by this assessment.

## Security notes

- GitHub Actions used OIDC with AWS STS temporary credentials rather than long-lived AWS access keys stored as GitHub secrets.
- Terraform state and credential-related local files must **not** be committed to the repository.
- Example account names and historical resource names in the report are documentation only; a new deployment must use valid, available resource names and an appropriately authorised AWS account.
- Review all IAM permissions, public networking and certificate requirements before using any design beyond an assessment environment.

## Documentation

- [Deployment and Validation Guide](docs/DEPLOYMENT_GUIDE.md)
- [Architecture Diagram](docs/architecture.png)
- Assessment 1 implementation report (submitted separately)

## Cleanup

After verification, the main Terraform environment was destroyed, followed by the separate versioned S3 backend. Manually configured GitHub Actions AWS IAM access was also cleaned up. See the teardown section of the deployment guide for the correct removal order and additional checks.
