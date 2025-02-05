# OpenTofu code to deploy a NixOS vm on AWS and run a Satisfactory Dedicated Server

## File structure

```bash
├── "apigw.tf" - handles the AWS API Gateway configuration
├── "autoshutdown.sh" - script to shutdown the server when inactive
├── "certs.tf" - handles CloudFlare origin certificates
├── "configuration.nix" - whole OS configuration and Satisfactory installation
├── "dns.tf" - handles CloudFlare domain & subdomain
├── "iam.tf" - handles AWS IAM configuration for EC2 and Lambda
├── "instance.tf" - EC2
├── "lambda.py" - script to boot-up EC2 on call
├── "lambda.tf" - templates lambda.py and creates it
├── "network.tf" - handles Security Groups, Routes, VPC, Ingress and etc.
├── "providers.tf "- AWS & Cloudflare provider config
├── "secrets.auto.tfvars.example" - example secret vars
├── "ssm.tf" - AWS SSM config and parameter
└── "variables.tf" - TF variables
```

## What do I need to get this running?

1. AWS credentials
1. CloudFlare credentials
1. Domain purchased through CloudFlare or at least managed by it
1. Discord webhook is *optional*