#!/bin/bash

# This is a smarter version of the cleanup script suggested in Phase 5. It will only show remaining resources, and includes the logical name/identifier and the ARN.
# It also indicate where resources are free or mostly free and therefore do not need to be removed.
# It also coveres more resource types than we use in this excercise to make the script more widely useful.

# ACM Certificates
certs=$(aws acm list-certificates --query "CertificateSummaryList[*].[CertificateArn,DomainName]")
if [[ $(echo "$certs" | jq 'length') -gt 0 ]]; then
    echo "=== ACM Certificates (FREE) ==="
    echo "$certs" | jq -r '.[] | "Domain: \(.[1]) ARN: \(.[0])"'
    echo
fi

# ALBs
albs=$(aws elbv2 describe-load-balancers --query "LoadBalancers[*].[LoadBalancerArn, DNSName]")
if [[ $(echo "$albs" | jq 'length') -gt 0 ]]; then
    echo "=== ALBs (CHARGEABLE - Delete) ==="
    echo "$albs" | jq -r '.[] | "DNS: \(.[1]) ARN: \(.[0])"'
    echo
fi

# CloudFormation Stacks
stacks=$(aws cloudformation list-stacks --query "StackSummaries[?StackStatus!='DELETE_COMPLETE'].[StackName,StackId]")
if [[ $(echo "$stacks" | jq 'length') -gt 0 ]]; then
    echo "=== CloudFormation Stacks (FREE) ==="
    echo "$stacks" | jq -r '.[] | "Name: \(.[0]) ARN: \(.[1])"'
    echo
fi

# CloudWatch Log Groups
loggroups=$(aws logs describe-log-groups --query "logGroups[*].[logGroupName,arn]")
if [[ $(echo "$loggroups" | jq 'length') -gt 0 ]]; then
    echo "=== CloudWatch Log Groups (FREE for small volume/short retention) ==="
    echo "$loggroups" | jq -r '.[] | "Name: \(.[0]) ARN: \(.[1])"'
    echo
fi

# EBS Volumes
vols=$(aws ec2 describe-volumes --query "Volumes[*].[VolumeId,Attachments[0].InstanceId]")
if [[ $(echo "$vols" | jq 'length') -gt 0 ]]; then
    echo "=== EBS Volumes ==="
    echo "$vols" | jq -r '.[] | "VolumeId: \(.[0]) InstanceId: \(.[1])"'
    echo
fi

# EC2 Instances
instances=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value|[0]]" --output json)
if [[ $(echo "$instances" | jq 'flatten | length') -gt 0 ]]; then
    echo "=== EC2 Instances ==="
    echo "$instances" | jq -r 'flatten | .[] | "Name: \(.[1]) InstanceId: \(.[0])"'
    echo
fi

# ECR Repositories
repos=$(aws ecr describe-repositories --query "repositories[*].[repositoryName,repositoryArn]")
if [[ $(echo "$repos" | jq 'length') -gt 0 ]]; then
    echo "=== ECR Repositories (FREE for low use) ==="
    echo "$repos" | jq -r '.[] | "Name: \(.[0]) ARN: \(.[1])"'
    echo
fi

# ECS Clusters
clusters=$(aws ecs list-clusters --query "clusterArns[]" --output json)
if [[ $(echo "$clusters" | jq 'length') -gt 0 ]]; then
    echo "=== ECS Clusters (FREE if no tasks/services) ==="
    echo "$clusters" | jq -r '.[] | "Cluster ARN: \(.)"'
    echo

    # ECS Services
    for cluster in $(echo "$clusters" | jq -r '.[]'); do
        services=$(aws ecs list-services --cluster "$cluster" --query "serviceArns[]" --output json)
        if [[ $(echo "$services" | jq 'length') -gt 0 ]]; then
            echo "Cluster: $cluster"
            echo "$services" | jq -r '.[] | "Service ARN: \(.)"'
        fi
    done

    # ECS Tasks
    for cluster in $(echo "$clusters" | jq -r '.[]'); do
        tasks=$(aws ecs list-tasks --cluster "$cluster" --query "taskArns[]" --output json)
        if [[ $(echo "$tasks" | jq 'length') -gt 0 ]]; then
            echo "Cluster: $cluster"
            echo "$tasks" | jq -r '.[] | "Task ARN: \(.)"'
        fi
    done
fi

# Elastic IPs
ips=$(aws ec2 describe-addresses --query "Addresses[*].[PublicIp,AllocationId]")
if [[ $(echo "$ips" | jq 'length') -gt 0 ]]; then
    echo "=== Elastic IPs ==="
    echo "$ips" | jq -r '.[] | "IP: \(.[0]) AllocationId: \(.[1])"'
    echo
fi

# IAM Roles
roles=$(aws iam list-roles --query "Roles[?contains(RoleName, 'cdk')].[RoleName,Arn]")
if [[ $(echo "$roles" | jq 'length') -gt 0 ]]; then
    echo "=== IAM Roles (FREE) ==="
    echo "$roles" | jq -r '.[] | "Role: \(.[0]) ARN: \(.[1])"'
    echo
fi

# Lambda Functions
lambdas=$(aws lambda list-functions --query "Functions[*].[FunctionName,FunctionArn]")
if [[ $(echo "$lambdas" | jq 'length') -gt 0 ]]; then
    echo "=== Lambda Functions ==="
    echo "$lambdas" | jq -r '.[] | "Name: \(.[0]) ARN: \(.[1])"'
    echo
fi

# NAT Gateways
natgws=$(aws ec2 describe-nat-gateways --query "NatGateways[*].[NatGatewayId,SubnetId]")
if [[ $(echo "$natgws" | jq 'length') -gt 0 ]]; then
    echo "=== NAT Gateways ==="
    echo "$natgws" | jq -r '.[] | "NatGatewayId: \(.[0]) SubnetId: \(.[1])"'
    echo
fi

# R53 Hosted Zones
zones=$(aws route53 list-hosted-zones --query "HostedZones[*].[Name,Id]")
if [[ $(echo "$zones" | jq 'length') -gt 0 ]]; then
    echo "=== R53 Hosted Zones ==="
    echo "$zones" | jq -r '.[] | "Name: \(.[0]) Id: \(.[1])"'
    echo
fi

# S3 Buckets
buckets=$(aws s3api list-buckets --query "Buckets[*].[Name,CreationDate]")
if [[ $(echo "$buckets" | jq 'length') -gt 0 ]]; then
    echo "=== S3 Buckets (FREE for low volume) ==="
    echo "$buckets" | jq -r '.[] | "Name: \(.[0]) Created: \(.[1])"'
    echo
fi

# Snapshots
snaps=$(aws ec2 describe-snapshots --owner-ids self --query "Snapshots[*].[SnapshotId,VolumeId]")
if [[ $(echo "$snaps" | jq 'length') -gt 0 ]]; then
    echo "=== Snapshots ==="
    echo "$snaps" | jq -r '.[] | "SnapshotId: \(.[0]) VolumeId: \(.[1])"'
    echo
fi

vpcs=$(aws ec2 describe-vpcs --query "Vpcs[?IsDefault==\`false\`].[VpcId,CidrBlock]")
if [[ $(echo "$vpcs" | jq 'length') -gt 0 ]]; then
    echo "=== VPCs (FREE unless contains NATG/ALB/EC2) ==="
    echo "$vpcs" | jq -r '.[] | "VpcId: \(.[0]) CIDR: \(.[1])"'
    echo
fi
