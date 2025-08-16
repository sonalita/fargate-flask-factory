# AWS ECS Fargate + CDK Python Learning Project Plan

## High-Level Plan

### Phase 0 — Prerequisites & Setup
- Install and bootstrap AWS CDK for Python.
- Structure the CDK project so it’s maintainable.
- Verify AWS CLI credentials are working.
- Understand what the CDK “synth” and “deploy” steps actually do.

### Phase 1 — Foundation: Custom VPC and ECS Cluster
- Create a **custom VPC** in CDK with:
  - At least 2 public subnets (for ALB).
  - At least 2 private subnets (for ECS tasks).
  - NAT Gateway for outbound internet access from private subnets.
- Create an **ECS Cluster** in Fargate mode within the custom VPC.

### Phase 2 — Application Container
- Write a simple **Flask “Hello World”** Docker app.
- Push the image to **Amazon ECR** (via CDK, so we automate repo creation).
- Deploy the container in **ECS Fargate**.

### Phase 3 — Load Balancing and Security
- Add an **Application Load Balancer (ALB)** in the public subnets.
- Enforce:
  - **HTTPS** from the internet to the ALB (via ACM-managed cert).
  - **HTTP only** from ALB to ECS containers (private subnets, no direct public access).
- Manage security groups for least-privilege network access.

### Phase 4 — Observability
- Enable **CloudWatch Logs** for the ECS task.
- Set up **CloudWatch metrics** for ALB and ECS service.
- (Optional) Create an alarm to test how we could react to errors or high latency.

### Phase 5 — Clean up & Iteration
- Learn how to **destroy** the stack cleanly.
- Discuss **cost awareness** in Fargate + ALB setups.
- Optional: Explore blue/green deployments or multiple environments.

## Key Learning Outcomes
By the end of this, you’ll:
- Understand **how CDK maps to AWS resources** (CloudFormation under the hood).
- Be able to **build and secure an ECS Fargate service** from scratch.
- Know how to integrate **HTTPS, DNS, metrics, and logging** entirely via IaC.
- Be confident enough to expand this into production-grade microservices.