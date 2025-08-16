# AWS ECS Fargate Phase 1 — Custom VPC + ECS Cluster (Cost-Optimized)

This CDK app creates a **cost‑optimized network** and an **empty ECS Fargate cluster**  with separation of concerns and maintainability.

## 1. Proposed structure
Create the following folder structure:

```bash
ecs-hello/
├── app.py
├── stacks/
│   ├── network_stack.py   # VPC + subnets
│   ├── cluster_stack.py   # ECS Cluster
│   └── tags.py            # Optional: centralized tag helper
```

## 2. Understanding the Network Layout

We’ll create:

- 2 public subnets — for the ALB (internet-facing).
- 2 private subnets — for ECS tasks (not internet-facing).
- NAT Gateway — so ECS tasks in private subnets can pull images from ECR and reach the internet.
- ECS Cluster — bound to this VPC.

## 3. Adding the CDK Code

`stacks/network_stack.py`
```python
from aws_cdk import (
    Stack,
    aws_ec2 as ec2
)
from constructs import Construct

class NetworkStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.vpc = ec2.Vpc(
            self, "EcsHelloVpc",
            max_azs=2,
            nat_gateways=1,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="Public",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24
                ),
                ec2.SubnetConfiguration(
                    name="Private",
                    subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS,
                    cidr_mask=24
                )
            ]
        )
```

`stacks/cluster_stack.py`
```python
from aws_cdk import (
    Stack,
    aws_ecs as ecs,
    aws_ecr as ecr
)
from constructs import Construct

class ClusterStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, *, vpc, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.cluster = ecs.Cluster(
            self, "EcsHelloCluster",
            vpc=vpc,
            cluster_name="ecs-hello-cluster"
        )
```

`stacks/app_stack.py`
```python
from aws_cdk import (
    Stack,
    aws_ecs as ecs,
    aws_ecr as ecr
)
from constructs import Construct

class AppStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, *, cluster, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        repo = ecr.Repository(self, "HelloEcrRepo")

        task_def = ecs.FargateTaskDefinition(self, "HelloTaskDef")
        container = task_def.add_container(
            "HelloContainer",
            image=ecs.ContainerImage.from_registry("amazon/amazon-ecs-sample"),
            logging=ecs.LogDriver.aws_logs(stream_prefix="hello")
        )
        container.add_port_mappings(ecs.PortMapping(container_port=8080))

        ecs.FargateService(
            self,
            "HelloService",
            cluster=cluster,
            task_definition=task_def,
            desired_count=1,
            assign_public_ip=True
        )
```

`app.py`
```python
#!/usr/bin/env python3
from aws_cdk import App
from stacks.network_stack import NetworkStack
from stacks.cluster_stack import ClusterStack
from stacks.app_stack import AppStack

app = App()

network = NetworkStack(app, "EcsNetworkStack")
cluster = ClusterStack(app, "EcsClusterStack", vpc=network.vpc)
app_stack = AppStack(app, "EcsAppStack", cluster=cluster.cluster)

app.synth()
```

## 4. Install Dependencies
```bash
pip install aws-cdk-lib constructs
```

## 5. Synthesize and Deploy
```bash
cdk synth
cdk deploy --all
```

You may also deploy the stacks individually. For example:
```bash
cdk deploy EcsNetworkStack
cdk deploy EcsClusterStack
cdk deploy EcsAppStack
```

CDK will:

- Generate a CloudFormation template.
- Create the VPC, subnets, route tables, NAT gateway.
- Create an ECS cluster linked to the VPC.

## 6. Validation

After deploy:

- In AWS Console → VPC → check subnets (2 public, 2 private).
- In AWS Console → ECS → see the empty cluster.

## 7. Outputs

Save the outputs for convenience later. For example:

```
EcsHelloPhase1.ClusterName = ecs-hello-cluster
EcsHelloPhase1.PrivateSubnetIds = subnet-0b592616b5d773b90,subnet-01364c0b53b74e9ea
EcsHelloPhase1.PublicSubnetIds = subnet-07de35c2e94384818,subnet-01535caf8b059ad4d
EcsHelloPhase1.VpcId = vpc-0a864af68d4306a13
Stack ARN:
arn:aws:cloudformation:eu-west-2:111111111:stack/EcsHelloPhase1/90db2830-79a2-11f0-916f-0ac9e567e65f
```