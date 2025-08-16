import os

from aws_cdk import (
    Duration,  # import Duration directly
    Stack,
)
from aws_cdk import (
    aws_certificatemanager as acm,
)
from aws_cdk import (
    aws_cloudwatch as cloudwatch,
)
from aws_cdk import (
    aws_ec2 as ec2,
)
from aws_cdk import (
    aws_ecr_assets as ecr_assets,
)
from aws_cdk import (
    aws_ecs as ecs,
)
from aws_cdk import (
    aws_elasticloadbalancingv2 as elbv2,
)
from constructs import Construct

from stacks.tags import apply_default_tags


class AppStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, *, cluster, certificate_arn=None, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # 1️⃣ Build & push local Docker image
        image_asset = ecr_assets.DockerImageAsset(
            self,
            'FlaskAppImage',
            directory=os.path.join(os.path.dirname(__file__), '../flask_app'),
        )

        task_def = ecs.FargateTaskDefinition(self, 'FlaskTaskDef')
        container = task_def.add_container(
            'FlaskContainer',
            image=ecs.ContainerImage.from_docker_image_asset(image_asset),
            logging=ecs.LogDriver.aws_logs(stream_prefix='flask'),
        )
        container.add_port_mappings(ecs.PortMapping(container_port=8080))

        # 2️⃣ Security group for ECS service (private, only ALB can talk)
        ecs_sg = ec2.SecurityGroup(
            self,
            'FlaskServiceSG',
            vpc=cluster.vpc,
            allow_all_outbound=True,
            description='Private SG for ECS service, allows only ALB traffic',
        )

        # 3️⃣ Security group for ALB (public, allows HTTPS from anywhere)
        alb_sg = ec2.SecurityGroup(
            self,
            'FlaskALBSG',
            vpc=cluster.vpc,
            allow_all_outbound=True,
            description='Public SG for ALB, allows HTTPS from Internet',
        )
        alb_sg.add_ingress_rule(ec2.Peer.any_ipv4(), ec2.Port.tcp(443), 'Allow HTTPS from anywhere')

        # 4️⃣ Fargate service in private subnets
        service = ecs.FargateService(
            self,
            'FlaskService',
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
            'FlaskALB2',
            vpc=cluster.vpc,
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PUBLIC),
            internet_facing=True,
            security_group=alb_sg,
        )

        # 6️⃣ ACM certificate (optional, only if domain_name is provided)
        certificate = None
        if certificate_arn:
            certificate = acm.Certificate.from_certificate_arn(self, 'FlaskALBCert', certificate_arn)
        # 7️⃣ HTTPS listener
        listener = alb.add_listener(
            'HttpsListener',
            port=443,
            certificates=[certificate] if certificate else None,
            open=True,
        )

        # 8️⃣ Target group pointing to ECS service
        listener.add_targets(
            'FlaskTargets',
            port=8080,  # ECS container port
            targets=[service],
            health_check=elbv2.HealthCheck(
                path='/',
                port='8080',
                interval=Duration.seconds(30),  # <-- use Duration directly
            ),
        )
        # 9️⃣ Allow ALB SG to talk to ECS SG
        ecs_sg.add_ingress_rule(alb_sg, ec2.Port.tcp(8080), 'Allow traffic from ALB only')

        # 🔟 Cloudwatch Alarm example - High CPU utilization
        cloudwatch.Alarm(
            self,
            'HighCpuAlarm',
            metric=service.metric_cpu_utilization(),
            threshold=80,
            evaluation_periods=2,
            datapoints_to_alarm=2,
            comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
        )
        # Apply tags to resources
        apply_default_tags(self)
