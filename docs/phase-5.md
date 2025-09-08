# AWS ECS Fargate Phase 5 — Clean up, Cost Awareness, Autoscaling, and Advanced Security

## 1. Autoscaling and Resource Requests/Limits in ECS

### Resource Requests/Limits

In ECS Fargate, you specify **CPU and memory** for each container in your task definition. This acts as both a request and a limit.

```python
container = task_def.add_container(
    "FlaskContainer",
    image=ecs.ContainerImage.from_docker_image_asset(image_asset),
    cpu=256,  # 0.25 vCPU
    memory_limit_mib=512,  # 512 MiB
    logging=ecs.LogDriver.aws_logs(stream_prefix="flask"),
)
```

### Service Autoscaling

You can enable autoscaling for your ECS service based on CloudWatch metrics (e.g., CPU utilization):

```python
scaling = service.auto_scale_task_count(
    min_capacity=1,
    max_capacity=5,
)

scaling.scale_on_cpu_utilization(
    "CpuScaling",
    target_utilization_percent=50,
)
```

- This will automatically adjust the number of running tasks to keep average CPU utilization near 50%.

## 2. Example: Deploying AquaSec MicroEnforcer on ECS

AquaSec MicroEnforcer can be deployed as a **sidecar container** in your ECS task definition.

```python
microenforcer_container = task_def.add_container(
    "AquasecMicroEnforcer",
    image=ecs.ContainerImage.from_registry("aquasec/microenforcer:latest"),
    environment={
        "AQUA_SERVER": "<your-aqua-server>",
        "AQUA_TOKEN": "<your-aqua-token>",
        # Add other required env vars
    },
    logging=ecs.LogDriver.aws_logs(stream_prefix="aquasec"),
)
```

- Ensure your main app container and MicroEnforcer are in the same task definition.
- Configure networking and IAM permissions as required by Aquasec.

## 3. Application Tracing on ECS with Datadog via OpenTelemetry

For distributed tracing with Datadog, use the **OpenTelemetry Collector** as a sidecar container and configure it to export traces to Datadog.

```python
otel_collector = task_def.add_container(
    "OtelCollector",
    image=ecs.ContainerImage.from_registry("otel/opentelemetry-collector-contrib:latest"),
    environment={
        "DD_API_KEY": "<your-datadog-api-key>",
        # Add other required env vars for Datadog exporter
    },
    command=[
        "--config=/etc/otel-collector-config.yaml"
    ],
    logging=ecs.LogDriver.aws_logs(stream_prefix="otel"),
)
```

- Mount a configuration file (`otel-collector-config.yaml`) that sets up the Datadog exporter.
- Instrument your application code with OpenTelemetry SDKs (Python: `opentelemetry-distro`, `opentelemetry-exporter-otlp`).
- Ensure network access to Datadog endpoints.

### Example OpenTelemetry Python Instrumentation

```python
from opentelemetry import trace
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace.export import BatchSpanProcessor

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)

trace.set_tracer_provider(TracerProvider())
otlp_exporter = OTLPSpanExporter(endpoint="http://localhost:4318/v1/traces")
trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(otlp_exporter))
```

- Adjust the OTLP exporter endpoint to match your collector configuration.

## 4. Destroying Your CDK Application

To cleanly remove all resources created by your CDK app:

```sh
cdk destroy
```

- This command deletes all stacks defined in your app.
- You may be prompted to confirm deletion.
- **Tip:** Run `cdk list` to see all deployed stacks.

## 5. Checking for Lingering Chargeable Resources

After destroying, check for resources that may still incur charges:

### Bash Script Example

```bash
#!/bin/bash

echo "=== ACM Certificates (FREE) ==="
aws acm list-certificates --output text

echo "=== ALB ==="
aws elbv2 describe-load-balancers --output text

echo "=== CloudFormation Stacks (FREE) ==="
aws cloudformation list-stacks --query "StackSummaries[?StackStatus!='DELETE_COMPLETE'].StackName" --output text

echo "=== CloudWatch Log Groups(FREE for small volume/short retention) ==="
aws logs describe-log-groups --query "logGroups[*].logGroupName" --output text

echo "=== EBS Volumes ==="
aws ec2 describe-volumes --query "Volumes[*].VolumeId" --output text

echo "=== EC2 Instances ==="
aws ec2 describe-instances --query "Reservations[*].Instances[*].InstanceId" --output text

echo "=== ECR Repositories (FREE for low use) ==="
aws ecr describe-repositories --query "repositories[*].repositoryName" --output text

echo "=== ECS Clusters (FREE if no tasks/services) ==="
clusters=$(aws ecs list-clusters --query "clusterArns[]" --output text)
echo "$clusters"

if [[ -n "$clusters" ]]; then
    echo "=== ECS Services ==="
    for cluster in $clusters; do
        aws ecs list-services --cluster "$cluster" --query "serviceArns[]" --output text
    done

    echo "=== ECS Tasks ==="
    for cluster in $clusters; do
        aws ecs list-tasks --cluster "$cluster" --query "taskArns[]" --output text
    done

else
    echo "No ECS clusters found."    
fi

echo "=== Elastic IPs ==="
aws ec2 describe-addresses --query "Addresses[*].PublicIp" --output text

echo "=== IAM Roles (FREE) ==="
aws iam list-roles --query "Roles[?contains(RoleName, 'cdk')].RoleName" --output text

echo "=== Lambda Functions ==="
aws lambda list-functions --query "Functions[*].FunctionName" --output text

echo "=== NAT Gateways ==="
aws ec2 describe-nat-gateways --output text

echo "=== R53 Hosted Zones ==="
aws route53 list-hosted-zones --output text

echo "=== S3 Buckets (FREE for low volume) ==="
aws s3api list-buckets --query "Buckets[*].Name" --output text

echo "=== Snapshots ==="
aws ec2 describe-snapshots --owner-ids self --query "Snapshots[*].SnapshotId" --output text

echo "=== VPCs (FREE unless contains NATG/ALB/EC2) ==="
aws ec2 describe-vpcs
```

- Review the output and manually delete any chargeable resources not removed by CDK.

## ✅ Result

- Learn how to set resource requests/limits and autoscaling for ECS
- Example provided for deploying Aquasec MicroEnforcer on ECS.
- Guidance for enabling application tracing with Datadog via OpenTelemetry Collector.
- You can destroy your app and check for lingering resources.