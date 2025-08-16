# AWS ECS Fargate Phase 4 — Observability and Tagging

## 1. Enable CloudWatch Logs for ECS Tasks

You already have logging enabled for your ECS container:

```python
container = task_def.add_container(
    "FlaskContainer",
    image=ecs.ContainerImage.from_docker_image_asset(image_asset),
    logging=ecs.LogDriver.aws_logs(stream_prefix="flask"),
)
```

**This captures all stdout/stderr from your container (including any log messages from your Flask app) and sends them to CloudWatch Logs.**

### To view logs:
- Go to the CloudWatch Console → Logs → Log groups.
- Look for a log group named `/aws/ecs/flask` (or similar).

## 2. Enable Container Insights (optional)

You can enable ECS Container Insights for more detailed metrics:

```python
cluster = ecs.Cluster(
    self,
    'EcsHelloCluster',
    vpc=vpc,
    container_insights=True,  # Enable Container Insights
)
```

## 3. CloudWatch Metrics for ALB

ALB automatically publishes metrics to CloudWatch, such as:
- `RequestCount`
- `HealthyHostCount`
- `TargetResponseTime`
- `HTTPCode_ELB_4XX_Count`, etc.

### To view metrics:
- Go to CloudWatch Console → Metrics → `AWS/ApplicationELB`.
- Filter by your ALB name.

## 4. CloudWatch Metrics for ECS Service

ECS automatically publishes metrics such as:
- `CPUUtilization`
- `MemoryUtilization`
- `RunningTaskCount`
- `PendingTaskCount`

### To view metrics:
- Go to CloudWatch Console → Metrics → `ECS/Service`.
- Filter by your cluster and service name.

## 5. (Optional) Create CloudWatch Alarms

You can create alarms for key metrics, e.g.:
- High error rates on ALB
- High CPU/memory usage on ECS tasks
- Unhealthy targets

Example (CDK):

Update `stacks/app_stack.py`

```python
from aws_cdk import aws_cloudwatch as cloudwatch

alarm = cloudwatch.Alarm(
    self,
    "HighCpuAlarm",
    metric=service.metric_cpu_utilization(),
    threshold=80,
    evaluation_periods=2,
    datapoints_to_alarm=2,
    comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
)
```

## 6. Tagging AWS Resources

Tagging helps organize and identify resources for cost allocation, ownership, and environment separation.

### Example Tag Module

Create a new file: `stacks/tags.py`

```python
from aws_cdk import Tags


def apply_default_tags(scope):
    # In a real application these would come from YAML etc.
    tags = {
        'Owner': 'Me',
        'Name': 'Hello-world',
        'Environment': 'Dev',
    }
    for key, value in tags.items():
        Tags.of(scope).add(key, value)

```

### Applying Tags in Your Stacks

Import and use the tag helper in your stack files, e.g. `app_stack.py`:

```python
# filepath: /home/steve/repos/ecs-hello/stacks/app_stack.py
from aws_cdk import Tags
from stacks.tags import apply_default_tags

# ...existing code...

class AppStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, *, cluster, certificate_arn=None, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # ...existing code...

        # Apply tags to resources
        tags = apply_default_tags(self)
```

You can also tag individual resources (e.g., VPC, ALB, ECS Service) similarly.

## ✅ Result

- All container logs are sent to CloudWatch Logs.
- ALB and ECS metrics are available in CloudWatch.
- (Optional) Alarms can notify you of issues.
- Resources are tagged for ownership, naming,