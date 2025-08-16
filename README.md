# AWS ECS Fargate + CDK Python Learning Project

This repository is a step-by-step learning project for building a secure, observable, and cost-aware AWS ECS Fargate cluster using AWS CDK (Python). It deploys a simple "Hello World" Flask web application and demonstrates best practices for networking, security, monitoring, autoscaling, and clean up.

## Prerequisites

- **AWS Account:** You need an AWS account with an IAM user or role that has full permissions for CDK and CloudFormation.  

> **💡 Cost:**  
> The total cost in the eu-west-2 region for developing and running this project over the course of 2 evenings and a Saturday was less than $3.00. ECS is cheap!

  [AWS IAM documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)
- **AWS CLI:**  
  [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **AWS CDK:**  
  [Install AWS CDK](https://docs.aws.amazon.com/cdk/v2/guide/getting_started.html)
- **Python 3.8+** and **Node.js** (for CDK CLI)
- **Configure AWS CLI credentials:**  
  [Configure AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)
- The ability to build Docker images

## Project Phases

Each phase is documented in detail. Click the links for step-by-step guides.

### [Phase 0 — Prerequisites & Setup](docs/phase-0.md)
- Install and bootstrap AWS CDK for Python.
- Structure the CDK project and set up your environment.

### [Phase 1 — Foundation: Custom VPC and ECS Cluster](docs/phase-1.md)
- Create a custom VPC with public/private subnets and NAT Gateway.
- Deploy an ECS Fargate cluster in the VPC.

### [Phase 2 — Application Container](docs/phase-2.md)
- Build and deploy a simple Flask "Hello World" Docker app.
- Use CDK to automate ECR repo creation and image deployment.

### [Phase 3 — Load Balancing and Security](docs/phase-3.md)
- Add an Application Load Balancer (ALB) with HTTPS.
- Secure networking with least-privilege security groups.

### [Phase 4 — Observability and Tagging](docs/phase-4.md)
- Enable CloudWatch Logs and metrics for ECS and ALB.
- Create CloudWatch alarms for key metrics.

### [Phase 5 — Clean up, Cost Awareness, Autoscaling, and Advanced Security](docs/phase-5.md)
- Destroy your CDK stacks and check for lingering resources.
- Future enhancements:
  - Set resource requests/limits and enable autoscaling.
  - Example: Deploy Aquasec MicroEnforcer
  - Example: Deploy Datadog tracing via OpenTelemetry.

## Key Learning Outcomes

- Understand how CDK maps to AWS resources (CloudFormation under the hood).
- Build and secure an ECS Fargate service from scratch.
- Integrate HTTPS, DNS, metrics, logging, autoscaling, and security via IaC.
- Confidently expand this into production-grade microservices.

---

## License

See [LICENSE](LICENSE) for MIT license details.
