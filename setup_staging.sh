#!/bin/bash

node_name=staging-web1
key_name=staging
key_path=~/.ssh/$key_name.pem
security_group=sg-yours #edit
subnet=subnet-yours #edit
image=ami-a4b792f6

if [ ! -f $key_path ]; then
    echo "$key does not exist!"
    exit 1
fi

knife ec2 server create \
    --flavor m3.medium \
    --security-group-ids $security_group \
    --ssh-user ubuntu \
    --ssh-key $key_name \
    --identity-file $key_path \
    --node-name $node_name \
    --environment staging \
    --run-list "recipe[kruk],recipe[kruk::rails_server],recipe[kruk::deploy]" \
    --iam-profile web-staging \
    --associate-public-ip \
    --subnet $subnet \
    --image $image
