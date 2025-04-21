# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-metadata-endpoint-v4-fargate-examples.html
ECS_SAMPLE_JSON = {
  'DockerId' => 'cd189a933e5849daa93386466019ab50-2495160603',
  'Name' => 'curl',
  'DockerName' => 'curl',
  'Image' => '111122223333.dkr.ecr.us-west-2.amazonaws.com/curltest:latest',
  'ImageID' => 'sha256:25f3695bedfb454a50f12d127839a68ad3caf91e451c1da073db34c542c4d2cb',
  'Labels' => {
    'com.amazonaws.ecs.cluster' => 'arn:aws:ecs:us-west-2:111122223333:cluster/default',
    'com.amazonaws.ecs.container-name' => 'curl',
    'com.amazonaws.ecs.task-arn' => 'arn:aws:ecs:us-west-2:111122223333:task/default/cd189a933e5849daa93386466019ab50',
    'com.amazonaws.ecs.task-definition-family' => 'curltest',
    'com.amazonaws.ecs.task-definition-version' => '2'
  },
  'DesiredStatus' => 'RUNNING',
  'KnownStatus' => 'RUNNING',
  'Limits' => {
    'CPU' => 10,
    'Memory' => 128
  },
  'CreatedAt' => '2020-10-08T20:09:11.44527186Z',
  'StartedAt' => '2020-10-08T20:09:11.44527186Z',
  'Type' => 'NORMAL',
  'Networks' => [
    {
      'NetworkMode' => 'awsvpc',
      'IPv4Addresses' => [
        '192.0.2.3'
      ],
      'AttachmentIndex' => 0,
      'MACAddress' => '0a:de:f6:10:51:e5',
      'IPv4SubnetCIDRBlock' => '192.0.2.0/24',
      'DomainNameServers' => [
        '192.0.2.2'
      ],
      'DomainNameSearchList' => [
        'us-west-2.compute.internal'
      ],
      'PrivateDNSName' => 'ip-10-0-0-222.us-west-2.compute.internal',
      'SubnetGatewayIpv4Address' => '192.0.2.0/24'
    }
  ],
  'ContainerARN' => 'arn:aws:ecs:us-west-2:111122223333:container/05966557-f16c-49cb-9352-24b3a0dcd0e1',
  'LogOptions' => {
    'awslogs-create-group' => 'true',
    'awslogs-group' => '/ecs/containerlogs',
    'awslogs-region' => 'us-west-2',
    'awslogs-stream' => 'ecs/curl/cd189a933e5849daa93386466019ab50'
  },
  'LogDriver' => 'awslogs',
  'Snapshotter' => 'overlayfs'
}.freeze

ECS_SAMPLE_TASK = {
  'Cluster' => 'arn:aws:ecs:us-east-1:123456789012:cluster/MyEmptyCluster',
  'TaskARN' => 'arn:aws:ecs:us-east-1:123456789012:task/MyEmptyCluster/bfa2636268144d039771334145e490c5',
  'Family' => 'sample-fargate',
  'Revision' => '5',
  'DesiredStatus' => 'RUNNING',
  'KnownStatus' => 'RUNNING',
  'Limits' => {
    'CPU' => 0.25,
    'Memory' => 512
  },
  'PullStartedAt' => '2023-07-21T15:45:33.532811081Z',
  'PullStoppedAt' => '2023-07-21T15:45:38.541068435Z',
  'AvailabilityZone' => 'us-east-1d',
  'Containers' => [
    {
      'DockerId' => 'bfa2636268144d039771334145e490c5-1117626119',
      'Name' => 'curl-image',
      'DockerName' => 'curl-image',
      'Image' => 'curlimages/curl',
      'ImageID' => 'sha256:daf3f46a2639c1613b25e85c9ee4193af8a1d538f92483d67f9a3d7f21721827',
      'Labels' => {
        'com.amazonaws.ecs.cluster' => 'arn:aws:ecs:us-east-1:123456789012:cluster/MyEmptyCluster',
        'com.amazonaws.ecs.container-name' => 'curl-image',
        'com.amazonaws.ecs.task-arn' => 'arn:aws:ecs:us-east-1:123456789012:task/MyEmptyCluster/bfa2636268144d039771334145e490c5',
        'com.amazonaws.ecs.task-definition-family' => 'sample-fargate',
        'com.amazonaws.ecs.task-definition-version' => '5'
      },
      'DesiredStatus' => 'RUNNING',
      'KnownStatus' => 'RUNNING',
      'Limits' => { 'CPU' => 128 },
      'CreatedAt' => '2023-07-21T15:45:44.91368314Z',
      'StartedAt' => '2023-07-21T15:45:44.91368314Z',
      'Type' => 'NORMAL',
      'Networks' => [
        {
          'NetworkMode' => 'awsvpc',
          'IPv4Addresses' => ['172.31.42.189'],
          'AttachmentIndex' => 0,
          'MACAddress' => '0e:98:9f:33:76:d3',
          'IPv4SubnetCIDRBlock' => '172.31.32.0/20',
          'DomainNameServers' => ['172.31.0.2'],
          'DomainNameSearchList' => ['ec2.internal'],
          'PrivateDNSName' => 'ip-172-31-42-189.ec2.internal',
          'SubnetGatewayIpv4Address' => '172.31.32.1/20'
        }
      ],
      'ContainerARN' => 'arn:aws:ecs:us-east-1:123456789012:container/MyEmptyCluster/bfa2636268144d039771334145e490c5/da6cccf7-1178-400c-afdf-7536173ee209',
      'Snapshotter' => 'overlayfs'
    },
    {
      'DockerId' => 'bfa2636268144d039771334145e490c5-3681984407',
      'Name' => 'fargate-app',
      'DockerName' => 'fargate-app',
      'Image' => 'public.ecr.aws/docker/library/httpd:latest',
      'ImageID' => 'sha256:8059bdd0058510c03ae4c808de8c4fd2c1f3c1b6d9ea75487f1e5caa5ececa02',
      'Labels' => {
        'com.amazonaws.ecs.cluster' => 'arn:aws:ecs:us-east-1:123456789012:cluster/MyEmptyCluster',
        'com.amazonaws.ecs.container-name' => 'fargate-app',
        'com.amazonaws.ecs.task-arn' => 'arn:aws:ecs:us-east-1:123456789012:task/MyEmptyCluster/bfa2636268144d039771334145e490c5',
        'com.amazonaws.ecs.task-definition-family' => 'sample-fargate',
        'com.amazonaws.ecs.task-definition-version' => '5'
      },
      'DesiredStatus' => 'RUNNING',
      'KnownStatus' => 'RUNNING',
      'Limits' => { 'CPU' => 2 },
      'CreatedAt' => '2023-07-21T15:45:44.954460255Z',
      'StartedAt' => '2023-07-21T15:45:44.954460255Z',
      'Type' => 'NORMAL',
      'Networks' => [
        {
          'NetworkMode' => 'awsvpc',
          'IPv4Addresses' => ['172.31.42.189'],
          'AttachmentIndex' => 0,
          'MACAddress' => '0e:98:9f:33:76:d3',
          'IPv4SubnetCIDRBlock' => '172.31.32.0/20',
          'DomainNameServers' => ['172.31.0.2'],
          'DomainNameSearchList' => ['ec2.internal'],
          'PrivateDNSName' => 'ip-172-31-42-189.ec2.internal',
          'SubnetGatewayIpv4Address' => '172.31.32.1/20'
        }
      ],
      'ContainerARN' => 'arn:aws:ecs:us-east-1:123456789012:container/MyEmptyCluster/bfa2636268144d039771334145e490c5/f65b461d-aa09-4acb-a579-9785c0530cbc',
      'Snapshotter' => 'overlayfs'
    }
  ],
  'LaunchType' => 'FARGATE',
  'ClockDrift' => {
    'ClockErrorBound' => 0.446931,
    'ReferenceTimestamp' => '2023-07-21T16:09:17Z',
    'ClockSynchronizationStatus' => 'SYNCHRONIZED'
  },
  'EphemeralStorageMetrics' => {
    'Utilized' => 261,
    'Reserved' => 20_496
  }
}.freeze

EKS_CLUSTER_MAP = {
  'kind' => 'ConfigMap',
  'apiVersion' => 'v1',
  metadata: {
    'name' => 'cluster-info',
    'namespace' => 'amazon-cloudwatch',
    'uid' => 'abcdef12-3456-7890-abcd-ef1234567890',
    'resourceVersion' => '67890',
    'creationTimestamp' => '2024-03-30T12:34:56Z'
  },
  'data' => {
    'cluster.name' => 'my-eks-cluster',
    'cluster.endpoint' => 'https://ABCD123456.gr7.us-west-2.eks.amazonaws.com',
    'cluster.region' => 'us-west-2'
  }
}.freeze

EC2_IDENTITY_DOC = {
  accountId: '123456789012',
  architecture: 'x86_64',
  availabilityZone: 'mock-west-2a',
  billingProducts: nil,
  devpayProductCodes: nil,
  marketplaceProductCodes: nil,
  imageId: 'ami-0957cee1854021123',
  instanceId: 'i-1234ab56cd7e89f01',
  instanceType: 't2.micro-mock',
  kernelId: nil,
  pendingTime: '2021-07-13T21:53:41Z',
  privateIp: '172.12.34.567',
  ramdiskId: nil,
  region: 'mock-west-2',
  version: '2017-09-30'
}.freeze
