from aws_cdk import Stack
from aws_cdk import aws_ecs as ecs
from constructs import Construct


class ClusterStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, *, vpc, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.cluster = ecs.Cluster(
            self, 'EcsHelloCluster', vpc=vpc, cluster_name='ecs-hello-cluster', container_insights=True
        )
