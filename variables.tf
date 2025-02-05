
variable "aws_access_key" {
        type = string
        description = "Access key to AWS console"
        sensitive = true
}

variable "aws_secret_key" {
        type = string
        description = "Secret key to AWS console"
        sensitive = true
}

variable "aws_region" {
        type = string
        description = "AWS region"
        default  = "eu-central-1"
}

variable "nixos_config" {
        type = string
        description = "Path to configuration.nix that gets base64 enccoded and passed through user-data to the instance"
        default = "./configuration.nix"
}

variable "instance_name" {
        type = string
        description = "Name of the instance to be created"
        default = "satisfactory"
}

variable "instance_type" {
        type = string
        default = "m5a.xlarge"
}

variable "ami_id" {
        type = string
        description = "The NIXOS AMI"
        default = "ami-05df1b211df600977" #22.11
        # pick the AMI from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/amazon-ec2-amis.nix
}

variable "ami_key_pair_name" {
        type = string
        default = "satisfactory"
        sensitive = true
}

variable "domain" {
        type = string
        description = "FQDN of your Cloudflare domain"
}

variable "discord_webhook_url" {
        type = string
        description = "webhook URL in the form of https://discord.com/api/webhooks/..."
        sensitive = true
}

variable "cloudflare_api_token" {
        type = string
        description = "api token with permissions"
        sensitive = true
}

variable "cloudflare_account_id" {
        type = string
        description = "Account ID for this zone"
        sensitive = true
}
