# AWS ECS Fargate Phase 3 — Load Balancing and Security

> This step assumes that you have a Domain Name and have registered a certificate for the subdomain domain you wish to use in Amazon Certificate manager. The configuration of your domain name records is beyond the scope of this exercise. In my case, I used Cloudflare which supports ACM DNS challenges.

## 1. Create ALB

Update `stacks/app_stack.py` to include

```python
alb_sg = ec2.SecurityGroup(
    self,
    "AlbSG",
    vpc=cluster.vpc,
    allow_all_outbound=True,
    description="Security group for the ALB",
)

# Allow HTTPS from anywhere
alb_sg.add_ingress_rule(
    ec2.Peer.any_ipv4(),
    ec2.Port.tcp(443),
    "Allow HTTPS from the internet",
)
```

## 2. Update the ECS Security Group
Update `stacks/app_stack.py` to include

```python
hello_sg = ec2.SecurityGroup(
    self,
    'HelloServiceSG',
    vpc=cluster.vpc,
    allow_all_outbound=True,
    description='SG for ECS Hello service (private)',
)

# Allow ALB SG on port 8080
hello_sg.add_ingress_rule(
    peer=alb_sg,
    connection=ec2.Port.tcp(8080),
    description='Allow HTTP from ALB only',
)
```
 - Remove the previous rule that allowed your public IP directly.

## 3. Create an HTTPS Listener with ACM cert

- You need an ACM certificate in the same region.
- Then attach it to the ALB HTTPS listener:
  
Update `stacks/app_stack.py` to include
```Python
from aws_cdk import aws_certificatemanager as acm
from aws_cdk import aws_elasticloadbalancingv2 as elbv2

cert = acm.Certificate.from_certificate_arn(
    self,
    "AlbCert",
    "arn:aws:acm:region:account:certificate/your-cert-id",
)

alb = elbv2.ApplicationLoadBalancer(
    self,
    "HelloAlb",
    vpc=cluster.vpc,
    internet_facing=True,
    security_group=alb_sg,
)

listener = alb.add_listener(
    "HttpsListener",
    port=443,
    certificates=[cert],
    default_target_groups=[],
)

# Forward traffic to ECS
listener.add_targets(
    "EcsTarget",
    port=8080,
    targets=[ecs.FargateService(self, "HelloServiceRef", service_name="HelloService")],
    health_check=elbv2.HealthCheck(path="/", port="8080"),
)
```

## 4. Subnet considerations
- **ALB** → public subnets
- **ECS Service** → private subnets (no direct public IP)
You’ll need to change assign_public_ip=True to False in your Fargate service:

```python
ecs.FargateService(
    self,
    'HelloService',
    cluster=cluster,
    task_definition=task_def,
    desired_count=1,
    assign_public_ip=False,  # now private
    security_groups=[hello_sg],
    enable_execute_command=True,
)
```

## The final `app_stack.py` code
```python
import os

from aws_cdk import Stack, aws_certificatemanager as acm
from aws_cdk import aws_ec2 as ec2
from aws_cdk import aws_ecr_assets as ecr_assets
from aws_cdk import aws_ecs as ecs
from aws_cdk import aws_elasticloadbalancingv2 as elbv2
from constructs import Construct


class AppStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, *, cluster, domain_name=None, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # 1️⃣ Build & push local Docker image
        image_asset = ecr_assets.DockerImageAsset(
            self,
            "FlaskAppImage",
            directory=os.path.join(os.path.dirname(__file__), "../flask_app"),
        )

        task_def = ecs.FargateTaskDefinition(self, "FlaskTaskDef")
        container = task_def.add_container(
            "FlaskContainer",
            image=ecs.ContainerImage.from_docker_image_asset(image_asset),
            logging=ecs.LogDriver.aws_logs(stream_prefix="flask"),
        )
        container.add_port_mappings(ecs.PortMapping(container_port=8080))

        # 2️⃣ Security group for ECS service (private, only ALB can talk)
        ecs_sg = ec2.SecurityGroup(
            self,
            "FlaskServiceSG",
            vpc=cluster.vpc,
            allow_all_outbound=True,
            description="Private SG for ECS service, allows only ALB traffic",
        )

        # 3️⃣ Security group for ALB (public, allows HTTPS from anywhere)
        alb_sg = ec2.SecurityGroup(
            self,
            "FlaskALBSG",
            vpc=cluster.vpc,
            allow_all_outbound=True,
            description="Public SG for ALB, allows HTTPS from Internet",
        )

        # CHANGE THE CIDR!
        alb_sg.add_ingress_rule(ec2.Peer.ipv4('0.0.0.0/0'), ec2.Port.tcp(443), 'Allow HTTPS from Internet')

        # 4️⃣ Fargate service in private subnets
        service = ecs.FargateService(
            self,
            "FlaskService",
            cluster=cluster,
            task_definition=task_def,
            desired_count=1,
            assign_public_ip=False,  # private
            security_groups=[ecs_sg],
            enable_execute_command=True,
        )

        # 5️⃣ ALB in public subnets
        alb = elbv2.ApplicationLoadBalancer(
            self,
            "FlaskALB",
            vpc=cluster.vpc,
            internet_facing=True,
            security_group=alb_sg,
        )

        # 6️⃣ ACM certificate (optional, only if domain_name is provided)
        certificate = None
        if domain_name:
            certificate = acm.Certificate(
                self,
                "FlaskALBCert",
                domain_name=domain_name,
                validation=acm.CertificateValidation.from_dns(),
            )

        # 7️⃣ HTTPS listener
        listener = alb.add_listener(
            "HttpsListener",
            port=443,
            certificates=[certificate] if certificate else None,
            open=True,
        )

        # 8️⃣ Target group pointing to ECS service
        listener.add_targets(
            "FlaskTargets",
            port=8080,  # ECS container port
            targets=[service],
            health_check=elbv2.HealthCheck(
                path="/",
                port="8080",
                interval=cdk.Duration.seconds(30),
            ),
        )

        # 9️⃣ Allow ALB SG to talk to ECS SG
        ecs_sg.add_ingress_rule(alb_sg, ec2.Port.tcp(8080), "Allow traffic from ALB only")

```

Modify `app.py` to pass in your domain's certificate if you have one.
```python
#!/usr/bin/env python3
import os

import boto3
from aws_cdk import App

from stacks.app_stack import AppStack
from stacks.cluster_stack import ClusterStack
from stacks.network_stack import NetworkStack


def get_certificate_arn(domain_name, region='eu-west-2'):
    client = boto3.client('acm', region_name=region)
    certs = client.list_certificates(CertificateStatuses=['ISSUED'])
    for cert in certs['CertificateSummaryList']:
        if cert['DomainName'] == domain_name:
            return cert['CertificateArn']
    return None


# get domain name form DOMAIN_NAME environment variable
domain_name = os.getenv('DOMAIN_NAME', None)
if not domain_name:
    raise ValueError('DOMAIN_NAME environment variable is not set')
certificate_arn = get_certificate_arn(domain_name)
print(f'Using certificate ARN: {certificate_arn}')

app = App()


network = NetworkStack(app, 'EcsNetworkStack')
cluster = ClusterStack(app, 'EcsClusterStack', vpc=network.vpc)
app_stack = AppStack(app, 'EcsAppStack', cluster=cluster.cluster, certificate_arn=certificate_arn)

app.synth()
```

>**Note:** Make sure to set the environment variable `DOMAIN_NAME` to your domain name before running `cdk apply`

## ✅ Result
- After the stack is deployed, create a `CNAME` DNS record for your chosen subdomain, for example, `ecs.yourdomain` pointing at the ALB's domain name. You should now be able to hit `https://ecs.yourdomain` If you use CloudFlare, do not use Cloudflare's proxy for the CNAME record otherwise TLS terminates at Cloudflare and you will not reach the ALB as it expects HTTPS.
- Internet → HTTPS → ALB → HTTP → ECS
- No direct public IP on ECS tasks
- Least-privilege SGs: ALB can hit ECS, your IP hits ALB only via HTTPS