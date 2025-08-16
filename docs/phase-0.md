# AWS ECS Fargate Phase 0

Let’s get CDK installed and bootstrapped.

1. Install AWS CDK CLI
```
npm install -g aws-cdk
```

2. Verify installation
```
cdk --version
```

3. Create a new Python CDK project
```
mkdir ecs-hello
cd ecs-hello
cdk init app --language python
```

3. Update `requirements.txt` to include libraries we will use later.

```text
aws-cdk-lib==2.208.0
boto3
constructs>=10.0.0,<11.0.0
flask
```

4. Create a Python virtual environment
```
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

5. Bootstrap CDK (per AWS account/region)
```
aws sso login # Assuming you have an AWS_PROFILE, if not, get credentials some other way
cdk bootstrap aws://1234567890/eu-west-2 # Use your account and region
```