#!/bin/bash

REGION="ap-southeast-2"
echo "Hunting for untagged ghost resources in $REGION..."

EIPS=$(aws ec2 describe-addresses --region $REGION --query 'Addresses[?AssociationId==`null`].AllocationId' --output text)
for eip in $EIPS; do
    echo "Releasing orphaned Elastic IP: $eip"
    aws ec2 release-address --allocation-id $eip --region $REGION
done

ENDPOINTS=$(aws ec2 describe-vpc-endpoints --region $REGION --filters "Name=vpc-endpoint-type,Values=Interface" --query 'VpcEndpoints[*].VpcEndpointId' --output text)
for ep in $ENDPOINTS; do
    TAG_CHECK=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$ep" "Name=key,Values=Environment" --query 'Tags[*].Value' --output text)
    if [ -z "$TAG_CHECK" ]; then
        echo "Deleting untagged VPC Endpoint: $ep"
        aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $ep --region $REGION
    fi
done

NATS=$(aws ec2 describe-nat-gateways --region $REGION --filter "Name=state,Values=available" --query 'NatGateways[*].NatGatewayId' --output text)
for nat in $NATS; do
    TAG_CHECK=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$nat" "Name=key,Values=Environment" --query 'Tags[*].Value' --output text)
    if [ -z "$TAG_CHECK" ]; then
        echo "Deleting untagged NAT Gateway: $nat"
        aws ec2 delete-nat-gateway --nat-gateway-id $nat --region $REGION
    fi
done

echo "Ghost hunt complete."