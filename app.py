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
