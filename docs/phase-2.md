# AWS ECS Fargate Phase 2 — Application Container

## 1. Project structure

We’ll expand the repo to include the app and a Dockerfile:
```bash
ecs-hello/
├── app.py
├── flask_app/
│   ├── app.py            # Flask "Hello World"
│   └── Dockerfile
├── stacks/
│   ├── network_stack.py
│   ├── cluster_stack.py
│   ├── app_stack.py
│   └── tags.py
```

## 2. Simple Flask App

Add `flask` to `requirements.txt` and run `pip install -r requirements.txt`

`flask_app/app.py`

src/app.py
from flask import Flask

app = Flask(__name__)

@app.route("/")
def hello():
    return "Hello World from ECS Fargate!"

if __name__ == "__main__":
    # Bind to 0.0.0.0 so container is reachable
    app.run(host="0.0.0.0", port=8080)
```

## 3 — Dockerfile

`flask_app/app.py`
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY app.py .
RUN pip install flask
EXPOSE 8080
CMD ["python", "app.py"]
```

We expose `8080` because our ALB (later) will target that port.

## 4 Update `AppStack` to use ECR and create a Security group.

Instead of manually creating ECR repos, we’ll use aws_ecr_assets in CDK, which:

  - Creates an ECR repo (if needed).
  - Builds the Docker image locally.
  - Pushes it to ECR automatically during cdk deploy.

`stacks/app_stack.py`
```python
import os

from aws_cdk import Stack
from aws_cdk import aws_ec2 as ec2
from aws_cdk import aws_ecr_assets as ecr_assets
from aws_cdk import aws_ecs as ecs
from constructs import Construct


class AppStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, *, cluster, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Build and push local Docker image
        image_asset = ecr_assets.DockerImageAsset(
            self, 'FlaskAppImage', directory=os.path.join(os.path.dirname(__file__), '../flask_app')
        )

        task_def = ecs.FargateTaskDefinition(self, 'FlaskTaskDef')
        container = task_def.add_container(
            'FlaskContainer',
            image=ecs.ContainerImage.from_docker_image_asset(image_asset),
            logging=ecs.LogDriver.aws_logs(stream_prefix='flask'),
        )
        container.add_port_mappings(ecs.PortMapping(container_port=8080))

        # Security Group for HTTP
        hello_sg = ec2.SecurityGroup(
            self,
            'HelloServiceSG',
            vpc=cluster.vpc,  # reference the VPC from ClusterStack
            allow_all_outbound=True,
            description='SG for ECS Hello service',
        )

        # Allow your specific IP on 8080
        my_ip = '1.1.1.1/32'  # CHANGE TO YOUR CIDR
        hello_sg.add_ingress_rule(
            peer=ec2.Peer.ipv4(my_ip),
            connection=ec2.Port.tcp(8080),
            description='Allow HTTP from my IP only',
        )

        # Fargate service
        ecs.FargateService(
            self,
            'HelloService',
            cluster=cluster,
            task_definition=task_def,
            desired_count=1,
            assign_public_ip=True,
            security_groups=[hello_sg],
            enable_execute_command=True,
        )
```

A note on debugging:

Adding `enable_execute_command=True,` allows us to use `aws ecs execute-command` for example:

```
aws ecs execute-command \
    --cluster ecs-hello-cluster \
    --task 804e3e1a0a4f49ef853e4ea19bc4f561 \
    --container HelloContainer \
    --interactive \
    --command "/bin/sh"
```

**Note:** This requires installation of the **Session Manager** AWS CLI plugin.

> ⚠️ Existing tasks won’t have execute-command enabled if you add it later. Redeploy the service to launch new tasks with the feature.

## 5. Deploy
```bash
cdk deploy EcsAppStack
```

- CDK builds the Docker image, pushes to ECR.
- ECS Fargate service launches with a public IP.
- Task logs go to CloudWatch Logs under flask.

## 6. Validate
1. Open ECS → Tasks → click the running task → ENI public IP.
2. In your browser or curl:
```bash
curl http://<public-ip>:8080
# Should return: Hello World from ECS Fargate!
```
3. Check CloudWatch logs for the container output.

This sets the stage for **Phase 3**, where we’ll add a load balancer and proper routing for multiple containers.